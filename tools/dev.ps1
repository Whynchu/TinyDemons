[CmdletBinding()]
param(
	[Parameter(Position = 0)]
	[ValidateSet("verify", "test", "preview", "new", "report", "doctor", "help")]
	[string]$Command = "help",
	[Parameter(Position = 1)]
	[string]$Kind = "",
	[Parameter(Position = 2)]
	[string]$Id = "",
	[ValidateSet("fast", "content", "gate", "all")]
	[string]$Suite = "content",
	[string]$ProjectRoot = "",
	[string]$GodotBin = "",
	[switch]$Editor,
	[switch]$Force
)

$ErrorActionPreference = "Stop"
$resolvedRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { Split-Path -Parent $PSScriptRoot } else { [IO.Path]::GetFullPath($ProjectRoot) }
if (-not (Test-Path -LiteralPath (Join-Path $resolvedRoot "project.godot") -PathType Leaf)) {
	throw "Tiny Demons project.godot not found under $resolvedRoot"
}

$resolvedGodot = if ([string]::IsNullOrWhiteSpace($GodotBin)) {
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) { $env:GODOT_BIN } else { "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" }
} else { $GodotBin }

function Assert-GodotAvailable {
	if (-not (Test-Path -LiteralPath $resolvedGodot -PathType Leaf)) {
		throw "Godot executable not found: $resolvedGodot. Set GODOT_BIN or pass -GodotBin."
	}
}

function Invoke-RepoPowerShell {
	param(
		[string]$ScriptPath,
		[object[]]$Arguments = @()
	)
	$powerShellExecutable = (Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
	if ([string]::IsNullOrWhiteSpace($powerShellExecutable)) {
		$powerShellExecutable = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1).Source
	}
	if ([string]::IsNullOrWhiteSpace($powerShellExecutable)) {
		throw "No PowerShell executable found"
	}
	& $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$([IO.Path]::GetFileName($ScriptPath)) failed with exit code $LASTEXITCODE"
	}
}

function Invoke-HeadlessScript {
	param(
		[string]$Script,
		[string[]]$UserArgs = @()
	)
	$headlessPath = Join-Path $resolvedRoot "tools/run_headless.ps1"
	$arguments = @(
		"-ProjectRoot", $resolvedRoot,
		"-GodotBin", $resolvedGodot,
		"-Script", $Script
	)
	if ($UserArgs.Count -gt 0) {
		$arguments += "-UserArgs"
		$arguments += $UserArgs
	}
	Invoke-RepoPowerShell $headlessPath $arguments
}

function Invoke-Verification {
	Assert-GodotAvailable
	Invoke-RepoPowerShell (Join-Path $resolvedRoot "tools/validate_test_manifest.ps1")
	Invoke-RepoPowerShell (Join-Path $resolvedRoot "tools/validate_composition.ps1") @("-SelfTest")
	Invoke-RepoPowerShell (Join-Path $resolvedRoot "tools/validate_composition.ps1")
	Invoke-RepoPowerShell (Join-Path $resolvedRoot "tools/validate_definitions.ps1") @("-ProjectRoot", $resolvedRoot, "-GodotBin", $resolvedGodot)
	Invoke-RepoPowerShell (Join-Path $resolvedRoot "tools/validate_godot_uids.ps1")
	Invoke-RepoPowerShell (Join-Path $resolvedRoot "tools/report_catalogs.ps1") @("-ProjectRoot", $resolvedRoot, "-GodotBin", $resolvedGodot)
	Write-Host "DEV_VERIFY_OK" -ForegroundColor Green
}

function Invoke-ContentTests {
	Assert-GodotAvailable
	$tests = switch ($Suite) {
		"fast" { @("enemy_definition_slice_smoke", "enemy_definition_roundtrip_smoke", "encounter_definition_smoke") }
		"content" { @("enemy_definition_slice_smoke", "enemy_definition_roundtrip_smoke", "encounter_definition_smoke", "slime_variant_smoke", "boss_variant_selection_smoke", "enemy_room_entrance_scene_smoke") }
		default { @() }
	}
	if ($Suite -in @("gate", "all")) {
		$hadGodotBin = -not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)
		$previousGodotBin = $env:GODOT_BIN
		try {
			$env:GODOT_BIN = $resolvedGodot
			$group = if ($Suite -eq "gate") { "gate" } else { "all" }
			Invoke-RepoPowerShell (Join-Path $resolvedRoot "tests/run_all_smoke.ps1") @("-TestGroup", $group)
		} finally {
			if ($hadGodotBin) { $env:GODOT_BIN = $previousGodotBin }
			else { Remove-Item Env:GODOT_BIN -ErrorAction SilentlyContinue }
		}
		return
	}
	foreach ($test in $tests) {
		Invoke-HeadlessScript ("res://tests/{0}.gd" -f $test)
	}
	Write-Host ("DEV_TEST_OK suite={0} tests={1}" -f $Suite, $tests.Count) -ForegroundColor Green
}

function New-EnemyDefinition {
	if ($Kind -ne "enemy") { throw "new currently supports only: new enemy <id>" }
	if ([string]::IsNullOrWhiteSpace($Id) -or $Id -notmatch "^[a-z][a-z0-9_]*$") {
		throw "Enemy id must match ^[a-z][a-z0-9_]*$"
	}
	$definitionsRoot = Join-Path $resolvedRoot "resources/definitions"
	$definitionPath = Join-Path $definitionsRoot ("{0}.tres" -f $Id)
	if ((Test-Path -LiteralPath $definitionPath -PathType Leaf) -and -not $Force) {
		throw "Definition already exists: $definitionPath. Use -Force only to replace it."
	}
	$pattern = '^[\s]*id[\s]*=[\s]*&"' + [regex]::Escape($Id) + '"'
	$existingMatches = @(Get-ChildItem -LiteralPath $definitionsRoot -Filter "*.tres" -File | Select-String -Pattern $pattern -List)
	if ($existingMatches.Count -gt 0 -and -not $Force) {
		throw "An authored definition already uses id '$Id': $($existingMatches[0].Path)"
	}
	$displayName = (($Id -split "_") | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join " "
	$template = @"
[gd_resource type="Resource" script_class="EnemyDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/enemy_definition.gd" id="1_enemy"]

[resource]
script = ExtResource("1_enemy")
id = &"$Id"
display_name = "$displayName"
element = 0
damage_contract = &"physical"
base_stats = {"AGI": 2, "DEF": 2, "INT": 0, "MND": 1, "STR": 2, "VIT": 2}
growth_weights = {"AGI": 0.2, "DEF": 0.24, "INT": 0.0, "MND": 0.08, "STR": 0.24, "VIT": 0.24}
visual_source = "green"
encounter_role = &"late"
encounter_weight = 0.5
encounter_min_rank = 3
"@
	$utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
	[System.IO.File]::WriteAllText($definitionPath, $template, $utf8NoBom)
	Write-Host "NEW_ENEMY_DEFINITION $definitionPath" -ForegroundColor Green
	Write-Host "Next: edit the resource, then run 'pwsh -File tools/dev.ps1 preview enemy $Id' and 'pwsh -File tools/dev.ps1 verify'."
}

function Show-Help {
	@"
Tiny Demons authoring commands

  verify                         Run manifest, composition, definitions, UID, and catalog checks.
  test -Suite fast|content       Run focused definition/content checks.
  test -Suite gate|all           Run the curated gate or full manifest inventory.
  preview enemy <id>             Validate and report a workbench preview without booting a run.
  preview enemy <id> -Editor     Open the preview workbench in the Godot editor.
  new enemy <id>                 Create one standalone EnemyDefinition resource.
  report                         Print the authored catalog report.
  doctor                         Check the project and configured Godot executable.

Use -ProjectRoot and -GodotBin when working from another checkout. GODOT_BIN is
honored automatically.
"@ | Write-Host
}

switch ($Command) {
	"help" { Show-Help }
	"verify" { Invoke-Verification }
	"test" { Invoke-ContentTests }
	"preview" {
		if ($Kind -ne "enemy" -or [string]::IsNullOrWhiteSpace($Id)) { throw "Usage: dev.ps1 preview enemy <id>" }
		Assert-GodotAvailable
		if ($Editor) {
			& $resolvedGodot "--editor" "--path" $resolvedRoot "res://scenes/enemy_preview_workbench.tscn" "--" ("--enemy-id={0}" -f $Id)
			exit $LASTEXITCODE
		}
		Invoke-HeadlessScript "res://tools/preview_enemy.gd" @(("--enemy-id={0}" -f $Id))
	}
	"new" { New-EnemyDefinition }
	"report" {
		Assert-GodotAvailable
		Invoke-RepoPowerShell (Join-Path $resolvedRoot "tools/report_catalogs.ps1") @("-ProjectRoot", $resolvedRoot, "-GodotBin", $resolvedGodot)
	}
	"doctor" {
		Assert-GodotAvailable
		Write-Host ("DEV_DOCTOR_OK root={0} godot={1}" -f $resolvedRoot, $resolvedGodot) -ForegroundColor Green
	}
}
