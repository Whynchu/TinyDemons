param(
	[string]$TestFilter = "",
	[ValidateSet("gate", "owner", "reference", "diagnostic", "all")]
	[string]$TestGroup = "gate",
	[int]$TestTimeoutSeconds = 90,
	[string]$ResultsPath = "",
	[int]$StopAfterEngineCrashes = 2,
	[switch]$InventoryOnly
)

$ErrorActionPreference = "Stop"
# Some managed Windows hosts expose both PATH and Path in the inherited
# environment block. Windows PowerShell's Start-Process materializes that block
# into a case-insensitive dictionary and fails on the duplicate. Normalize it
# once in this runner process before starting Godot workers.
$processPath = $env:Path
Remove-Item Env:PATH -ErrorAction SilentlyContinue
if (-not [string]::IsNullOrWhiteSpace($processPath)) {
	$env:Path = $processPath
}
$root = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" }
$powerShell = (Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if ([string]::IsNullOrWhiteSpace($powerShell)) {
	$powerShell = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1).Source
}
if ([string]::IsNullOrWhiteSpace($powerShell)) {
	throw "No PowerShell executable found for smoke preflight"
}

$definitionValidator = Join-Path $root "tools/validate_definitions.ps1"
$manifestValidator = Join-Path $root "tools/validate_test_manifest.ps1"
$compositionValidator = Join-Path $root "tools/validate_composition.ps1"

& $powerShell -NoProfile -ExecutionPolicy Bypass -File $manifestValidator
if ($LASTEXITCODE -ne 0) {
	throw "Test manifest preflight failed"
}

& $powerShell -NoProfile -ExecutionPolicy Bypass -File $compositionValidator -SelfTest
if ($LASTEXITCODE -ne 0) {
	throw "Composition ownership self-test failed"
}
& $powerShell -NoProfile -ExecutionPolicy Bypass -File $compositionValidator
if ($LASTEXITCODE -ne 0) {
	throw "Composition ownership preflight failed"
}

& $powerShell -NoProfile -ExecutionPolicy Bypass -File $definitionValidator -ProjectRoot $root -GodotBin $godot
if ($LASTEXITCODE -ne 0) {
	throw "Definition validation preflight failed"
}

if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
	throw "Godot executable not found: $godot. Set GODOT_BIN or pass a configured binary."
}

$tempRoot = $env:RUNNER_TEMP
if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = $env:TEMP }
if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = [System.IO.Path]::GetTempPath() }
$headlessUserData = Join-Path $tempRoot ("tiny-demons-headless-{0}" -f $PID)
New-Item -ItemType Directory -Path $headlessUserData -Force | Out-Null
$logFile = Join-Path $headlessUserData "smoke.log"
$resultsPath = if ($ResultsPath) { $ResultsPath } else { Join-Path $headlessUserData "smoke-results.csv" }
$inventoryPath = "$resultsPath.inventory.csv"

# The manifest is the single source of truth for the test inventory. Each row
# records role (gate/owner/reference/diagnostic/report), state
# (verified/open/stale/harness/environment/unverified), owner, target, and load
# kind. Runner grouping derives from `role`; `report` rows are intentionally
# not runner tests.
$manifestPath = Join-Path $PSScriptRoot "manifest.csv"
$manifest = Import-Csv -LiteralPath $manifestPath
$manifestByScript = @{}
foreach ($row in $manifest) {
	$manifestByScript[$row.script] = $row
}

$runnableRoles = @("gate", "owner", "reference", "diagnostic")
$tests = switch ($TestGroup) {
	"gate" { @($manifest | Where-Object { $_.role -eq "gate" } | ForEach-Object { $_.script }) }
	"owner" { @($manifest | Where-Object { $_.role -eq "owner" } | ForEach-Object { $_.script }) }
	"reference" { @($manifest | Where-Object { $_.role -eq "reference" } | ForEach-Object { $_.script }) }
	"diagnostic" { @($manifest | Where-Object { $_.role -eq "diagnostic" } | ForEach-Object { $_.script }) }
	"all" { @($manifest | Where-Object { $_.role -in $runnableRoles } | ForEach-Object { $_.script }) }
}

if ($TestFilter) {
	$tests = @($tests | Where-Object { $_ -like $TestFilter })
}

$inventoryTests = $tests

Write-Host "Smoke group: $TestGroup ($($tests.Count) selected paths)"

$resultsDirectory = Split-Path -Parent $resultsPath
if ($resultsDirectory -and -not (Test-Path -LiteralPath $resultsDirectory)) {
	New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null
}
@("test,result,exit_code,elapsed_seconds,role,state,detail") | Set-Content -LiteralPath $resultsPath
@("test,script_path,role,state,exists") | Set-Content -LiteralPath $inventoryPath
$missingTests = @()
foreach ($test in $inventoryTests) {
	$scriptPath = Join-Path $root ("tests/{0}.gd" -f $test)
	$exists = Test-Path -LiteralPath $scriptPath
	$row = $manifestByScript[$test]
	$role = if ($row) { $row.role } else { "unclassified" }
	$state = if ($row) { $row.state } else { "unclassified" }
	Add-Content -LiteralPath $inventoryPath -Value ('"{0}","{1}","{2}","{3}",{4}' -f $test, $scriptPath, $role, $state, $exists.ToString().ToLowerInvariant())
	if (-not $exists) {
		$missingTests += $test
		Add-Content -LiteralPath $resultsPath -Value ('"{0}",missing,,0,"{1}","{2}","test script not found"' -f $test, $role, $state)
	}
}
if ($InventoryOnly) {
	if ($missingTests.Count -gt 0) { exit 1 }
	exit 0
}

$importArguments = @(
	"--headless",
	"--import",
	"--audio-driver", "Dummy",
	"--user-data-dir", $headlessUserData,
	"--path", $root,
	"--log-file", $logFile
)
& $godot @importArguments
if ($LASTEXITCODE -ne 0) {
	throw "Godot import preflight failed with exit code $LASTEXITCODE"
}

$failed = $false
$engineCrashCount = 0
$failByState = @{}
foreach ($test in $tests) {
	if ($missingTests -contains $test) { continue }
	Write-Host "=== $test ==="
	$row = $manifestByScript[$test]
	$role = if ($row) { $row.role } else { "unclassified" }
	$state = if ($row) { $row.state } else { "unclassified" }
	$startedAt = Get-Date
	$testUserData = Join-Path $tempRoot ("tiny-demons-headless-{0}-{1}" -f $PID, $test)
	$testLogFile = Join-Path $testUserData "smoke.log"
	New-Item -ItemType Directory -Path $testUserData -Force | Out-Null
	$arguments = @("--headless", "--audio-driver", "Dummy", "--user-data-dir", $testUserData, "--path", $root, "--log-file", $testLogFile, "-s", ("res://tests/{0}.gd" -f $test))
	# Windows PowerShell 5.1 can misinterpret an ArgumentList array containing
	# `--path` as a case-insensitive parameter map. Pass one explicitly quoted
	# command-line string so the Godot process receives the intended arguments.
	$argumentText = ($arguments | ForEach-Object { '"{0}"' -f ([string]$_).Replace('"', '\"') }) -join " "
	try {
		$process = Start-Process -FilePath $godot -ArgumentList $argumentText -WindowStyle Hidden -PassThru
	} catch {
		$detail = "failed to start Godot: $($_.Exception.Message)"
		Write-Host "ENGINE_START_FAILURE: $test ($detail)" -ForegroundColor Red
		Add-Content -LiteralPath $resultsPath -Value ('"{0}",engine_start_failure,,0,"{1}","{2}","{3}"' -f $test, $role, $state, $detail.Replace('"', '""'))
		$failed = $true
		$engineCrashCount += 1
		if ($engineCrashCount -ge $StopAfterEngineCrashes) {
			Write-Host "STOPPED: repeated Godot startup failures" -ForegroundColor Red
			break
		}
		continue
	}
	$completed = $process.WaitForExit($TestTimeoutSeconds * 1000)
	if (-not $completed) {
		# Process.Kill(bool) is unavailable on the .NET/Windows PowerShell
		# combination used by some local and CI hosts. The fallback still ends
		# the timed-out worker; the smoke runner does not own a process tree.
		try {
			$process.Kill($true)
		} catch {
			$process.Kill()
		}
		$process.WaitForExit()
		$elapsed = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 2)
		$detail = "timeout after $TestTimeoutSeconds seconds"
		Write-Host "TIMEOUT: $test ($detail)" -ForegroundColor Red
		Add-Content -LiteralPath $resultsPath -Value ('"{0}",timeout,,{1},"{2}","{3}","{4}"' -f $test, $elapsed, $role, $state, $detail)
		$failed = $true
		$failByState[$state] += 1
	} else {
		$process.WaitForExit()
		$exitCode = $process.ExitCode
		$elapsed = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 2)
		if (Test-Path -LiteralPath $testLogFile) { Get-Content -LiteralPath $testLogFile | Write-Host }
		$isEngineCrash = $exitCode -lt 0 -or $exitCode -in @(3221225477, -1073741510)
		if ($isEngineCrash) {
			$engineCrashCount += 1
			Write-Host "ENGINE_CRASH: $test (exit $exitCode)" -ForegroundColor Red
			Add-Content -LiteralPath $resultsPath -Value ('"{0}",engine_crash,{1},{2},"{3}","{4}","Godot process crashed"' -f $test, $exitCode, $elapsed, $role, $state)
			$failByState[$state] += 1
			if ($engineCrashCount -ge $StopAfterEngineCrashes) {
				Write-Host "STOPPED: repeated Godot engine crashes" -ForegroundColor Red
				$failed = $true
				break
			}
		} elseif ($exitCode -ne 0) {
			Write-Host "FAILED: $test (exit $exitCode)" -ForegroundColor Red
			Add-Content -LiteralPath $resultsPath -Value ('"{0}",fail,{1},{2},"{3}","{4}",""' -f $test, $exitCode, $elapsed, $role, $state)
			$failed = $true
			$failByState[$state] += 1
		} else {
			Write-Host "PASSED: $test" -ForegroundColor Green
			Add-Content -LiteralPath $resultsPath -Value ('"{0}",pass,0,{1},"{2}","{3}",""' -f $test, $elapsed, $role, $state)
		}
	}
}

if ($failByState.Count -gt 0) {
	Write-Host "Failures by manifest state:" -ForegroundColor Yellow
	foreach ($entry in ($failByState.GetEnumerator() | Sort-Object Key)) {
		Write-Host ("  {0}: {1}" -f $entry.Key, $entry.Value) -ForegroundColor Yellow
	}
	Write-Host "NOTE: a failed check may be a harness/environment issue rather than a product bug. Consult tests/manifest.csv state for each test." -ForegroundColor Yellow
}

if (-not $TestFilter -and $TestGroup -in @("gate", "all")) {
	Write-Host "=== sfx lab pytest ==="
	$sfxLabPy = "C:\Development\Tiny-Demons\TinyDemons\tools\sfx_reconstruction\.venv311\Scripts\python.exe"
	$sfxLabTests = "C:\Development\Tiny-Demons\TinyDemons\tools\sfx_lab\tests"
	& $sfxLabPy -m pytest $sfxLabTests -q
	if ($LASTEXITCODE -ne 0) {
		Write-Host "FAILED: sfx lab pytest (exit $LASTEXITCODE)" -ForegroundColor Red
		$failed = $true
	} else {
		Write-Host "PASSED: sfx lab pytest" -ForegroundColor Green
	}
	Write-Host "=== web export smoke ==="
	$webSmoke = Join-Path $PSScriptRoot "web_export_smoke.ps1"
	$webSmokeArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $webSmoke)
	if ($env:REQUIRE_WEB_EXPORT -eq "1") { $webSmokeArgs += "-RequireExport" }
	& $powerShell @webSmokeArgs
	if ($LASTEXITCODE -ne 0) {
		Write-Host "FAILED: web export smoke (exit $LASTEXITCODE)" -ForegroundColor Red
		$failed = $true
	} else {
		Write-Host "PASSED: web export smoke" -ForegroundColor Green
	}
	Write-Host "=== main scene headless run ==="
	& $godot --headless --audio-driver Dummy --user-data-dir $headlessUserData --path $root --log-file $logFile --quit-after 30
	if ($LASTEXITCODE -ne 0) {
		Write-Host "FAILED: main scene (exit $LASTEXITCODE)" -ForegroundColor Red
		$failed = $true
	} else {
		Write-Host "PASSED: main scene"
	}
}
if ($failed) {
	Write-Host "SMOKE SUITE FAILED" -ForegroundColor Red
	exit 1
}
Write-Host "SMOKE SUITE OK" -ForegroundColor Green
exit 0
