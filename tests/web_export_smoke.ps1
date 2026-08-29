[CmdletBinding()]
param(
	[switch]$RequireExport
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godotVersion = if ($env:GODOT_VERSION) { $env:GODOT_VERSION } else { "4.7.1" }
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" }
$presetText = Get-Content -LiteralPath (Join-Path $root "export_presets.cfg") -Raw
$projectText = Get-Content -LiteralPath (Join-Path $root "project.godot") -Raw
foreach ($requiredPresetValue in @('[preset.0]', 'platform="Web"', 'export_path="dist/index.html"', 'variant/thread_support=false', 'progressive_web_app/enabled=true', 'progressive_web_app/icon_144x144="res://assets/artwork/player_UI_portrait_pwa_144.png"', 'progressive_web_app/icon_180x180="res://assets/artwork/player_UI_portrait_pwa_180.png"', 'progressive_web_app/icon_512x512="res://assets/artwork/player_UI_portrait_pwa_512.png"', 'image-rendering:pixelated')) {
	if (-not $presetText.Contains($requiredPresetValue)) { throw "Web preset is missing $requiredPresetValue" }
}
if (-not $projectText.Contains('renderer/rendering_method.web="gl_compatibility"')) {
	throw "Web renderer override is missing from project.godot"
}
Write-Host "WEB_EXPORT_CONFIG_OK: single-threaded Compatibility preset and renderer override" -ForegroundColor Green
$templateCandidates = @()
if ($env:XDG_DATA_HOME) {
	$templateCandidates += Join-Path $env:XDG_DATA_HOME ("godot/export_templates/{0}.stable/web_nothreads_release.zip" -f $godotVersion)
}
if ($env:APPDATA) {
	$templateCandidates += Join-Path $env:APPDATA ("Godot/export_templates/{0}.stable/web_nothreads_release.zip" -f $godotVersion)
}
$hasTemplate = $false
foreach ($candidate in $templateCandidates) {
	if (Test-Path -LiteralPath $candidate) {
		$hasTemplate = $true
		break
	}
}

if (-not (Test-Path -LiteralPath $godot)) {
	if ($RequireExport) { throw "Godot executable not found: $godot" }
	Write-Host "WEB_EXPORT_SMOKE_SKIPPED: Godot executable not found ($godot)" -ForegroundColor Yellow
	exit 0
}
if (-not $hasTemplate) {
	if ($RequireExport) { throw "Godot $godotVersion single-threaded Web release template not found. Install web_nothreads_release.zip before running this check." }
	Write-Host "WEB_EXPORT_SMOKE_SKIPPED: Godot $godotVersion Web release template is not installed" -ForegroundColor Yellow
	exit 0
}

$outputDir = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$exportPath = Join-Path $outputDir "index.html"
$arguments = @("--headless", "--path", $root, "--export-release", "Web", $exportPath)
& $godot @arguments
if ($LASTEXITCODE -ne 0) {
	throw "Godot Web export failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $exportPath)) { throw "Web export did not create index.html" }
$wasm = @(Get-ChildItem -LiteralPath $outputDir -Recurse -File -Filter "*.wasm")
$pck = @(Get-ChildItem -LiteralPath $outputDir -Recurse -File -Filter "*.pck")
if ($wasm.Count -eq 0) { throw "Web export did not create a .wasm payload" }
if ($pck.Count -eq 0) { throw "Web export did not create a .pck payload" }
$indexText = Get-Content -LiteralPath $exportPath -Raw
if ($indexText -match '(?:src|href)="/') { throw "Web export contains a root-absolute asset reference; project-site paths must remain relative" }
New-Item -ItemType File -Force -Path (Join-Path $outputDir ".nojekyll") | Out-Null
Write-Host ("WEB_EXPORT_SMOKE_OK: {0}; wasm={1}; pck={2}" -f $exportPath, $wasm.Count, $pck.Count) -ForegroundColor Green
exit 0
