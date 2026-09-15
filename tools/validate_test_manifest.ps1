param(
	[string]$ManifestPath = "",
	[string]$TestsDirectory = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedManifestPath = if ($ManifestPath) { $ManifestPath } else { Join-Path $projectRoot "tests/manifest.csv" }
$resolvedTestsDirectory = if ($TestsDirectory) { $TestsDirectory } else { Join-Path $projectRoot "tests" }

if (-not (Test-Path -LiteralPath $resolvedManifestPath -PathType Leaf)) {
	throw "Test manifest not found: $resolvedManifestPath"
}
if (-not (Test-Path -LiteralPath $resolvedTestsDirectory -PathType Container)) {
	throw "Tests directory not found: $resolvedTestsDirectory"
}

$requiredColumns = @("script", "role", "state", "owner", "target", "load", "notes")
$allowedRoles = @("gate", "owner", "reference", "diagnostic", "report")
$allowedStates = @("verified", "open", "stale", "harness", "environment", "unverified", "superseded")
$allowedLoads = @("main", "pure", "scene", "fixture")
$manifest = @(Import-Csv -LiteralPath $resolvedManifestPath)
$errors = [System.Collections.Generic.List[string]]::new()

if ($manifest.Count -eq 0) {
	$errors.Add("Manifest is empty")
} else {
	$actualColumns = @($manifest[0].PSObject.Properties.Name)
	foreach ($column in $requiredColumns) {
		if ($column -notin $actualColumns) {
			$errors.Add("Manifest is missing required column '$column'")
		}
	}
}

$manifestByScript = @{}
foreach ($row in $manifest) {
	$scriptName = [string]$row.script
	if ([string]::IsNullOrWhiteSpace($scriptName)) {
		$errors.Add("Manifest contains a row with an empty script name")
		continue
	}
	if ($manifestByScript.ContainsKey($scriptName)) {
		$errors.Add("Manifest contains duplicate script '$scriptName'")
	} else {
		$manifestByScript[$scriptName] = $row
	}

	foreach ($field in @("role", "state", "owner", "target", "load")) {
		if ([string]::IsNullOrWhiteSpace([string]$row.$field)) {
			$errors.Add("Manifest row '$scriptName' has an empty $field")
		}
	}
	if ([string]$row.role -notin $allowedRoles) {
		$errors.Add("Manifest row '$scriptName' has unsupported role '$($row.role)'")
	}
	if ([string]$row.state -notin $allowedStates) {
		$errors.Add("Manifest row '$scriptName' has unsupported state '$($row.state)'")
	}
	if ([string]$row.load -notin $allowedLoads) {
		$errors.Add("Manifest row '$scriptName' has unsupported load kind '$($row.load)'")
	}
	if ($scriptName -notmatch '^[a-z0-9_]+$') {
		$errors.Add("Manifest row '$scriptName' is not a safe test basename")
	}
	$scriptPath = Join-Path $resolvedTestsDirectory ("{0}.gd" -f $scriptName)
	if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
		$errors.Add("Manifest row '$scriptName' has no matching file '$scriptPath'")
	}
}

$diskScripts = @(Get-ChildItem -LiteralPath $resolvedTestsDirectory -Filter "*.gd" -File | ForEach-Object { $_.BaseName })
foreach ($scriptName in $diskScripts) {
	if (-not $manifestByScript.ContainsKey($scriptName)) {
		$errors.Add("Test script '$scriptName.gd' is not registered in manifest.csv")
	}
}

if ($errors.Count -gt 0) {
	Write-Host "TEST_MANIFEST_INVALID" -ForegroundColor Red
	foreach ($errorMessage in $errors) {
		Write-Host ("- {0}" -f $errorMessage) -ForegroundColor Red
	}
	exit 1
}

$runnableCount = @($manifest | Where-Object { $_.role -ne "report" }).Count
$reportCount = @($manifest | Where-Object { $_.role -eq "report" }).Count
$gateCount = @($manifest | Where-Object { $_.role -eq "gate" }).Count
Write-Host ("TEST_MANIFEST_OK rows={0} runnable={1} reports={2} gate={3}" -f $manifest.Count, $runnableCount, $reportCount, $gateCount) -ForegroundColor Green
exit 0
