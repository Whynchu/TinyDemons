[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$GodotBin = "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
    [string]$Script = "",
    [switch]$Editor,
    [int]$QuitAfter = 0,
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"
$userDataDir = Join-Path $env:TEMP ("tiny-demons-headless-{0}" -f $PID)
$logFile = Join-Path $userDataDir "headless.log"
New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null

$arguments = @(
    "--headless",
    "--audio-driver", "Dummy",
    "--user-data-dir", $userDataDir,
    "--path", $ProjectRoot,
    "--log-file", $logFile
)
if ($Editor) {
    $arguments += @("--editor", "--quit")
}
if ($QuitAfter -gt 0) {
    $arguments += @("--quit-after", [string]$QuitAfter)
}
if (-not [string]::IsNullOrWhiteSpace($Script)) {
    $arguments += @("-s", $Script)
}
$arguments += $ExtraArgs

& $GodotBin @arguments
$exitCode = $LASTEXITCODE
Write-Host "Headless Godot exit $exitCode; log: $logFile"
exit $exitCode
