param(
	[string]$BaselinePath = "",
	[string]$ScriptsDirectory = "",
	[switch]$UpdateBaseline
)

## Composition ownership guardrail.
##
## Enforces the four hard gates in docs/composition-refactor-analysis.md so the
## strict ownership score cannot drift back into claimed-but-unmeasured progress:
##
##   1. No context stores or accepts GameplayState outside the transitional
##      allowlist.
##   2. No completed (non-allowlisted) context relies on `context.runtime`.
##   3. No new parallel `*_legacy` / `*_context` duplicate implementations.
##   4. No root-access, GameplayState, or RoomController size regression vs the
##      recorded baseline.
##
## A gate that is already open (e.g. RoomController larger than the target) is a
## report, not a failure. A regression that makes a metric worse than the last
## recorded baseline is a failure. Use -UpdateBaseline only when a slice
## deliberately lands and you are recording the new accepted state.

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedScriptsDirectory = if ($ScriptsDirectory) { $ScriptsDirectory } else { Join-Path $projectRoot "scripts" }
$resolvedBaselinePath = if ($BaselinePath) { $BaselinePath } else { Join-Path $PSScriptRoot "composition-baseline.json" }

# The transitional allowlist. These contexts may store GameplayState or inherit
# it (RoomSpawnContext / RoomRespawnContext extend RoomRuntimeContext). Direct
# contexts must never be added here.
$transitionalAllowlist = @(
	"RoomEntryContext",
	"RoomActivationContext",
	"RoomRuntimeContext",
	"RoomSpawnContext",
	"RoomRespawnContext"
)

$allowedRoles = @("gate", "owner", "reference", "diagnostic", "report")
$allowedStates = @("verified", "open", "stale", "harness", "environment", "unverified", "superseded")
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

# ---- 1. Contexts: GameplayState coupling and .runtime use ----
$contextFiles = @(Get-ChildItem -LiteralPath $resolvedScriptsDirectory -Filter "*context*.gd" -File)
$transitionalFound = @()
foreach ($file in $contextFiles) {
	$content = Get-Content -Raw -LiteralPath $file.FullName
	$className = ""
	$m = [regex]::Match($content, '(?m)^class_name\s+(\w+)')
	if ($m.Success) { $className = $m.Groups[1].Value }
	if ($className -in $transitionalAllowlist) {
		$transitionalFound += $className
		continue
	}
	# A real GameplayState field or constructor parameter is a coupling signal.
	# Comments and documentation strings that mention GameplayState are not.
	$hasField = [regex]::IsMatch($content, '(?m)^\s*(?:var|@export)\s+[A-Za-z_]\w*\s*:\s*GameplayState\b')
	$hasParam = [regex]::IsMatch($content, 'GameplayState\s+\w+\s*[,)]')
	if ($hasField -or $hasParam) {
		$errors.Add("Context '$className' ($($file.Name)) stores or accepts GameplayState but is not on the transitional allowlist")
	}
	# Completed contexts must not reach back through a runtime handle.
	if ($content -match '\.runtime\b') {
		$errors.Add("Context '$className' ($($file.Name)) references '.runtime' but is not a transitional adapter")
	}
}
if ($transitionalFound.Count -ne $transitionalAllowlist.Count) {
	$missing = @($transitionalAllowlist | Where-Object { $_ -notin $transitionalFound })
	$warnings.Add("Transitional allowlist drift: expected $($transitionalAllowlist.Count), found $($transitionalFound.Count); missing: $($missing -join ', '). This is fine if a slice retired them, otherwise the allowlist is stale.")
}

# ---- 2. Parallel legacy duplicates ----
$legacyCount = 0
$legacyPairs = [System.Collections.Generic.List[string]]::new()
$scriptFiles = @(Get-ChildItem -LiteralPath $resolvedScriptsDirectory -Filter "*.gd" -File)
foreach ($file in $scriptFiles) {
	$content = Get-Content -Raw -LiteralPath $file.FullName
	foreach ($legacyMatch in [regex]::Matches($content, '(?m)^\s*func\s+(_\w+)_legacy\s*\(')) {
		$baseName = $legacyMatch.Groups[1].Value
		$legacyCount += 1
		# A legacy body that is a one-line forward to the _context version is
		# acceptable. Anything larger is a parallel duplicate implementation.
		$start = $legacyMatch.Index
		$openBrace = $content.IndexOf("{", $start)
		$nextFunc = $content.IndexOf("^func", $start + 1)
		$bodyEnd = if ($nextFunc -gt $openBrace) { $nextFunc } else { [Math]::Min($content.Length, $openBrace + 120) }
		$body = $content.Substring($openBrace + 1, [Math]::Max(0, $bodyEnd - $openBrace - 1))
		$isForward = ($body -match 'call\("_\w+_context"' -or $body -match 'return\s+.*_context\(') -and $body.Trim().Count("`n") -le 1
		# The context twin may keep the same stem with or without the leading
		# underscore (e.g. _enter_connected_room_legacy -> enter_connected_room_context).
		$stem = $baseName.TrimStart("_")
		$hasContextTwin = [regex]::IsMatch($content, "func\s+$stem`_context\s*\(") -or [regex]::IsMatch($content, "func\s+_$stem`_context\s*\(")
		if ($hasContextTwin -and -not $isForward) {
			$legacyPairs.Add("$($file.Name):$baseName")
		}
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
	$rootAccesses += ([regex]::Matches($content, 'root\.(call|get|set)\(')).Count
	$runtimeRefs += ([regex]::Matches($content, '\.runtime\b')).Count
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
$baseline = @{}
if (Test-Path -LiteralPath $resolvedBaselinePath) {
	$baseline = Get-Content -Raw -LiteralPath $resolvedBaselinePath | ConvertFrom-Json
} else {
	$warnings.Add("No baseline file at $resolvedBaselinePath; recording current values with -UpdateBaseline is recommended before CI wiring.")
}

function Get-BaselineValue($key, $fallback) {
	if ($null -ne $baseline -and $null -ne $baseline.$key) { return [int]$baseline.$key }
	return $fallback
}

$rootBaseline = Get-BaselineValue "root_accesses" 3140
$gsLinesBaseline = Get-BaselineValue "gameplay_state_lines" 1720
$gsFieldsBaseline = Get-BaselineValue "gameplay_state_fields" 287
$rcLinesBaseline = Get-BaselineValue "room_controller_lines" 2297
$runtimeBaseline = Get-BaselineValue "runtime_refs" 20
$legacyBaseline = Get-BaselineValue "legacy_total" 13

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

# ---- 5. Output ----
Write-Host "COMPOSITION_AUDIT" -ForegroundColor Cyan
Write-Host "  root.call/get/set : $rootAccesses (baseline $rootBaseline)"
Write-Host "  GameplayState     : $gameplayStateLines lines / $gameplayStateFields fields (baseline $gsLinesBaseline / $gsFieldsBaseline)"
Write-Host "  RoomController    : $roomControllerLines lines (baseline $rcLinesBaseline)"
Write-Host "  .runtime refs     : $runtimeRefs (baseline $runtimeBaseline)"
Write-Host "  legacy duplicates : $legacyCount (baseline $legacyBaseline)"
Write-Host "  contexts          : $($contextFiles.Count) files; $($transitionalFound.Count) transitional allowlisted"
foreach ($pair in $legacyPairs) {
	Write-Host "  duplicate pair: $pair" -ForegroundColor Yellow
}

if ($UpdateBaseline) {
	$newBaseline = [ordered]@{
		root_accesses = $rootAccesses
		gameplay_state_lines = $gameplayStateLines
		gameplay_state_fields = $gameplayStateFields
		room_controller_lines = $roomControllerLines
		runtime_refs = $runtimeRefs
		legacy_total = $legacyCount
		transitional_allowlist = $transitionalAllowlist
	}
	$newBaseline | ConvertTo-Json | Set-Content -LiteralPath $resolvedBaselinePath -Encoding UTF8
	Write-Host "COMPOSITION_BASELINE_UPDATED" -ForegroundColor Green
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