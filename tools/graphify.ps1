# Invoke the local Godot fork against the Tiny Demons graph from any directory.
# Examples: ./tools/graphify.ps1 query "ActorGeometry" --budget 1500
#           ./tools/graphify.ps1 update .
param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$GraphifyArguments = @("--help")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$forkRoot = Join-Path $projectRoot "graphify-godot"
$pythonPath = Join-Path $forkRoot ".venv/Scripts/python.exe"
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
	$pythonPath = Join-Path $forkRoot ".venv/bin/python"
}
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
	throw "Graphify's local Python environment is missing. Set up graphify-godot/.venv with the fork's [godot] extra; see docs/graphify-godot-integration-plan.md."
}

$previousOutput = $env:GRAPHIFY_OUT
$previousPythonPath = $env:PYTHONPATH
$commandExitCode = 1
Push-Location -LiteralPath $projectRoot
try {
	$env:GRAPHIFY_OUT = Join-Path $forkRoot ".tools/tiny-demons-map"
	$env:PYTHONPATH = if ([string]::IsNullOrEmpty($previousPythonPath)) {
		$forkRoot
	} else {
		$forkRoot + [IO.Path]::PathSeparator + $previousPythonPath
	}
	& $pythonPath -m graphify @GraphifyArguments
	$commandExitCode = $LASTEXITCODE
} finally {
	$env:GRAPHIFY_OUT = $previousOutput
	$env:PYTHONPATH = $previousPythonPath
	Pop-Location
}
exit $commandExitCode
