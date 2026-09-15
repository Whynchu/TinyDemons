param(
	[string]$BaselinePath = "",
	[string]$ScriptsDirectory = "",
	[switch]$UpdateBaseline,
	[switch]$RequireTargets,
	[switch]$SelfTest
)

## Composition ownership guardrail.
##
## The default mode is a regression gate. It protects the last accepted
## composition baseline while the strict ownership work is in progress.
## -RequireTargets is the opt-in completion audit: it fails until the target
## thresholds in composition-baseline.json are met.
##
## The guard checks:
##
##   1. No context stores or accepts GameplayState outside the transitional
##      allowlist recorded in the baseline JSON.
##   2. No completed context relies on `context.runtime`.
##   3. No new parallel `*_legacy` / `*_context` duplicate implementations.
##   4. No root-access, GameplayState, or RoomController size regression.
##
## Use -UpdateBaseline only after a reviewed slice deliberately retires
## coupling or extracts an owner. The command refuses to write a baseline when
## the current tree has a regression.

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedScriptsDirectory = if ($ScriptsDirectory) { $ScriptsDirectory } else { Join-Path $projectRoot "scripts" }
$resolvedBaselinePath = if ($BaselinePath) { $BaselinePath } else { Join-Path $PSScriptRoot "composition-baseline.json" }

$defaultTargets = [ordered]@{
	root_accesses_max = 2499
	gameplay_state_lines_max = 1719
	gameplay_state_fields_max = 286
	room_controller_lines_max = 2296
	runtime_refs_max = 0
	legacy_pairs_max = 0
	transitional_contexts_max = 0
}

function Get-CodeOnlyContent([string]$Content) {
	# GDScript comments are line comments. Keep inline code intact and remove
	# full-line documentation before checking architectural tokens.
	$codeLines = foreach ($line in ($Content -split "`r?`n")) {
		if ($line.TrimStart().StartsWith("#")) {
			continue
		}
		$line
	}
	return ($codeLines -join "`n")
}

function Get-PropertyValue($Object, [string]$Name) {
	if ($null -eq $Object -or $null -eq $Object.PSObject.Properties[$Name]) {
		return $null
	}
	return $Object.PSObject.Properties[$Name].Value
}

function Get-PropertyInfo($Object, [string]$Name) {
	if ($null -eq $Object) {
		return $null
	}
	return $Object.PSObject.Properties[$Name]
}

function Get-IntegerBaseline($Baseline, [string]$Name, [int]$Fallback) {
	$value = Get-PropertyValue $Baseline $Name
	if ($null -ne $value) {
		return [int]$value
	}
	return $Fallback
}

function Get-TargetValue($Targets, [string]$Name, [int]$Fallback) {
	$value = Get-PropertyValue $Targets $Name
	if ($null -ne $value) {
		return [int]$value
	}
	return $Fallback
}

function Get-FunctionBodyInfo([string[]]$Lines, [int]$FunctionLineIndex) {
	$body = [System.Collections.Generic.List[string]]::new()
	for ($index = $FunctionLineIndex + 1; $index -lt $Lines.Count; $index += 1) {
		if ($Lines[$index] -match '^\s*(?:static\s+)?func\s+[A-Za-z_]\w*\s*\(') {
			break
		}
		$body.Add($Lines[$index])
	}
	$codeLines = @(
		$body |
			ForEach-Object {
				$line = $_ -replace '\s+#.*$', ''
				if ($line.Trim() -ne '') { $line.Trim() }
			} |
			Where-Object { $_ }
	)
	return [PSCustomObject]@{
		Lines = $codeLines
		IsForward = $codeLines.Count -eq 1 -and (
			$codeLines[0] -match '(?:^|\b)return\s+.*(?:_?[A-Za-z_]\w*_context\s*\(|call\(\s*["'']_?[A-Za-z_]\w*_context["'']\s*[,)]?)' -or
			$codeLines[0] -match '^_?[A-Za-z_]\w*_context\s*\('
		)
	}
}

function Get-LegacyAudit([System.IO.FileInfo[]]$Files) {
	$legacyCount = 0
	$legacyPairs = [System.Collections.Generic.List[string]]::new()
	foreach ($file in $Files) {
		$lines = @(Get-Content -LiteralPath $file.FullName)
		$content = Get-Content -Raw -LiteralPath $file.FullName
		$codeContent = Get-CodeOnlyContent $content
		for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex += 1) {
			if ($lines[$lineIndex] -notmatch '^\s*(?:static\s+)?func\s+(_\w+)_legacy\s*\(') {
				continue
			}
			$baseName = $Matches[1]
			$legacyCount += 1
			$bodyInfo = Get-FunctionBodyInfo $lines $lineIndex
			$stem = $baseName.TrimStart("_")
			$contextPattern = '(?m)^\s*(?:static\s+)?func\s+_?' + [regex]::Escape($stem) + '_context\s*\('
			$hasContextTwin = [regex]::IsMatch($codeContent, $contextPattern)
			if ($hasContextTwin -and -not $bodyInfo.IsForward) {
				$legacyPairs.Add("$($file.Name):$baseName")
			}
		}
	}
	return [PSCustomObject]@{
		Count = $legacyCount
		Pairs = @($legacyPairs | Sort-Object -Unique)
	}
}

function Invoke-ValidatorForSelfTest([string]$FixtureScripts, [string]$FixtureBaseline, [switch]$FixtureRequireTargets) {
	$arguments = @(
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", $PSCommandPath,
		"-ScriptsDirectory", $FixtureScripts,
		"-BaselinePath", $FixtureBaseline
	)
	if ($FixtureRequireTargets) {
		$arguments += "-RequireTargets"
	}
	$script:SelfTestLastOutput = @(& pwsh @arguments 2>&1) -join "`n"
	return $LASTEXITCODE
}

if ($SelfTest) {
	$selfTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tiny-demons-composition-validator-" + [guid]::NewGuid().ToString("N"))
	$fixtureScripts = Join-Path $selfTestRoot "scripts"
	$fixtureBaseline = Join-Path $selfTestRoot "baseline.json"
	New-Item -ItemType Directory -Path $fixtureScripts -Force | Out-Null
	try {
		Set-Content -LiteralPath (Join-Path $fixtureScripts "gameplay_state.gd") -Value "var state = 0" -Encoding UTF8
		Set-Content -LiteralPath (Join-Path $fixtureScripts "room_controller.gd") -Value "extends Node" -Encoding UTF8
		Set-Content -LiteralPath (Join-Path $fixtureScripts "fixture_context.gd") -Value @(
			"extends RefCounted",
			"class_name FixtureContext",
			"var profile: Object = null"
		) -Encoding UTF8
		Set-Content -LiteralPath (Join-Path $fixtureScripts "forward.gd") -Value @(
			"extends RefCounted",
			"func _sample_context(value: Object) -> void:",
			"    pass",
			"",
			"func _sample_legacy(value: Object) -> void:",
			"    return _sample_context(value)"
		) -Encoding UTF8
		$fixtureBaselineObject = [ordered]@{
			root_accesses = 0
			gameplay_state_lines = 1
			gameplay_state_fields = 1
			room_controller_lines = 1
			runtime_refs = 0
			legacy_total = 1
			legacy_pairs = @()
			transitional_allowlist = @()
			targets = [ordered]@{
				root_accesses_max = 0
				gameplay_state_lines_max = 1
				gameplay_state_fields_max = 1
				room_controller_lines_max = 1
				runtime_refs_max = 0
				legacy_pairs_max = 0
				transitional_contexts_max = 0
			}
		}
		$fixtureBaselineObject | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixtureBaseline -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $fixtureScripts $fixtureBaseline) -ne 0) {
			throw "valid fixture was rejected`n$script:SelfTestLastOutput"
		}

		Set-Content -LiteralPath (Join-Path $fixtureScripts "bad_context.gd") -Value @(
			"extends RefCounted",
			"class_name BadContext",
			"var runtime: GameplayState = null"
		) -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $fixtureScripts $fixtureBaseline) -eq 0) {
			throw "GameplayState context coupling was not rejected`n$script:SelfTestLastOutput"
		}
		Remove-Item -LiteralPath (Join-Path $fixtureScripts "bad_context.gd") -Force

		Set-Content -LiteralPath (Join-Path $fixtureScripts "duplicate.gd") -Value @(
			"extends RefCounted",
			"func _sample_context(value: Object) -> void:",
			"    pass",
			"",
			"func _sample_legacy(value: Object) -> void:",
			"    pass"
		) -Encoding UTF8
		$sameCountBaseline = Join-Path $selfTestRoot "same-count-baseline.json"
		$sameCountBaselineObject = $fixtureBaselineObject | ConvertTo-Json -Depth 5 | ConvertFrom-Json
		$sameCountBaselineObject.legacy_total = 2
		$sameCountBaselineObject.legacy_pairs = @("approved.gd:_approved")
		$sameCountBaselineObject | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $sameCountBaseline -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $fixtureScripts $sameCountBaseline) -eq 0) {
			throw "parallel legacy/context implementation was not rejected`n$script:SelfTestLastOutput"
		}
		Remove-Item -LiteralPath (Join-Path $fixtureScripts "duplicate.gd") -Force

		Set-Content -LiteralPath (Join-Path $fixtureScripts "root_access.gd") -Value @(
			"extends RefCounted",
			"func use_root(root: Object) -> void:",
			'    root.call("example")'
		) -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $fixtureScripts $fixtureBaseline) -eq 0) {
			throw "root-access regression was not rejected`n$script:SelfTestLastOutput"
		}
		Remove-Item -LiteralPath (Join-Path $fixtureScripts "root_access.gd") -Force

		$strictScripts = Join-Path $selfTestRoot "strict-scripts"
		Copy-Item -LiteralPath $fixtureScripts -Destination $strictScripts -Recurse
		Set-Content -LiteralPath (Join-Path $strictScripts "root_access.gd") -Value @(
			"extends RefCounted",
			"func use_root(root: Object) -> void:",
			'    root.call("example")'
		) -Encoding UTF8
		$strictBaseline = Join-Path $selfTestRoot "strict-baseline.json"
		$strictBaselineObject = $fixtureBaselineObject | ConvertTo-Json -Depth 5 | ConvertFrom-Json
		$strictBaselineObject.root_accesses = 1
		$strictBaselineObject.targets.root_accesses_max = 0
		$strictBaselineObject | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $strictBaseline -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $strictScripts $strictBaseline) -ne 0) {
			throw "valid regression fixture was rejected before strict target audit`n$script:SelfTestLastOutput"
		}
		if ((Invoke-ValidatorForSelfTest $strictScripts $strictBaseline -FixtureRequireTargets) -eq 0) {
			throw "strict target failure was not enforced`n$script:SelfTestLastOutput"
		}
		Write-Host "COMPOSITION_SELF_TEST_OK" -ForegroundColor Green
	}
	finally {
		if (Test-Path -LiteralPath $selfTestRoot) {
			Remove-Item -LiteralPath $selfTestRoot -Recurse -Force
		}
	}
	exit 0
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$baseline = $null
if (Test-Path -LiteralPath $resolvedBaselinePath) {
	$baseline = Get-Content -Raw -LiteralPath $resolvedBaselinePath | ConvertFrom-Json
} else {
	$errors.Add("No baseline file at $resolvedBaselinePath")
}

$allowlistProperty = Get-PropertyInfo $baseline "transitional_allowlist"
$transitionalAllowlist = if ($null -ne $allowlistProperty) {
	@($allowlistProperty.Value | ForEach-Object { [string]$_ })
} else {
	$errors.Add("Baseline has no transitional_allowlist; refusing to run with an implicit allowlist")
	@()
}

$targetsValue = Get-PropertyValue $baseline "targets"
$targetValues = [ordered]@{}
if ($null -eq $targetsValue) {
	$errors.Add("Baseline has no targets object; refusing to run without recorded strict targets")
}
foreach ($targetName in $defaultTargets.Keys) {
	if ($null -ne $targetsValue -and $null -eq (Get-PropertyInfo $targetsValue $targetName)) {
		$errors.Add("Baseline targets object is missing '$targetName'; refusing to use an implicit target.")
	}
	$targetValues[$targetName] = Get-TargetValue $targetsValue $targetName $defaultTargets[$targetName]
}
$requiredBaselineMetrics = @(
	"root_accesses",
	"gameplay_state_lines",
	"gameplay_state_fields",
	"room_controller_lines",
	"runtime_refs",
	"legacy_total"
)
foreach ($metricName in $requiredBaselineMetrics) {
	if ($null -eq (Get-PropertyInfo $baseline $metricName)) {
		$errors.Add("Baseline is missing required metric '$metricName'; refusing to use an implicit value.")
	}
}

if (-not (Test-Path -LiteralPath $resolvedScriptsDirectory)) {
	$errors.Add("Scripts directory does not exist: $resolvedScriptsDirectory")
}

$contextFiles = @()
$scriptFiles = @()
if (Test-Path -LiteralPath $resolvedScriptsDirectory) {
	$contextFiles = @(Get-ChildItem -LiteralPath $resolvedScriptsDirectory -Filter "*context*.gd" -File)
	$scriptFiles = @(Get-ChildItem -LiteralPath $resolvedScriptsDirectory -Filter "*.gd" -File)
}

# ---- 1. Contexts: GameplayState coupling and .runtime use ----
$transitionalFound = [System.Collections.Generic.List[string]]::new()
foreach ($file in $contextFiles) {
	$content = Get-Content -Raw -LiteralPath $file.FullName
	$codeContent = Get-CodeOnlyContent $content
	$className = ""
	$classMatch = [regex]::Match($content, '(?m)^class_name\s+(\w+)')
	if ($classMatch.Success) {
		$className = $classMatch.Groups[1].Value
	}
	if ($className -in $transitionalAllowlist) {
		if ($className -notin $transitionalFound) {
			$transitionalFound.Add($className)
		}
		continue
	}
	if ($codeContent -match '\bGameplayState\b') {
		$errors.Add("Context '$className' ($($file.Name)) stores or accepts GameplayState but is not on the JSON transitional allowlist")
	}
	if ($codeContent -match '\.runtime\b') {
		$errors.Add("Context '$className' ($($file.Name)) references '.runtime' but is not a transitional adapter")
	}
}
$missingAllowlist = @($transitionalAllowlist | Where-Object { $_ -notin $transitionalFound })
if ($missingAllowlist.Count -gt 0) {
	$errors.Add("Transitional allowlist is stale; missing context classes: $($missingAllowlist -join ', ')")
}

# ---- 2. Parallel legacy duplicates ----
$legacyAudit = Get-LegacyAudit $scriptFiles
$legacyCount = $legacyAudit.Count
$legacyPairs = @($legacyAudit.Pairs)
$baselineLegacyPairsProperty = Get-PropertyInfo $baseline "legacy_pairs"
$baselineLegacyPairs = if ($null -ne $baselineLegacyPairsProperty) {
	@($baselineLegacyPairsProperty.Value | ForEach-Object { [string]$_ })
} else {
	$errors.Add("Baseline has no legacy_pairs inventory; refusing to run without a pair-level duplicate baseline")
	@()
}
foreach ($pair in $legacyPairs) {
	if ($pair -notin $baselineLegacyPairs -and $null -ne $baselineLegacyPairsProperty) {
		$errors.Add("New parallel legacy/context implementation: $pair")
	}
}

# ---- 3. Metrics ----
$rootAccesses = 0
$gameplayStateLines = 0
$gameplayStateFields = 0
$roomControllerLines = 0
$runtimeRefs = 0
foreach ($file in $scriptFiles) {
	$content = Get-Content -Raw -LiteralPath $file.FullName
	$codeContent = Get-CodeOnlyContent $content
	$rootAccesses += ([regex]::Matches($codeContent, 'root\.(call|get|set)\(')).Count
	$runtimeRefs += ([regex]::Matches($codeContent, '\.runtime\b')).Count
}
$gsPath = Join-Path $resolvedScriptsDirectory "gameplay_state.gd"
if (Test-Path -LiteralPath $gsPath) {
	$gsLines = @(Get-Content -LiteralPath $gsPath)
	$gameplayStateLines = $gsLines.Count
	$gameplayStateFields = @($gsLines | Where-Object { $_ -match '^(var|const)\s' }).Count
}
$rcPath = Join-Path $resolvedScriptsDirectory "room_controller.gd"
if (Test-Path -LiteralPath $rcPath) {
	$roomControllerLines = @(Get-Content -LiteralPath $rcPath).Count
}

# ---- 4. Baseline comparison ----
$rootBaseline = Get-IntegerBaseline $baseline "root_accesses" 3140
$gsLinesBaseline = Get-IntegerBaseline $baseline "gameplay_state_lines" 1720
$gsFieldsBaseline = Get-IntegerBaseline $baseline "gameplay_state_fields" 287
$rcLinesBaseline = Get-IntegerBaseline $baseline "room_controller_lines" 2297
$runtimeBaseline = Get-IntegerBaseline $baseline "runtime_refs" 20
$legacyBaseline = Get-IntegerBaseline $baseline "legacy_total" 13

if ($rootAccesses -gt $rootBaseline) {
	$errors.Add("Root-access regression: $rootAccesses > baseline $rootBaseline")
}
if ($gameplayStateLines -gt $gsLinesBaseline) {
	$errors.Add("GameplayState line regression: $gameplayStateLines > baseline $gsLinesBaseline")
}
if ($gameplayStateFields -gt $gsFieldsBaseline) {
	$errors.Add("GameplayState field regression: $gameplayStateFields > baseline $gsFieldsBaseline")
}
if ($roomControllerLines -gt $rcLinesBaseline) {
	$errors.Add("RoomController size regression: $roomControllerLines > baseline $rcLinesBaseline")
}
if ($runtimeRefs -gt $runtimeBaseline) {
	$errors.Add(".runtime reference regression: $runtimeRefs > baseline $runtimeBaseline")
}
if ($legacyCount -gt $legacyBaseline) {
	$errors.Add("Legacy duplicate regression: $legacyCount > baseline $legacyBaseline")
}

if ($RequireTargets) {
	if ($rootAccesses -gt $targetValues.root_accesses_max) {
		$errors.Add("Strict target not met: root accesses $rootAccesses > $($targetValues.root_accesses_max)")
	}
	if ($gameplayStateLines -gt $targetValues.gameplay_state_lines_max) {
		$errors.Add("Strict target not met: GameplayState lines $gameplayStateLines > $($targetValues.gameplay_state_lines_max)")
	}
	if ($gameplayStateFields -gt $targetValues.gameplay_state_fields_max) {
		$errors.Add("Strict target not met: GameplayState fields $gameplayStateFields > $($targetValues.gameplay_state_fields_max)")
	}
	if ($roomControllerLines -gt $targetValues.room_controller_lines_max) {
		$errors.Add("Strict target not met: RoomController lines $roomControllerLines > $($targetValues.room_controller_lines_max)")
	}
	if ($runtimeRefs -gt $targetValues.runtime_refs_max) {
		$errors.Add("Strict target not met: .runtime references $runtimeRefs > $($targetValues.runtime_refs_max)")
	}
	if ($legacyPairs.Count -gt $targetValues.legacy_pairs_max) {
		$errors.Add("Strict target not met: legacy/context duplicate pairs $($legacyPairs.Count) > $($targetValues.legacy_pairs_max)")
	}
	if ($transitionalFound.Count -gt $targetValues.transitional_contexts_max) {
		$errors.Add("Strict target not met: transitional contexts $($transitionalFound.Count) > $($targetValues.transitional_contexts_max)")
	}
}

# ---- 5. Output and baseline update ----
Write-Host "COMPOSITION_AUDIT" -ForegroundColor Cyan
Write-Host "  mode              : $(if ($RequireTargets) { 'strict targets' } else { 'regression floor' })"
Write-Host "  root.call/get/set : $rootAccesses (baseline $rootBaseline; target <= $($targetValues.root_accesses_max))"
Write-Host "  GameplayState     : $gameplayStateLines lines / $gameplayStateFields fields (baseline $gsLinesBaseline / $gsFieldsBaseline)"
Write-Host "  RoomController    : $roomControllerLines lines (baseline $rcLinesBaseline; target <= $($targetValues.room_controller_lines_max))"
Write-Host "  .runtime refs     : $runtimeRefs (baseline $runtimeBaseline; target <= $($targetValues.runtime_refs_max))"
Write-Host "  legacy duplicates : $legacyCount total / $($legacyPairs.Count) paired (baseline $legacyBaseline / $(($baselineLegacyPairs | Measure-Object).Count))"
Write-Host "  contexts          : $($contextFiles.Count) files; $($transitionalFound.Count) transitional allowlisted"
foreach ($pair in $legacyPairs) {
	Write-Host "  duplicate pair: $pair" -ForegroundColor Yellow
}

if ($UpdateBaseline) {
	if ($errors.Count -gt 0) {
		$errors.Add("Refusing -UpdateBaseline because the current tree has audit errors")
	} elseif ($null -eq $baseline) {
		$errors.Add("Refusing -UpdateBaseline because no baseline JSON was loaded")
	} else {
		$newBaseline = [ordered]@{
			root_accesses = $rootAccesses
			gameplay_state_lines = $gameplayStateLines
			gameplay_state_fields = $gameplayStateFields
			room_controller_lines = $roomControllerLines
			runtime_refs = $runtimeRefs
			legacy_total = $legacyCount
			legacy_pairs = $legacyPairs
			transitional_allowlist = $transitionalAllowlist
			targets = $targetValues
		}
		$newBaseline | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resolvedBaselinePath -Encoding UTF8
		Write-Host "COMPOSITION_BASELINE_UPDATED" -ForegroundColor Green
	}
}

foreach ($warning in $warnings) {
	Write-Host "WARN: $warning" -ForegroundColor Yellow
}

if ($errors.Count -gt 0) {
	Write-Host "COMPOSITION_AUDIT_FAILED" -ForegroundColor Red
	foreach ($errorMessage in $errors) {
		Write-Host "- $errorMessage" -ForegroundColor Red
	}
	exit 1
}
Write-Host "COMPOSITION_AUDIT_OK" -ForegroundColor Green
exit 0
