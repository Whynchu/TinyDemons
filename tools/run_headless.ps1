[CmdletBinding()]
param(
	[string]$ProjectRoot = "",
	[string]$GodotBin = "",
    [string]$Script = "",
    [switch]$Editor,
    [int]$QuitAfter = 0,
    [string[]]$ExtraArgs = @(),
    [string[]]$UserArgs = @()
)

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
$userDataDir = Join-Path $tempRoot ("tiny-demons-headless-{0}" -f $PID)
$logFile = Join-Path $userDataDir "headless.log"
New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null

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
if ($UserArgs.Count -gt 0) {
	$arguments += "--"
	$arguments += $UserArgs
}

& $GodotBin @arguments
$exitCode = $LASTEXITCODE
Write-Host "Headless Godot exit $exitCode; log: $logFile"
exit $exitCode
