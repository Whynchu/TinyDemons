# Query the installed Godot fork from this worktree. A linked worktree can
# reuse the primary checkout's ignored fork without copying its environment.
param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$GraphifyArguments = @("--help")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$forkRoot = Join-Path $projectRoot "graphify-godot"
if (-not (Test-Path -LiteralPath $forkRoot -PathType Container)) {
	$gitExecutable = Get-Command git -ErrorAction SilentlyContinue
	if ($null -ne $gitExecutable) {
		$commonGitDirectory = & $gitExecutable.Source -c ("safe.directory={0}" -f $projectRoot) -C $projectRoot rev-parse --path-format=absolute --git-common-dir
		if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commonGitDirectory)) {
			$primaryRoot = Split-Path -Parent ([IO.Path]::GetFullPath($commonGitDirectory.Trim()))
			$forkRoot = Join-Path $primaryRoot "graphify-godot"
		}
	}
}

$pythonPath = Join-Path $forkRoot ".venv/Scripts/python.exe"
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
	$pythonPath = Join-Path $forkRoot ".venv/bin/python"
}
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
	throw "Graphify's local Godot fork/environment is unavailable. Use ownership docs and current source; no automatic installation is performed."
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
