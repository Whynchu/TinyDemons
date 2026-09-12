[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$sidecars = Get-ChildItem -LiteralPath (Join-Path $root "scripts"), (Join-Path $root "tests") -Filter *.gd.uid -Recurse
$records = foreach ($file in $sidecars) {
	$uid = (Get-Content -LiteralPath $file.FullName -Raw).Trim()
	if ($uid -notmatch '^uid://[a-z0-9]+$') { throw "Invalid Godot UID in $($file.FullName): $uid" }
	[pscustomobject]@{ Uid = $uid; Path = $file.FullName }
}
$duplicates = $records | Group-Object Uid | Where-Object Count -gt 1
if ($duplicates) {
	foreach ($duplicate in $duplicates) {
		$paths = ($duplicate.Group | ForEach-Object Path) -join ", "
		Write-Error "Duplicate script UID $($duplicate.Name): $paths"
	}
	exit 1
}

$scene_files = Get-ChildItem -LiteralPath (Join-Path $root "scenes"), (Join-Path $root "scripts"), (Join-Path $root "tests") -Include *.tscn,*.gd -Recurse
$script_uids = @{}
foreach ($record in $records) { $script_uids[$record.Uid] = $record.Path }
foreach ($file in $scene_files) {
	foreach ($match in [regex]::Matches((Get-Content -LiteralPath $file.FullName -Raw), 'uid="(uid://[a-z0-9]+)" path="res://scripts/([^"]+\.gd)"')) {
		$uid = $match.Groups[1].Value
		$expected = Join-Path $root ("scripts/{0}" -f $match.Groups[2].Value)
		if (-not $script_uids.ContainsKey($uid)) { throw "Scene references script UID without sidecar: $uid in $($file.FullName)" }
		if ([IO.Path]::GetFullPath($script_uids[$uid]) -ne [IO.Path]::GetFullPath($expected + '.uid')) { throw "Script UID path mismatch for $uid in $($file.FullName)" }
	}
}
Write-Host ("GODOT_UID_VALIDATION_OK: {0} script sidecars; no duplicate or mismatched scene script IDs" -f $records.Count) -ForegroundColor Green
