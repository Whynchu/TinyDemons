param(
    [string]$ProjectRoot = "",
    [string]$GodotBin = ""
)

## Definition validator (Slice F, T2). Runs the Godot definition validator
## against every authored definition resource. Fails nonzero when any definition
## is malformed, so it joins the CI preflight alongside
## validate_composition.ps1 and validate_test_manifest.ps1.

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
$userDataDir = Join-Path $tempRoot ("tiny-demons-validate-defs-{0}" -f $PID)
$logFile = Join-Path $userDataDir "validate_definitions.log"
New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null

& $GodotBin --headless --audio-driver Dummy --user-data-dir $userDataDir --path $ProjectRoot --log-file $logFile -s "res://tools/validate_definitions.gd"
$exitCode = $LASTEXITCODE
if (Test-Path $logFile) {
    Get-Content $logFile | Select-String "DEFINITION_VALIDATOR|FAILED:" | ForEach-Object { Write-Host $_.Line.Trim() }
}
if ($exitCode -ne 0) {
    Write-Host "DEFINITION_VALIDATOR_FAILED exit=$exitCode"
    exit 1
}
Write-Host "DEFINITION_VALIDATOR_OK"
exit 0
