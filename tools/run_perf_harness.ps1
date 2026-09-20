[CmdletBinding()]
param(
	[string]$ProjectRoot = "",
	[string]$GodotBin = "",
	[string]$OutputPath = "",
	[string]$ScenarioFilter = ""
)

## Fixed-seed performance scenario harness (T3).
##
## Runs tests/performance_scenario_harness.gd headlessly and prints a PERF_
## line per scenario plus a PERF_BASELINE_ summary. Use it to establish the
## desktop and mobile (e.g. Samsung A17) baselines described in
## docs/long-term-composition-and-performance-plan.md. Output is machine
## parseable; optionally write it to a file with -OutputPath.
##
## The same script can run on a device build; point -GodotBin at the device
## export or pass the harness through the normal mobile export flow and capture
## stdout from the device.

$ErrorActionPreference = "Stop"
$ProjectRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { Split-Path -Parent $PSScriptRoot } else { $ProjectRoot }
$GodotBin = if ([string]::IsNullOrWhiteSpace($GodotBin)) {
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) { $env:GODOT_BIN } else { "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" }
} else { $GodotBin }
if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
	throw "Godot executable not found: $GodotBin. Set GODOT_BIN or pass -GodotBin."
}
$harnessScript = "res://tests/performance_scenario_harness.gd"
$tempRoot = $env:RUNNER_TEMP
if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = $env:TEMP }
if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = [System.IO.Path]::GetTempPath() }
$userDataDir = Join-Path $tempRoot ("tiny-demons-perf-{0}" -f $PID)
$logFile = Join-Path $userDataDir "perf.log"
New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null

if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "tests/performance_scenario_harness.gd"))) {
	throw "Scenario harness not found: $harnessScript"
}

$importArguments = @(
	"--headless",
	"--import",
	"--audio-driver", "Dummy",
	"--user-data-dir", $userDataDir,
	"--path", $ProjectRoot,
	"--log-file", $logFile
)
& $GodotBin @importArguments
if ($LASTEXITCODE -ne 0) {
	throw "Godot import failed with exit code $LASTEXITCODE"
}

$arguments = @(
	"--headless",
	"--audio-driver", "Dummy",
	"--user-data-dir", $userDataDir,
	"--path", $ProjectRoot,
	"--log-file", $logFile,
	"-s", $harnessScript
)

$output = @(& $GodotBin @arguments 2>&1)
$exitCode = $LASTEXITCODE

$perfLines = @($output | Where-Object { $_ -match '^PERF_' })
if ($perfLines.Count -gt 0) {
	foreach ($line in $perfLines) {
		Write-Host $line -ForegroundColor Cyan
	}
	if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
		$perfLines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
		Write-Host "PERF_WRITTEN $OutputPath" -ForegroundColor Green
	}
} else {
	Write-Host "PERF_FAILED no scenario output (exit $exitCode); log: $logFile" -ForegroundColor Red
	$output | Select-Object -Last 20 | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
	exit 1
}

if ($exitCode -ne 0) {
	Write-Host "PERF_ENGINE_EXIT $exitCode (harness finished but engine reported nonzero)" -ForegroundColor Yellow
}

exit 0
