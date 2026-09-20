param(
    [string]$ProjectRoot = "",
    [string]$GodotBin = ""
)

## Catalog report (Slice F, T2). Runs the definition catalog report so a
## designer can see "what content exists" without reading coordinators. Prints
## surface counts and stable IDs; exits nonzero on any load failure.

$ErrorActionPreference = "Stop"
$ProjectRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { Split-Path -Parent $PSScriptRoot } else { $ProjectRoot }
$GodotBin = if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) { $env:GODOT_BIN } else { "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" }
} else { $GodotBin }
if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
    throw "Godot executable not found: $GodotBin. Set GODOT_BIN or pass -GodotBin."
}
$tempRoot = $env:RUNNER_TEMP
if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = $env:TEMP }
if ([string]::IsNullOrWhiteSpace($tempRoot)) { $tempRoot = [System.IO.Path]::GetTempPath() }
$userDataDir = Join-Path $tempRoot ("tiny-demons-report-catalogs-{0}" -f $PID)
$logFile = Join-Path $userDataDir "report_catalogs.log"
New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null

& $GodotBin --headless --audio-driver Dummy --user-data-dir $userDataDir --path $ProjectRoot --log-file $logFile -s "res://tools/report_catalogs.gd"
$exitCode = $LASTEXITCODE
if (Test-Path $logFile) {
    Get-Content $logFile | Select-String "===|item_catalog|slime_variant_catalog|encounter_definition|room_definition|dungeon_generation_policy|dungeon_layout_run|puzzle_map|LOAD_FAILED|ERROR" | ForEach-Object { Write-Host $_.Line.Trim() }
}
exit $exitCode
