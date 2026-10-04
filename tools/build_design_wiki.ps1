param(
	[string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceDirectory = Join-Path $projectRoot "wiki-site"
$contentDirectory = Join-Path $projectRoot "docs/wiki"
$outputPath = if ($OutputDirectory) {
	if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $projectRoot $OutputDirectory }
} else {
	Join-Path $projectRoot "dist/wiki"
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
Copy-Item -Path (Join-Path $sourceDirectory "*") -Destination $outputPath -Recurse -Force
$publishedContent = Join-Path $outputPath "content"
New-Item -ItemType Directory -Force -Path $publishedContent | Out-Null
Get-ChildItem -LiteralPath $contentDirectory -Filter "*.md" -File |
	Copy-Item -Destination $publishedContent -Force

Write-Host "Design wiki built to $outputPath"
