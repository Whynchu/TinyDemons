[CmdletBinding()]
param(
	[string]$InputRoot = "",
	[switch]$Force,
	[switch]$DeleteWavSources
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = if ($InputRoot) { (Resolve-Path -LiteralPath $InputRoot).Path } else { Join-Path $projectRoot "assets\sounds" }
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -eq $ffmpeg) {
	throw "ffmpeg is required. Install it, then rerun convert_audio_to_ogg.ps1."
}

$wavFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter "*.wav")
if ($wavFiles.Count -eq 0) {
	Write-Host "No WAV files found under $sourceRoot" -ForegroundColor Yellow
	exit 0
}

$converted = 0
$skipped = 0
$sourceBytes = 0L
$outputBytes = 0L
foreach ($wav in $wavFiles) {
	$ogg = [System.IO.Path]::ChangeExtension($wav.FullName, ".ogg")
	if ((Test-Path -LiteralPath $ogg) -and -not $Force) {
		$skipped++
		if ($DeleteWavSources) {
			Remove-Item -LiteralPath $wav.FullName -Force
		}
		continue
	}
	$arguments = @("-hide_banner", "-loglevel", "error", "-nostdin", "-y")
	$arguments += @("-i", $wav.FullName, "-c:a", "libvorbis", "-q:a", "5", $ogg)
	& $ffmpeg.Source @arguments
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $ogg)) {
		throw "ffmpeg failed while converting $($wav.FullName)"
	}
	$converted++
	$sourceBytes += $wav.Length
	$outputBytes += (Get-Item -LiteralPath $ogg).Length
	if ($DeleteWavSources) {
		Remove-Item -LiteralPath $wav.FullName -Force
	}
}

Write-Host ("Audio conversion complete: converted={0}, skipped={1}, source_bytes={2}, ogg_bytes={3}" -f $converted, $skipped, $sourceBytes, $outputBytes) -ForegroundColor Green
if ($DeleteWavSources) {
	Write-Host "WAV sources were removed from the working tree after successful conversion." -ForegroundColor Yellow
}
