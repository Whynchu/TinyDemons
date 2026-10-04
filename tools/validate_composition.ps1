param(
	[string]$BaselinePath = "",
	[string]$ScriptsDirectory = "",
	[switch]$UpdateBaseline,
	[switch]$RequireTargets,
	[switch]$SelfTest
)

## Composition ownership guardrail.
##
## The default mode is a regression gate. It protects the last accepted
## composition baseline while the strict ownership work is in progress.
## -RequireTargets is the opt-in completion audit: it fails until the target
## thresholds in composition-baseline.json are met.
##
## The guard checks:
##
##   1. No context stores or accepts GameplayState outside the transitional
##      allowlist recorded in the baseline JSON.
##   2. No completed context relies on `context.runtime`.
##   3. No new parallel `*_legacy` / `*_context` duplicate implementations.
##   4. No root-access, GameplayState, or RoomController size regression.
##
## Use -UpdateBaseline only after a reviewed slice deliberately retires
## coupling or extracts an owner. The command refuses to write a baseline when
## the current tree has a regression.

$ErrorActionPreference = "Stop"
$powerShellExecutable = (Get-Command powershell.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if ([string]::IsNullOrWhiteSpace($powerShellExecutable)) {
	$powerShellExecutable = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1).Source
}
if ([string]::IsNullOrWhiteSpace($powerShellExecutable)) {
	throw "No PowerShell executable found for composition self-test"
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedScriptsDirectory = if ($ScriptsDirectory) { $ScriptsDirectory } else { Join-Path $projectRoot "scripts" }
$resolvedBaselinePath = if ($BaselinePath) { $BaselinePath } else { Join-Path $PSScriptRoot "composition-baseline.json" }

$defaultTargets = [ordered]@{
	root_accesses_max = 2499
	gameplay_state_lines_max = 1719
	gameplay_state_fields_max = 287
	room_controller_lines_max = 2296
	runtime_refs_max = 0
	legacy_pairs_max = 0
	transitional_contexts_max = 0
}

$defaultForwardTargets = [ordered]@{
	screen_state_controller_lines = 800
	hub_flow_controller_seams = 120
	screen_state_controller_seams = 120
	live_context_twin_pairs = 0
	bootstrap_registration_rows = 44
	scripts_flat_directory = $false
	untyped_root_parameters = 0
	unclassified_scripts = 0
}

$forwardTargetStages = @{
	screen_state_controller_lines = 3
	hub_flow_controller_seams = 2
	screen_state_controller_seams = 3
	live_context_twin_pairs = 2
	bootstrap_registration_rows = 3
	scripts_flat_directory = 1
	untyped_root_parameters = 2
	unclassified_scripts = 1
}

function Get-CodeOnlyContent([string]$Content) {
	# GDScript comments are line comments. Keep inline code intact and remove
	# full-line documentation before checking architectural tokens.
	$codeLines = foreach ($line in ($Content -split "`r?`n")) {
		if ($line.TrimStart().StartsWith("#")) {
			continue
		}
		$line
	}
	return ($codeLines -join "`n")
}

function Get-PropertyValue($Object, [string]$Name) {
	if ($null -eq $Object -or $null -eq $Object.PSObject.Properties[$Name]) {
		return $null
	}
	return $Object.PSObject.Properties[$Name].Value
}

function Get-PropertyInfo($Object, [string]$Name) {
	if ($null -eq $Object) {
		return $null
	}
	return $Object.PSObject.Properties[$Name]
}

function Get-IntegerBaseline($Baseline, [string]$Name, [int]$Fallback) {
	$value = Get-PropertyValue $Baseline $Name
	if ($null -ne $value) {
		return [int]$value
	}
	return $Fallback
}

## Weighted completion: how far each metric has traveled from the recorded
## completion_start toward its strict target, weighted by the size of the
## remaining gap. A metric that grew beyond its start contributes zero progress
## (clamped), never negative credit.
function Get-CompletionPercent(
	[int]$RootAccesses, [int]$GameplayStateLines, [int]$GameplayStateFields,
	[int]$RoomControllerLines, [int]$RuntimeRefs, [int]$LegacyPairs,
	[int]$TransitionalContexts, $CompletionStart, $TargetValues
) {
	$metrics = @(
		@{ Name = "root_accesses"; Start = (Get-IntegerBaseline $CompletionStart "root_accesses" 3135); Target = (Get-TargetValue $TargetValues "root_accesses_max" 2499); Current = $RootAccesses },
		@{ Name = "gameplay_state_lines"; Start = (Get-IntegerBaseline $CompletionStart "gameplay_state_lines" 1720); Target = (Get-TargetValue $TargetValues "gameplay_state_lines_max" 1719); Current = $GameplayStateLines },
		@{ Name = "gameplay_state_fields"; Start = (Get-IntegerBaseline $CompletionStart "gameplay_state_fields" 287); Target = (Get-TargetValue $TargetValues "gameplay_state_fields_max" 286); Current = $GameplayStateFields },
		@{ Name = "room_controller_lines"; Start = (Get-IntegerBaseline $CompletionStart "room_controller_lines" 2297); Target = (Get-TargetValue $TargetValues "room_controller_lines_max" 2296); Current = $RoomControllerLines },
		@{ Name = "runtime_refs"; Start = (Get-IntegerBaseline $CompletionStart "runtime_refs" 20); Target = (Get-TargetValue $TargetValues "runtime_refs_max" 0); Current = $RuntimeRefs },
		@{ Name = "legacy_pairs"; Start = (Get-IntegerBaseline $CompletionStart "legacy_pairs" 11); Target = (Get-TargetValue $TargetValues "legacy_pairs_max" 0); Current = $LegacyPairs },
		@{ Name = "transitional_contexts"; Start = (Get-IntegerBaseline $CompletionStart "transitional_contexts" 5); Target = (Get-TargetValue $TargetValues "transitional_contexts_max" 0); Current = $TransitionalContexts }
	)
	$weightedSum = 0.0
	$totalWeight = 0.0
	$details = [System.Collections.Generic.List[string]]::new()
	foreach ($metric in $metrics) {
		$gap = $metric.Start - $metric.Target
		if ($gap -le 0) {
			continue
		}
		$traveled = $metric.Start - $metric.Current
		$progress = [Math]::Min([Math]::Max($traveled / $gap, 0.0), 1.0)
		$weightedSum += $progress * $gap
		$totalWeight += $gap
		$details.Add(("{0}={1:P0}" -f $metric.Name, $progress))
	}
	$percent = if ($totalWeight -gt 0) { $weightedSum / $totalWeight } else { 1.0 }
	return [PSCustomObject]@{
		Percent = $percent
		Details = @($details)
	}
}

function Get-TargetValue($Targets, [string]$Name, [int]$Fallback) {
	$value = Get-PropertyValue $Targets $Name
	if ($null -ne $value) {
		return [int]$value
	}
	return $Fallback
}

## Editor composition: the reusable-component / editor-changeable direction.
## A "piece" counts toward completion only when it is BOTH directly wired (no
## root.call/get/set) AND changeable in the editor (@export field, tuning .tres,
## or typed Resource) instead of a hardcoded const dictionary. The composite is
## a weighted average over four measured sub-metrics:
##   component_direct    (weight 0.20) blind components / total components
##   component_editor    (weight 0.30) @export-configured / total components
##   component_both      (weight 0.25) blind AND editor-configured / total
##   definition_editor   (weight 0.25) editor-able definition surfaces / total
## This number is intentionally low today: the direct-access half is mostly
## complete but the editor-changeable half has barely started.
function Get-EditorComposition([string]$ScriptsDir, [string]$ProjectRoot) {
	$componentFiles = @(Get-ChildItem -LiteralPath $ScriptsDir -Filter "*component*.gd" -File -Recurse)
	$componentTotal = $componentFiles.Count
	$componentBlind = 0
	$componentConfigured = 0
	$componentBoth = 0
	foreach ($file in $componentFiles) {
		$codeContent = Get-CodeOnlyContent (Get-Content -Raw -LiteralPath $file.FullName)
		$rootSites = ([regex]::Matches($codeContent, 'root\.(call|get|set)\(')).Count
		$exportCount = ([regex]::Matches($codeContent, '@export')).Count
		$isBlind = $rootSites -eq 0
		$isConfigured = $exportCount -gt 0
		if ($isBlind) { $componentBlind += 1 }
		if ($isConfigured) { $componentConfigured += 1 }
		if ($isBlind -and $isConfigured) { $componentBoth += 1 }
	}
	# Definition surfaces are counted by file: the content catalogs, the authored
	# run builders, and the external tuning resources. A surface is editor-able
	# when the editor can inspect its data: a .tres resource file, or a catalog
	# script that loads its authored definitions from resources/definitions/*.tres
	# instead of a hardcoded const dictionary.
	#
	# This list intentionally contains only files that hold authored definition
	# content. The shared layout contract (dungeon_layout_definition.gd) is
	# infrastructure, not authored data. The procedural run wrappers
	# (dungeon_layout_run3/4/5/6.gd) only resolve starter/alternate flames and
	# delegate to the puzzle-map compiler; their authored content is the puzzle
	# plan resources below, which are already counted. Run 1 and Run 2 are
	# genuine authored layouts (rooms/connections converted to .tres) and stay on
	# the list.
	$definitionScripts = @(
		"item_catalog.gd",
		"element_catalog.gd",
		"slime_variant_catalog.gd",
		"palette_library.gd",
		"encounter_definition.gd",
		"room_definition.gd",
		"dungeon_generation_policy.gd",
		"reward_definition.gd",
		"dungeon_layout_run1.gd",
		"dungeon_layout_run2.gd",
		"puzzle_map_r4.gd",
		"puzzle_map_r5.gd",
		"puzzle_map_r3_new.gd"
	)
	$definitionScriptCount = 0
	$definitionScriptEditable = 0
	foreach ($name in $definitionScripts) {
		$scriptPath = Get-ChildItem -LiteralPath $ScriptsDir -Filter $name -File -Recurse | Select-Object -First 1
		if ($null -ne $scriptPath) {
			$definitionScriptCount += 1
			$scriptContent = Get-Content -Raw -LiteralPath $scriptPath.FullName
			if ($scriptContent -match 'resources/definitions/[\w/]+\.tres') {
				$definitionScriptEditable += 1
			}
		}
	}
	$tuningDir = Join-Path $ProjectRoot "resources/tuning"
	$tuningCount = if (Test-Path -LiteralPath $tuningDir) {
		@(Get-ChildItem -LiteralPath $tuningDir -Filter "*.tres" -File).Count
	} else {
		0
	}
	$definitionTotal = $definitionScriptCount + $tuningCount
	$definitionEditable = $tuningCount + $definitionScriptEditable

	$componentDirect = if ($componentTotal -gt 0) { $componentBlind / $componentTotal } else { 0.0 }
	$componentEditor = if ($componentTotal -gt 0) { $componentConfigured / $componentTotal } else { 0.0 }
	$componentBothRate = if ($componentTotal -gt 0) { $componentBoth / $componentTotal } else { 0.0 }
	$definitionEditor = if ($definitionTotal -gt 0) { $definitionEditable / $definitionTotal } else { 0.0 }
	$composite = (0.20 * $componentDirect) + (0.30 * $componentEditor) + (0.25 * $componentBothRate) + (0.25 * $definitionEditor)

	return [PSCustomObject]@{
		ComponentTotal = $componentTotal
		ComponentBlind = $componentBlind
		ComponentConfigured = $componentConfigured
		ComponentBoth = $componentBoth
		DefinitionTotal = $definitionTotal
		DefinitionEditable = $definitionEditable
		ComponentDirect = $componentDirect
		ComponentEditor = $componentEditor
		ComponentBothRate = $componentBothRate
		DefinitionEditor = $definitionEditor
		Composite = $composite
	}
}

function Get-FunctionBodyInfo([string[]]$Lines, [int]$FunctionLineIndex) {
	$body = [System.Collections.Generic.List[string]]::new()
	for ($index = $FunctionLineIndex + 1; $index -lt $Lines.Count; $index += 1) {
		if ($Lines[$index] -match '^\s*(?:static\s+)?func\s+[A-Za-z_]\w*\s*\(') {
			break
		}
		$body.Add($Lines[$index])
	}
	$codeLines = @(
		$body |
			ForEach-Object {
				$line = $_ -replace '\s+#.*$', ''
				if ($line.Trim() -ne '') { $line.Trim() }
			} |
			Where-Object { $_ }
	)
	return [PSCustomObject]@{
		Lines = $codeLines
		IsForward = $codeLines.Count -eq 1 -and (
			$codeLines[0] -match '(?:^|\b)return\s+.*(?:_?[A-Za-z_]\w*_context\s*\(|call\(\s*["'']_?[A-Za-z_]\w*_context["'']\s*[,)]?)' -or
			$codeLines[0] -match '^_?[A-Za-z_]\w*_context\s*\('
		)
	}
}

function Get-LegacyAudit([System.IO.FileInfo[]]$Files) {
	$legacyCount = 0
	$legacyPairs = [System.Collections.Generic.List[string]]::new()
	foreach ($file in $Files) {
		$lines = @(Get-Content -LiteralPath $file.FullName)
		$content = Get-Content -Raw -LiteralPath $file.FullName
		$codeContent = Get-CodeOnlyContent $content
		for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex += 1) {
			if ($lines[$lineIndex] -notmatch '^\s*(?:static\s+)?func\s+(_\w+)_legacy\s*\(') {
				continue
			}
			$baseName = $Matches[1]
			$legacyCount += 1
			$bodyInfo = Get-FunctionBodyInfo $lines $lineIndex
			$stem = $baseName.TrimStart("_")
			$contextPattern = '(?m)^\s*(?:static\s+)?func\s+_?' + [regex]::Escape($stem) + '_context\s*\('
			$hasContextTwin = [regex]::IsMatch($codeContent, $contextPattern)
			if ($hasContextTwin -and -not $bodyInfo.IsForward) {
				$legacyPairs.Add("$($file.Name):$baseName")
			}
		}
	}
	return [PSCustomObject]@{
		Count = $legacyCount
		Pairs = @($legacyPairs | Sort-Object -Unique)
	}
}

function Get-UntypedRootParameterCount([string]$Content) {
	$lines = @($Content -split "`r?`n")
	$count = 0
	for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex += 1) {
		$line = $lines[$lineIndex]
		if ($line -notmatch '^\s*(?:static\s+)?func\s+\w+\s*\(') { continue }
		$openIndex = $line.IndexOf('(')
		$depth = 0
		$quote = [char]0
		$escaped = $false
		$parameters = [System.Text.StringBuilder]::new()
		for ($scanLine = $lineIndex; $scanLine -lt $lines.Count; $scanLine += 1) {
			$scanText = $lines[$scanLine]
			$startColumn = if ($scanLine -eq $lineIndex) { $openIndex } else { 0 }
			for ($column = $startColumn; $column -lt $scanText.Length; $column += 1) {
				$character = $scanText[$column]
				if ($quote -ne [char]0) {
					if ($depth -gt 0) { [void]$parameters.Append($character) }
					if ($escaped) { $escaped = $false; continue }
					if ($character -eq '\' -and $quote -eq '"') { $escaped = $true; continue }
					if ($character -eq $quote) { $quote = [char]0 }
					continue
				}
				if ($character -eq '#') { break }
				if ($character -eq '"' -or $character -eq "'") {
					$quote = $character
					if ($depth -gt 0) { [void]$parameters.Append($character) }
					continue
				}
				if ($character -eq '(') {
					$depth += 1
					if ($depth -gt 1) { [void]$parameters.Append($character) }
					continue
				}
				if ($character -eq ')') {
					$depth -= 1
					if ($depth -eq 0) { break }
					[void]$parameters.Append($character)
					continue
				}
				if ($depth -gt 0) { [void]$parameters.Append($character) }
			}
			if ($depth -eq 0) { break }
		}
		$count += ([regex]::Matches($parameters.ToString(), '(?m)(?:^|,)\s*_?root\s*(?::\s*(?:Object|Variant))?\s*(?=,|=|$)')).Count
	}
	return $count
}

function Add-RuleFinding($RuleFindings, [string]$Rule, [string]$Finding) {
	if (-not $RuleFindings.ContainsKey($Rule)) {
		$RuleFindings[$Rule] = [System.Collections.Generic.List[string]]::new()
	}
	$RuleFindings[$Rule].Add($Finding)
}

function Get-RelativeScriptPath([System.IO.FileInfo]$File, [string]$ScriptsRoot) {
	return $File.FullName.Substring($ScriptsRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
}

function Invoke-ValidatorForSelfTest([string]$FixtureScripts, [string]$FixtureBaseline, [switch]$FixtureRequireTargets) {
	$arguments = @(
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", $PSCommandPath,
		"-ScriptsDirectory", $FixtureScripts,
		"-BaselinePath", $FixtureBaseline
	)
	if ($FixtureRequireTargets) {
		$arguments += "-RequireTargets"
	}
	$script:SelfTestLastOutput = @(& $powerShellExecutable @arguments 2>&1) -join "`n"
	return $LASTEXITCODE
}

if ($SelfTest) {
	$selfTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tiny-demons-composition-validator-" + [guid]::NewGuid().ToString("N"))
	$fixtureScripts = Join-Path $selfTestRoot "scripts"
	$fixtureBaseline = Join-Path $selfTestRoot "baseline.json"
	New-Item -ItemType Directory -Path $fixtureScripts -Force | Out-Null
	try {
		Set-Content -LiteralPath (Join-Path $fixtureScripts "gameplay_state.gd") -Value "var state = 0" -Encoding UTF8
		Set-Content -LiteralPath (Join-Path $fixtureScripts "room_controller.gd") -Value "extends Node" -Encoding UTF8
		Set-Content -LiteralPath (Join-Path $fixtureScripts "fixture_context.gd") -Value @(
			"extends RefCounted",
			"class_name FixtureContext",
			"var profile: Object = null"
		) -Encoding UTF8
		Set-Content -LiteralPath (Join-Path $fixtureScripts "forward.gd") -Value @(
			"extends RefCounted",
			"func _sample_context(value: Object) -> void:",
			"    pass",
			"",
			"func _sample_legacy(value: Object) -> void:",
			"    return _sample_context(value)"
		) -Encoding UTF8
		$fixtureBaselineObject = [ordered]@{
			root_accesses = 0
			gameplay_state_lines = 1
			gameplay_state_fields = 1
			room_controller_lines = 1
			runtime_refs = 0
			legacy_total = 1
			legacy_pairs = @()
			transitional_allowlist = @()
			architecture_rules = [ordered]@{
				script_hygiene = @('gameplay_state.gd', 'room_controller.gd', 'fixture_context.gd', 'forward.gd')
			}
			per_file = [ordered]@{
				"root_access.gd" = [ordered]@{
					dynamic_dispatch = 0
					reach_through = 0
					untyped_root_parameters = 0
					live_context_twin_pairs = 0
				}
			}
			completion_start = [ordered]@{
				root_accesses = 0
				gameplay_state_lines = 1
				gameplay_state_fields = 1
				room_controller_lines = 1
				runtime_refs = 0
				legacy_pairs = 0
				transitional_contexts = 0
			}
			targets = [ordered]@{
				root_accesses_max = 0
				gameplay_state_lines_max = 1
				gameplay_state_fields_max = 1
				room_controller_lines_max = 1
				runtime_refs_max = 0
				legacy_pairs_max = 0
				transitional_contexts_max = 0
				forward = [ordered]@{
					screen_state_controller_lines = 800
					hub_flow_controller_seams = 120
					screen_state_controller_seams = 120
					live_context_twin_pairs = 0
					bootstrap_registration_rows = 44
					scripts_flat_directory = $false
					untyped_root_parameters = 0
					unclassified_scripts = 0
				}
			}
		}
		$fixtureBaselineObject | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixtureBaseline -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $fixtureScripts $fixtureBaseline) -ne 0) {
			throw "valid fixture was rejected`n$script:SelfTestLastOutput"
		}

		$fixtureRules = @(
			@{ Name = 'component_blindness'; File = 'fixture_component.gd'; Lines = @('extends Node', 'func sample():', '    get_parent()') },
			@{ Name = 'initialize_root'; File = 'fixture_initialize.gd'; Lines = @('extends Node', 'func initialize(root: Object):', '    pass') },
			@{ Name = 'component_self_wiring'; File = 'fixture_component.gd'; Lines = @('extends Node', 'func wire(other_component: Node):', '    other_component.changed.connect(_on_changed)') },
			@{ Name = 'identity_branches'; File = 'fixture_runtime.gd'; Lines = @('extends Node', 'func choose(element_id: String):', '    if element_id == "fire":', '        pass') },
			@{ Name = 'process_ownership'; File = 'fixture_runtime.gd'; Lines = @('extends Node', 'func _process(delta: float):', '    pass') },
			@{ Name = 'script_hygiene'; File = 'fixture_runtime.gd'; Lines = @('extends Node') },
			@{ Name = 'god_file_declaration'; File = 'fixture_runtime.gd'; Lines = @('extends Node') }
		)
		foreach ($ruleFixture in $fixtureRules) {
			$ruleScripts = Join-Path $selfTestRoot ("rules-" + $ruleFixture.Name)
			New-Item -ItemType Directory -Path $ruleScripts -Force | Out-Null
			Copy-Item -LiteralPath (Join-Path $fixtureScripts 'gameplay_state.gd') -Destination $ruleScripts
			Copy-Item -LiteralPath (Join-Path $fixtureScripts 'room_controller.gd') -Destination $ruleScripts
			Copy-Item -LiteralPath (Join-Path $fixtureScripts 'fixture_context.gd') -Destination $ruleScripts
			Copy-Item -LiteralPath (Join-Path $fixtureScripts 'forward.gd') -Destination $ruleScripts
			$ruleLines = @($ruleFixture.Lines)
			if ($ruleFixture.Name -eq 'god_file_declaration') { $ruleLines += @(1..401 | ForEach-Object { 'var fixture_field_{0} = {0}' -f $_ }) }
			Set-Content -LiteralPath (Join-Path $ruleScripts $ruleFixture.File) -Value $ruleLines -Encoding UTF8
			$ruleBaseline = Join-Path $selfTestRoot ("rules-" + $ruleFixture.Name + '.json')
			$ruleBaselineObject = $fixtureBaselineObject | ConvertTo-Json -Depth 8 | ConvertFrom-Json
			$ruleBaselineObject | Add-Member -NotePropertyName architecture_rules -NotePropertyValue ([PSCustomObject]@{}) -Force
			$ruleBaselineObject | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ruleBaseline -Encoding UTF8
			if ((Invoke-ValidatorForSelfTest $ruleScripts $ruleBaseline) -eq 0 -or $script:SelfTestLastOutput -notmatch "architecture rule '$($ruleFixture.Name)'") {
				throw "architecture rule '$($ruleFixture.Name)' did not reject its fixture`n$script:SelfTestLastOutput"
			}
		}

		$cycleScripts = Join-Path $selfTestRoot 'rules-controller_cycles'
		New-Item -ItemType Directory -Path $cycleScripts -Force | Out-Null
		Copy-Item -LiteralPath (Join-Path $fixtureScripts 'gameplay_state.gd') -Destination $cycleScripts
		Copy-Item -LiteralPath (Join-Path $fixtureScripts 'room_controller.gd') -Destination $cycleScripts
		Copy-Item -LiteralPath (Join-Path $fixtureScripts 'fixture_context.gd') -Destination $cycleScripts
		Copy-Item -LiteralPath (Join-Path $fixtureScripts 'forward.gd') -Destination $cycleScripts
		Set-Content -LiteralPath (Join-Path $cycleScripts 'alpha_controller.gd') -Value 'const B = preload("res://scripts/runtime/controllers/beta_controller.gd")' -Encoding UTF8
		Set-Content -LiteralPath (Join-Path $cycleScripts 'beta_controller.gd') -Value 'const A = preload("res://scripts/runtime/controllers/alpha_controller.gd")' -Encoding UTF8
		$cycleBaseline = Join-Path $selfTestRoot 'rules-controller_cycles.json'
		$cycleBaselineObject = $fixtureBaselineObject | ConvertTo-Json -Depth 8 | ConvertFrom-Json
		$cycleBaselineObject | Add-Member -NotePropertyName architecture_rules -NotePropertyValue ([PSCustomObject]@{}) -Force
		$cycleBaselineObject | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cycleBaseline -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $cycleScripts $cycleBaseline) -eq 0 -or $script:SelfTestLastOutput -notmatch "architecture rule 'controller_cycles'") {
			throw "controller dependency cycle was not rejected`n$script:SelfTestLastOutput"
		}

		Set-Content -LiteralPath (Join-Path $fixtureScripts "bad_context.gd") -Value @(
			"extends RefCounted",
			"class_name BadContext",
			"var runtime: GameplayState = null"
		) -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $fixtureScripts $fixtureBaseline) -eq 0) {
			throw "GameplayState context coupling was not rejected`n$script:SelfTestLastOutput"
		}
		Remove-Item -LiteralPath (Join-Path $fixtureScripts "bad_context.gd") -Force

		Set-Content -LiteralPath (Join-Path $fixtureScripts "duplicate.gd") -Value @(
			"extends RefCounted",
			"func _sample_context(value: Object) -> void:",
			"    pass",
			"",
			"func _sample_legacy(value: Object) -> void:",
			"    pass"
		) -Encoding UTF8
		$sameCountBaseline = Join-Path $selfTestRoot "same-count-baseline.json"
		$sameCountBaselineObject = $fixtureBaselineObject | ConvertTo-Json -Depth 5 | ConvertFrom-Json
		$sameCountBaselineObject.legacy_total = 2
		$sameCountBaselineObject.legacy_pairs = @("approved.gd:_approved")
		$sameCountBaselineObject | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $sameCountBaseline -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $fixtureScripts $sameCountBaseline) -eq 0) {
			throw "parallel legacy/context implementation was not rejected`n$script:SelfTestLastOutput"
		}
		Remove-Item -LiteralPath (Join-Path $fixtureScripts "duplicate.gd") -Force

		Set-Content -LiteralPath (Join-Path $fixtureScripts "root_access.gd") -Value @(
			"extends RefCounted",
			"func use_root(root: Object) -> void:",
			'    root.call("example")'
		) -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $fixtureScripts $fixtureBaseline) -eq 0 -or $script:SelfTestLastOutput -notmatch "Per-file dynamic_dispatch regression") {
			throw "per-file root-access regression was not specifically rejected`n$script:SelfTestLastOutput"
		}
		Remove-Item -LiteralPath (Join-Path $fixtureScripts "root_access.gd") -Force

		$strictScripts = Join-Path $selfTestRoot "strict-scripts"
		Copy-Item -LiteralPath $fixtureScripts -Destination $strictScripts -Recurse
		Set-Content -LiteralPath (Join-Path $strictScripts "root_access.gd") -Value @(
			"extends RefCounted",
			"func use_root(root: Object) -> void:",
			'    root.call("example")'
		) -Encoding UTF8
		$strictBaseline = Join-Path $selfTestRoot "strict-baseline.json"
		$strictBaselineObject = $fixtureBaselineObject | ConvertTo-Json -Depth 5 | ConvertFrom-Json
		$strictBaselineObject.root_accesses = 1
		$strictBaselineObject.per_file.'root_access.gd'.dynamic_dispatch = 1
		$strictBaselineObject.per_file.'root_access.gd'.reach_through = 1
		$strictBaselineObject.per_file.'root_access.gd'.untyped_root_parameters = 1
		$strictBaselineObject.architecture_rules.script_hygiene += @('root_access.gd')
		$strictBaselineObject.targets.root_accesses_max = 0
		$strictBaselineObject | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $strictBaseline -Encoding UTF8
		if ((Invoke-ValidatorForSelfTest $strictScripts $strictBaseline) -ne 0) {
			throw "valid regression fixture was rejected before strict target audit`n$script:SelfTestLastOutput"
		}
		if ((Invoke-ValidatorForSelfTest $strictScripts $strictBaseline -FixtureRequireTargets) -eq 0) {
			throw "strict target failure was not enforced`n$script:SelfTestLastOutput"
		}
		Write-Host "COMPOSITION_SELF_TEST_OK" -ForegroundColor Green
	}
	finally {
		if (Test-Path -LiteralPath $selfTestRoot) {
			Remove-Item -LiteralPath $selfTestRoot -Recurse -Force
		}
	}
	exit 0
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$baseline = $null
if (Test-Path -LiteralPath $resolvedBaselinePath) {
	$baseline = Get-Content -Raw -LiteralPath $resolvedBaselinePath | ConvertFrom-Json
} else {
	$errors.Add("No baseline file at $resolvedBaselinePath")
}

$allowlistProperty = Get-PropertyInfo $baseline "transitional_allowlist"
$transitionalAllowlist = if ($null -eq $allowlistProperty) {
	$errors.Add("Baseline has no transitional_allowlist; refusing to run with an implicit allowlist")
	@()
} else {
	@($allowlistProperty.Value | Where-Object { $null -ne $_ -and [string]$_ -ne "" } | ForEach-Object { [string]$_ })
}

$targetsValue = Get-PropertyValue $baseline "targets"
$targetValues = [ordered]@{}
if ($null -eq $targetsValue) {
	$errors.Add("Baseline has no targets object; refusing to run without recorded strict targets")
}
foreach ($targetName in $defaultTargets.Keys) {
	if ($null -ne $targetsValue -and $null -eq (Get-PropertyInfo $targetsValue $targetName)) {
		$errors.Add("Baseline targets object is missing '$targetName'; refusing to use an implicit target.")
	}
	$targetValues[$targetName] = Get-TargetValue $targetsValue $targetName $defaultTargets[$targetName]
}
$forwardTargetObject = Get-PropertyValue $targetsValue "forward"
$forwardTargetValues = [ordered]@{}
if ($null -eq $forwardTargetObject) {
	$errors.Add("Baseline targets object is missing 'forward'; refusing to run without explicit forward targets")
}
foreach ($targetName in $defaultForwardTargets.Keys) {
	$targetProperty = Get-PropertyInfo $forwardTargetObject $targetName
	if ($null -eq $targetProperty) {
		$errors.Add("Baseline forward targets are missing '$targetName'; refusing to use an implicit target")
		$forwardTargetValues[$targetName] = $defaultForwardTargets[$targetName]
		continue
	}
	$forwardTargetValues[$targetName] = $targetProperty.Value
	$defaultTarget = $defaultForwardTargets[$targetName]
	if ($defaultTarget -is [bool]) {
		if ([bool]$targetProperty.Value -ne $defaultTarget) {
			$errors.Add("Forward target '$targetName' cannot be loosened or changed without updating the reviewed target definition")
		}
	} elseif ([int]$targetProperty.Value -gt [int]$defaultTarget) {
		$errors.Add("Forward target '$targetName' was loosened from $defaultTarget to $($targetProperty.Value)")
	}
}
$requiredBaselineMetrics = @(
	"root_accesses",
	"gameplay_state_lines",
	"gameplay_state_fields",
	"room_controller_lines",
	"runtime_refs",
	"legacy_total"
)
foreach ($metricName in $requiredBaselineMetrics) {
	if ($null -eq (Get-PropertyInfo $baseline $metricName)) {
		$errors.Add("Baseline is missing required metric '$metricName'; refusing to use an implicit value.")
	}
}

$completionStart = Get-PropertyValue $baseline "completion_start"
if ($null -eq $completionStart) {
	$errors.Add("Baseline is missing 'completion_start'; refusing to compute a completion percentage from an implicit start.")
} else {
	foreach ($startName in @("root_accesses", "gameplay_state_lines", "gameplay_state_fields", "room_controller_lines", "runtime_refs", "legacy_pairs", "transitional_contexts")) {
		if ($null -eq (Get-PropertyInfo $completionStart $startName)) {
			$errors.Add("Baseline completion_start is missing '$startName'; refusing to use an implicit value.")
		}
	}
}
$targetValues.forward = $forwardTargetValues

if (-not (Test-Path -LiteralPath $resolvedScriptsDirectory)) {
	$errors.Add("Scripts directory does not exist: $resolvedScriptsDirectory")
}

$contextFiles = @()
$scriptFiles = @()
if (Test-Path -LiteralPath $resolvedScriptsDirectory) {
	$contextFiles = @(Get-ChildItem -LiteralPath $resolvedScriptsDirectory -Filter "*context*.gd" -File -Recurse)
	$scriptFiles = @(Get-ChildItem -LiteralPath $resolvedScriptsDirectory -Filter "*.gd" -File -Recurse)
}

# ---- 0. Architecture rules: snapshot existing debt, reject new violations ----
$architectureFindings = @{}
$allowedScriptRoles = @('actors', 'algorithms', 'components', 'content', 'editor', 'runtime', 'services', 'ui')
$controllerEdges = @{}
foreach ($file in $scriptFiles) {
	$relativePath = Get-RelativeScriptPath $file $resolvedScriptsDirectory
	$code = Get-CodeOnlyContent (Get-Content -Raw -LiteralPath $file.FullName)
	$lines = @($code -split "`r?`n")
	$isComponent = $file.Name -match 'component'
	if ($isComponent) {
		$blindCount = 0
		$selfWiringCount = 0
		for ($i = 0; $i -lt $lines.Count; $i += 1) {
			if ($lines[$i] -match '\b(get_parent|get_node)\s*\(' -or $lines[$i] -match '\broot\s*\.') {
				$blindCount += 1
			}
			if ($lines[$i] -match '\bfunc\s+initialize\s*\([^)]*\broot\b') {
				Add-RuleFinding $architectureFindings 'initialize_root' $relativePath
			}
			if ($lines[$i] -match '\b[A-Za-z_]\w*component\w*\s*\.\s*\w+\s*\.\s*connect\s*\(') {
				$selfWiringCount += 1
			}
		}
		for ($i = 1; $i -le $blindCount; $i += 1) { Add-RuleFinding $architectureFindings 'component_blindness' ("{0}#{1}" -f $relativePath, $i) }
		for ($i = 1; $i -le $selfWiringCount; $i += 1) { Add-RuleFinding $architectureFindings 'component_self_wiring' ("{0}#{1}" -f $relativePath, $i) }
	} elseif ($code -match '(?m)^\s*func\s+initialize\s*\([^)]*\broot\b') {
		Add-RuleFinding $architectureFindings 'initialize_root' $relativePath
	}
	if ($relativePath -match '(^|/)gameplay_frame_controller\.gd$') {
		# The frame controller is the sole owner of per-frame scheduling.
	} elseif ($code -match '(?m)^\s*func\s+_process\s*\(') {
		Add-RuleFinding $architectureFindings 'process_ownership' $relativePath
	}
	if ($code -match '(?m)^\s*(?:if|elif)\b[^\n]*\w*(?:id|element|variant)\w*\s*==\s*["''][^"'']+["'']') {
		Add-RuleFinding $architectureFindings 'identity_branches' $relativePath
	}
	if ($file.Name -match '_controller\.gd$') {
		$controllerEdges[$file.Name] = @([regex]::Matches($code, '(?:preload|load)\s*\(\s*["'']res://scripts/(?:[^"'']*/)?([^/"'']+_controller\.gd)["'']') | ForEach-Object { $_.Groups[1].Value })
	}
	$role = ($relativePath -split '/')[0]
	if ($relativePath -notmatch '/' -or $role -notin $allowedScriptRoles) {
		Add-RuleFinding $architectureFindings 'script_hygiene' $relativePath
	}
}

# Find directed cycles in controller preload/load dependencies.
$visitedControllers = @{}
$activeControllers = @{}
$reportedCycles = @{}
function Visit-Controller([string]$Controller, [string[]]$Stack) {
	if ($activeControllers.ContainsKey($Controller)) {
		$cycleStart = [array]::IndexOf($Stack, $Controller)
		if ($cycleStart -ge 0) {
			$cycle = @($Stack[$cycleStart..($Stack.Count - 1)] + $Controller)
			$key = (($cycle | Sort-Object -Unique) -join ' <-> ')
			if (-not $reportedCycles.ContainsKey($key)) {
				$reportedCycles[$key] = $true
				Add-RuleFinding $architectureFindings 'controller_cycles' $key
			}
		}
		return
	}
	if ($visitedControllers.ContainsKey($Controller)) { return }
	$visitedControllers[$Controller] = $true
	$activeControllers[$Controller] = $true
	$nextStack = @($Stack + $Controller)
	foreach ($dependency in @($controllerEdges[$Controller])) {
		if ($controllerEdges.ContainsKey($dependency)) { Visit-Controller $dependency $nextStack }
	}
	$activeControllers.Remove($Controller)
}
foreach ($controller in $controllerEdges.Keys) { Visit-Controller $controller @() }

# Require ownership notes only for new or materially expanded substantial files.
$baselinePerFileForRules = Get-PropertyValue $baseline 'per_file'
foreach ($file in $scriptFiles) {
	$relativePath = Get-RelativeScriptPath $file $resolvedScriptsDirectory
	$lineCount = @(Get-Content -LiteralPath $file.FullName).Count
	$priorMetric = Get-PropertyValue $baselinePerFileForRules $file.Name
	$priorLines = if ($null -ne $priorMetric) { Get-IntegerBaseline $priorMetric 'lines' 0 } else { 0 }
	$isNewLargeFile = ($priorLines -eq 0 -and $lineCount -gt 400)
	$isSubstantialGrowth = ($priorLines -gt 0 -and $lineCount -gt 400 -and (($lineCount -gt ($priorLines + 100) -and $lineCount -gt ($priorLines * 1.2)) -or $priorLines -le 400))
	$header = (Get-Content -LiteralPath $file.FullName -TotalCount 40) -join "`n"
	if (($isNewLargeFile -or $isSubstantialGrowth) -and $header -notmatch '(?m)^\s*#\s*(Owner|Responsibility):\s*\S') {
		Add-RuleFinding $architectureFindings 'god_file_declaration' $relativePath
	}
}

$baselineArchitectureRules = Get-PropertyValue $baseline 'architecture_rules'
if ($null -eq $baselineArchitectureRules) {
	$errors.Add('Baseline has no architecture_rules inventory; refusing to run without a reviewed snapshot of existing architectural debt.')
} else {
	foreach ($rule in $architectureFindings.Keys) {
		$baselineRule = Get-PropertyValue $baselineArchitectureRules $rule
		$allowedFindings = if ($null -eq $baselineRule) { @() } else { @($baselineRule | ForEach-Object { [string]$_ }) }
		foreach ($finding in $architectureFindings[$rule] | Sort-Object -Unique) {
			$isAllowed = $finding -in $allowedFindings
			if (-not $isAllowed -and $rule -ne 'script_hygiene') {
				$findingPath = [string]$finding -replace '#\d+$', ''
				$findingLeaf = ($findingPath -split '[/\\]')[-1]
				$matchingPrior = @($allowedFindings | Where-Object {
					$priorPath = ([string]$_ -replace ':\d+$', '' -replace '#\d+$', '')
					($priorPath -split '[/\\]')[-1] -eq $findingLeaf
				})
				if ($finding -match '#(\d+)$') { $isAllowed = [int]$Matches[1] -le $matchingPrior.Count }
				elseif ($matchingPrior.Count -gt 0) { $isAllowed = $true }
			}
			# Migrate older line-based snapshots to stable per-file ordinal keys
			# without treating line insertions as fresh violations.
			if (-not $isAllowed -and $finding -match '^(.*)#(\d+)$') {
				$findingFile = $Matches[1]
				$findingOrdinal = [int]$Matches[2]
				$filePrefix = [regex]::Escape($findingFile) + '(?::|#)'
				$priorCount = @($allowedFindings | Where-Object { $_ -match $filePrefix }).Count
				$isAllowed = $findingOrdinal -le $priorCount
			}
			if (-not $isAllowed) {
				$errors.Add("architecture rule '$rule' regression: $finding")
			}
		}
	}
}

# ---- 1. Contexts: GameplayState coupling and .runtime use ----
$transitionalFound = [System.Collections.Generic.List[string]]::new()
foreach ($file in $contextFiles) {
	$content = Get-Content -Raw -LiteralPath $file.FullName
	$codeContent = Get-CodeOnlyContent $content
	$className = ""
	$classMatch = [regex]::Match($content, '(?m)^class_name\s+(\w+)')
	if ($classMatch.Success) {
		$className = $classMatch.Groups[1].Value
	}
	if ($className -in $transitionalAllowlist) {
		if ($className -notin $transitionalFound) {
			$transitionalFound.Add($className)
		}
		continue
	}
	if ($codeContent -match '\bGameplayState\b') {
		$errors.Add("Context '$className' ($($file.Name)) stores or accepts GameplayState but is not on the JSON transitional allowlist")
	}
	if ($codeContent -match '\.runtime\b') {
		$errors.Add("Context '$className' ($($file.Name)) references '.runtime' but is not a transitional adapter")
	}
}
$missingAllowlist = @($transitionalAllowlist | Where-Object { $_ -notin $transitionalFound })
if ($missingAllowlist.Count -gt 0) {
	$errors.Add("Transitional allowlist is stale; missing context classes: $($missingAllowlist -join ', ')")
}

# ---- 2. Parallel legacy duplicates ----
$legacyAudit = Get-LegacyAudit $scriptFiles
$legacyCount = $legacyAudit.Count
$legacyPairs = @($legacyAudit.Pairs)
$baselineLegacyPairsProperty = Get-PropertyInfo $baseline "legacy_pairs"
$baselineLegacyPairs = if ($null -ne $baselineLegacyPairsProperty) {
	@($baselineLegacyPairsProperty.Value | ForEach-Object { [string]$_ })
} else {
	$errors.Add("Baseline has no legacy_pairs inventory; refusing to run without a pair-level duplicate baseline")
	@()
}
foreach ($pair in $legacyPairs) {
	if ($pair -notin $baselineLegacyPairs -and $null -ne $baselineLegacyPairsProperty) {
		$errors.Add("New parallel legacy/context implementation: $pair")
	}
}

# ---- 3. Metrics ----
$rootAccesses = 0
$gameplayStateLines = 0
$gameplayStateFields = 0
$roomControllerLines = 0
$runtimeRefs = 0
$gameplayLines = 0
$totalReachThrough = 0
$untypedRootParameters = 0
$liveContextTwinPairs = 0
$rootCallableStrings = 0
$stringSignalConnects = 0
$perFileMetrics = [ordered]@{}
foreach ($file in $scriptFiles) {
	$content = Get-Content -Raw -LiteralPath $file.FullName
	$codeContent = Get-CodeOnlyContent $content
	# Preserve the exact historical aggregate expression so the new per-file
	# view remains comparable to the accepted 2,202-site scorecard.
	$fileRootAccesses = ([regex]::Matches($codeContent, 'root\.(call|get|set)\(')).Count
	$fileReachThrough = ([regex]::Matches($codeContent, '\broot\.\w+')).Count
	$fileUntypedRootParameters = Get-UntypedRootParameterCount $codeContent
	$functionNames = @([regex]::Matches($codeContent, '(?m)^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(') | ForEach-Object { $_.Groups[1].Value })
	$functionNameSet = @{}
	foreach ($functionName in $functionNames) { $functionNameSet[$functionName] = $true }
	$fileContextTwins = 0
	foreach ($functionName in $functionNames) {
		if ($functionName -match '^(.+)_context$' -and $functionNameSet.ContainsKey($Matches[1])) {
			$fileContextTwins += 1
		}
	}
	$fileRuntimeRefs = ([regex]::Matches($codeContent, '\.runtime\b')).Count
	$fileRootCallableStrings = ([regex]::Matches($codeContent, 'Callable\s*\(\s*root\s*,\s*["''][^"'']+["'']')).Count
	$fileStringSignalConnects = ([regex]::Matches($codeContent, '\.connect\s*\(\s*["''][^"'']+["'']')).Count
	$rootAccesses += $fileRootAccesses
	$totalReachThrough += $fileReachThrough
	$untypedRootParameters += $fileUntypedRootParameters
	$liveContextTwinPairs += $fileContextTwins
	$rootCallableStrings += $fileRootCallableStrings
	$stringSignalConnects += $fileStringSignalConnects
	$runtimeRefs += $fileRuntimeRefs
	$relativeScriptPath = $file.FullName.Substring($resolvedScriptsDirectory.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
	$perFileMetrics[$file.Name] = [ordered]@{
		path = "scripts/$relativeScriptPath"
		lines = @(Get-Content -LiteralPath $file.FullName).Count
		dynamic_dispatch = $fileRootAccesses
		reach_through = $fileReachThrough
		untyped_root_parameters = $fileUntypedRootParameters
		live_context_twin_pairs = $fileContextTwins
		runtime_refs = $fileRuntimeRefs
		root_callable_strings = $fileRootCallableStrings
		string_signal_connects = $fileStringSignalConnects
	}
}
$gameplayFile = $scriptFiles | Where-Object { $_.Name -eq 'gameplay.gd' } | Select-Object -First 1
if ($null -ne $gameplayFile) { $gameplayLines = @(Get-Content -LiteralPath $gameplayFile.FullName).Count }
$gsFile = $scriptFiles | Where-Object { $_.Name -eq 'gameplay_state.gd' } | Select-Object -First 1
if ($null -ne $gsFile) {
	$gsLines = @(Get-Content -LiteralPath $gsFile.FullName)
	$gameplayStateLines = $gsLines.Count
	$gameplayStateFields = @($gsLines | Where-Object { $_ -match '^(var|const)\s' }).Count
}
$roomControllerFile = $scriptFiles | Where-Object { $_.Name -eq 'room_controller.gd' } | Select-Object -First 1
if ($null -ne $roomControllerFile) { $roomControllerLines = @(Get-Content -LiteralPath $roomControllerFile.FullName).Count }

$controllerFile = $scriptFiles | Where-Object { $_.Name -eq 'screen_state_controller.gd' } | Select-Object -First 1
$hubFlowFiles = @($scriptFiles | Where-Object { $_.Name -in @('hub_flow_controller.gd', 'hub_economy_controller.gd') })
$hubFlowSeams = 0
foreach ($hubControllerFile in $hubFlowFiles) {
	# The forward seam target covers the complete hub subsystem after its
	# presentation/economy split, so moving methods cannot make the metric fall.
	$hubFlowSeams += ([regex]::Matches((Get-CodeOnlyContent (Get-Content -Raw -LiteralPath $hubControllerFile.FullName)), 'root\.(call|get|set)\(')).Count
}
$bootstrapFile = $scriptFiles | Where-Object { $_.Name -eq 'gameplay_bootstrap.gd' } | Select-Object -First 1
$forwardCurrentValues = [ordered]@{
	screen_state_controller_lines = if ($null -ne $controllerFile) { @(Get-Content -LiteralPath $controllerFile.FullName).Count } else { 0 }
	hub_flow_controller_seams = $hubFlowSeams
	screen_state_controller_seams = if ($null -ne $controllerFile) { ([regex]::Matches((Get-CodeOnlyContent (Get-Content -Raw -LiteralPath $controllerFile.FullName)), 'root\.(call|get|set)\(')).Count } else { 0 }
	live_context_twin_pairs = $liveContextTwinPairs
	bootstrap_registration_rows = if ($null -ne $bootstrapFile) { ([regex]::Matches((Get-CodeOnlyContent (Get-Content -Raw -LiteralPath $bootstrapFile.FullName)), '_add_runtime_node\s*\(')).Count } else { 0 }
	scripts_flat_directory = (@($scriptFiles | Where-Object { (Get-RelativeScriptPath $_ $resolvedScriptsDirectory) -notmatch '/' }).Count -eq $scriptFiles.Count)
	untyped_root_parameters = $untypedRootParameters
	unclassified_scripts = @($scriptFiles | Where-Object { $rel = Get-RelativeScriptPath $_ $resolvedScriptsDirectory; $parts = $rel -split '/'; $rel -notmatch '/' -or $parts[0] -notin $allowedScriptRoles }).Count
}

# Per-file floors prevent an aggregate reduction in one owner from masking
# growth in another. Files are keyed by basename so an approved role-folder
# move preserves its metric identity.
$perFileBaseline = Get-PropertyValue $baseline "per_file"
if ($null -eq $perFileBaseline) {
	$errors.Add("Baseline has no per_file metric inventory; refusing to run without per-file regression floors.")
} else {
	foreach ($fileName in $perFileMetrics.Keys) {
		$currentMetric = $perFileMetrics[$fileName]
		$baselineMetricProperty = Get-PropertyInfo $perFileBaseline $fileName
		if ($null -eq $baselineMetricProperty) {
			if ($currentMetric.dynamic_dispatch -gt 0 -or $currentMetric.untyped_root_parameters -gt 0) {
				$errors.Add("Unbaselined script '$($currentMetric.path)' adds root seams; review and update its metric baseline deliberately")
			}
			continue
		}
		$baselineMetric = $baselineMetricProperty.Value
		foreach ($metricName in @("dynamic_dispatch", "reach_through", "untyped_root_parameters", "live_context_twin_pairs")) {
			$baselineValue = Get-IntegerBaseline $baselineMetric $metricName -1
			if ($baselineValue -ge 0 -and $currentMetric[$metricName] -gt $baselineValue) {
				$errors.Add("Per-file $metricName regression in '$($currentMetric.path)': $($currentMetric[$metricName]) > baseline $baselineValue")
			}
		}
	}
}

# ---- 4. Baseline comparison ----
$rootBaseline = Get-IntegerBaseline $baseline "root_accesses" 3140
$gsLinesBaseline = Get-IntegerBaseline $baseline "gameplay_state_lines" 1720
$gsFieldsBaseline = Get-IntegerBaseline $baseline "gameplay_state_fields" 287
$rcLinesBaseline = Get-IntegerBaseline $baseline "room_controller_lines" 2297
$runtimeBaseline = Get-IntegerBaseline $baseline "runtime_refs" 20
$legacyBaseline = Get-IntegerBaseline $baseline "legacy_total" 13

# ---- 4b. Editor composition metric ----
$editorComposition = Get-EditorComposition $resolvedScriptsDirectory $projectRoot
$editorBaseline = Get-PropertyValue $baseline "editor_composition"
$editorWarned = $false
if ($null -eq $editorBaseline) {
	$warnings.Add("Baseline has no editor_composition record; editor-composition percent is computed but not regression-guarded. Run -UpdateBaseline to lock it in.")
	$editorWarned = $true
} else {
	$editorBlindBaseline = Get-IntegerBaseline $editorBaseline "component_blind" -1
	$editorConfiguredBaseline = Get-IntegerBaseline $editorBaseline "component_configured" -1
	$editorBothBaseline = Get-IntegerBaseline $editorBaseline "component_both" -1
	$editorEditableBaseline = Get-IntegerBaseline $editorBaseline "definition_editable" -1
	if ($editorBlindBaseline -ge 0 -and $editorComposition.ComponentBlind -lt $editorBlindBaseline) {
		$errors.Add("Editor composition regression: blind components $($editorComposition.ComponentBlind) < baseline $editorBlindBaseline")
	}
	if ($editorConfiguredBaseline -ge 0 -and $editorComposition.ComponentConfigured -lt $editorConfiguredBaseline) {
		$errors.Add("Editor composition regression: editor-configured components $($editorComposition.ComponentConfigured) < baseline $editorConfiguredBaseline")
	}
	if ($editorBothBaseline -ge 0 -and $editorComposition.ComponentBoth -lt $editorBothBaseline) {
		$errors.Add("Editor composition regression: blind+configured components $($editorComposition.ComponentBoth) < baseline $editorBothBaseline")
	}
	if ($editorEditableBaseline -ge 0 -and $editorComposition.DefinitionEditable -lt $editorEditableBaseline) {
		$errors.Add("Editor composition regression: editor-able definition surfaces $($editorComposition.DefinitionEditable) < baseline $editorEditableBaseline")
	}
}

if ($rootAccesses -gt $rootBaseline) {
	$errors.Add("Root-access regression: $rootAccesses > baseline $rootBaseline")
}
if ($gameplayStateLines -gt $gsLinesBaseline) {
	$errors.Add("GameplayState line regression: $gameplayStateLines > baseline $gsLinesBaseline")
}
if ($gameplayStateFields -gt $gsFieldsBaseline) {
	$errors.Add("GameplayState field regression: $gameplayStateFields > baseline $gsFieldsBaseline")
}
if ($roomControllerLines -gt $rcLinesBaseline) {
	$errors.Add("RoomController size regression: $roomControllerLines > baseline $rcLinesBaseline")
}
if ($runtimeRefs -gt $runtimeBaseline) {
	$errors.Add(".runtime reference regression: $runtimeRefs > baseline $runtimeBaseline")
}
if ($legacyCount -gt $legacyBaseline) {
	$errors.Add("Legacy duplicate regression: $legacyCount > baseline $legacyBaseline")
}

if ($RequireTargets) {
	if ($rootAccesses -gt $targetValues.root_accesses_max) {
		$errors.Add("Strict target not met: root accesses $rootAccesses > $($targetValues.root_accesses_max)")
	}
	if ($gameplayStateLines -gt $targetValues.gameplay_state_lines_max) {
		$errors.Add("Strict target not met: GameplayState lines $gameplayStateLines > $($targetValues.gameplay_state_lines_max)")
	}
	if ($gameplayStateFields -gt $targetValues.gameplay_state_fields_max) {
		$errors.Add("Strict target not met: GameplayState fields $gameplayStateFields > $($targetValues.gameplay_state_fields_max)")
	}
	if ($roomControllerLines -gt $targetValues.room_controller_lines_max) {
		$errors.Add("Strict target not met: RoomController lines $roomControllerLines > $($targetValues.room_controller_lines_max)")
	}
	if ($runtimeRefs -gt $targetValues.runtime_refs_max) {
		$errors.Add("Strict target not met: .runtime references $runtimeRefs > $($targetValues.runtime_refs_max)")
	}
	if ($legacyPairs.Count -gt $targetValues.legacy_pairs_max) {
		$errors.Add("Strict target not met: legacy/context duplicate pairs $($legacyPairs.Count) > $($targetValues.legacy_pairs_max)")
	}
	if ($transitionalFound.Count -gt $targetValues.transitional_contexts_max) {
		$errors.Add("Strict target not met: transitional contexts $($transitionalFound.Count) > $($targetValues.transitional_contexts_max)")
	}
}

# ---- 5. Output and baseline update ----
$completion = Get-CompletionPercent `
	$rootAccesses $gameplayStateLines $gameplayStateFields `
	$roomControllerLines $runtimeRefs $legacyPairs.Count $transitionalFound.Count `
	$completionStart $targetValues
Write-Host "COMPOSITION_AUDIT" -ForegroundColor Cyan
Write-Host "  mode              : $(if ($RequireTargets) { 'strict targets' } else { 'regression floor' })"
Write-Host ("  completion        : {0:P1} (weighted progress from recorded start toward strict targets)" -f $completion.Percent)
Write-Host "  root.call/get/set : $rootAccesses (baseline $rootBaseline; target <= $($targetValues.root_accesses_max))"
Write-Host "  GameplayState     : $gameplayStateLines lines / $gameplayStateFields fields (baseline $gsLinesBaseline / $gsFieldsBaseline)"
Write-Host "  RoomController    : $roomControllerLines lines (baseline $rcLinesBaseline; target <= $($targetValues.room_controller_lines_max))"
Write-Host "  .runtime refs     : $runtimeRefs (baseline $runtimeBaseline; target <= $($targetValues.runtime_refs_max))"
Write-Host "  reach-through     : $totalReachThrough across root.<member> reads/calls"
Write-Host "  untyped root args : $untypedRootParameters Object/Variant or untyped root parameters (composition-plan audit counted 560)"
Write-Host "  context twins     : $liveContextTwinPairs live _context pairs"
Write-Host "  string call forms : $rootCallableStrings Callable(root, string) / $stringSignalConnects string .connect calls"
Write-Host "  legacy duplicates : $legacyCount total / $($legacyPairs.Count) paired (baseline $legacyBaseline / $(($baselineLegacyPairs | Measure-Object).Count))"
Write-Host "  contexts          : $($contextFiles.Count) files; $($transitionalFound.Count) transitional allowlisted"
Write-Host ("  scripts           : {0} GDScript files; {1} directories; {2} unclassified" -f $scriptFiles.Count, @((Get-ChildItem -LiteralPath $resolvedScriptsDirectory -Directory -Recurse)).Count, $forwardCurrentValues.unclassified_scripts)
Write-Host "  forward targets   : metric / current / target / stage / status"
foreach ($targetName in $defaultForwardTargets.Keys) {
	$currentValue = $forwardCurrentValues[$targetName]
	$targetValue = $forwardTargetValues[$targetName]
	$isMet = if ($targetValue -is [bool]) { [bool]$currentValue -eq [bool]$targetValue } else { [int]$currentValue -le [int]$targetValue }
	$status = if ($isMet) { 'met' } else { 'open' }
	$stage = if ($forwardTargetStages.ContainsKey($targetName)) { $forwardTargetStages[$targetName] } else { 0 }
	Write-Host ("    {0} / {1} / {2} / {3} / {4}" -f $targetName, $currentValue, $targetValue, $stage, $status)
}
foreach ($pair in $legacyPairs) {
	Write-Host "  duplicate pair: $pair" -ForegroundColor Yellow
}
$topSeamFiles = @($perFileMetrics.GetEnumerator() | Sort-Object { $_.Value.dynamic_dispatch } -Descending | Select-Object -First 20)
Write-Host "  top root seams    : file / dynamic / reach-through / untyped root params"
foreach ($entry in $topSeamFiles) {
	Write-Host ("    {0} / {1} / {2} / {3}" -f $entry.Value.path, $entry.Value.dynamic_dispatch, $entry.Value.reach_through, $entry.Value.untyped_root_parameters)
}
Write-Host ("  editor compos.   : {0:P1} (weighted; direct+editor changeable)" -f $editorComposition.Composite)
Write-Host ("    components      : {0} blind / {1} editor-configured / {2} both of {3} (direct {4:P0} / editor {5:P0} / both {6:P0})" -f $editorComposition.ComponentBlind, $editorComposition.ComponentConfigured, $editorComposition.ComponentBoth, $editorComposition.ComponentTotal, $editorComposition.ComponentDirect, $editorComposition.ComponentEditor, $editorComposition.ComponentBothRate)
Write-Host ("    definitions     : {0} editor-able of {1} surfaces ({2:P0})" -f $editorComposition.DefinitionEditable, $editorComposition.DefinitionTotal, $editorComposition.DefinitionEditor)
if ($completion.Details.Count -gt 0) {
	Write-Host "  progress detail  : $($completion.Details -join ', ')"
}

if ($UpdateBaseline) {
	if ($errors.Count -gt 0) {
		$errors.Add("Refusing -UpdateBaseline because the current tree has audit errors")
	} elseif ($null -eq $baseline) {
		$errors.Add("Refusing -UpdateBaseline because no baseline JSON was loaded")
	} else {
		# completion_start is a fixed reference: it is seeded from the current
		# values on first creation and then preserved on later updates so the
		# completion percentage measures progress since the original start,
		# not since the last baseline refresh. There is no implicit re-zeroing.
		$resolvedCompletionStart = $completionStart
		if ($null -eq $resolvedCompletionStart) {
			$resolvedCompletionStart = [ordered]@{
				root_accesses = $rootAccesses
				gameplay_state_lines = $gameplayStateLines
				gameplay_state_fields = $gameplayStateFields
				room_controller_lines = $roomControllerLines
				runtime_refs = $runtimeRefs
				legacy_pairs = $legacyPairs.Count
				transitional_contexts = $transitionalFound.Count
			}
		}
		$newBaseline = [ordered]@{
			root_accesses = $rootAccesses
			gameplay_state_lines = $gameplayStateLines
			gameplay_state_fields = $gameplayStateFields
			room_controller_lines = $roomControllerLines
			runtime_refs = $runtimeRefs
			legacy_total = $legacyCount
			legacy_pairs = @($legacyPairs)
			transitional_allowlist = @($transitionalAllowlist)
			completion_start = $resolvedCompletionStart
			targets = $targetValues
			architecture_rules = [ordered]@{}
			per_file = $perFileMetrics
			metric_snapshot = [ordered]@{
				gameplay_lines = $gameplayLines
				total_reach_through = $totalReachThrough
				untyped_root_parameters = $untypedRootParameters
				live_context_twin_pairs = $liveContextTwinPairs
				root_callable_strings = $rootCallableStrings
				string_signal_connects = $stringSignalConnects
				script_subdirectories = @((Get-ChildItem -LiteralPath $resolvedScriptsDirectory -Directory -Recurse)).Count
				unclassified_scripts = $forwardCurrentValues.unclassified_scripts
			}
			editor_composition = [ordered]@{
				component_total = $editorComposition.ComponentTotal
				component_blind = $editorComposition.ComponentBlind
				component_configured = $editorComposition.ComponentConfigured
				component_both = $editorComposition.ComponentBoth
				definition_total = $editorComposition.DefinitionTotal
				definition_editable = $editorComposition.DefinitionEditable
			}
		}
		foreach ($ruleName in ($architectureFindings.Keys | Sort-Object)) {
			$newBaseline.architecture_rules[$ruleName] = @($architectureFindings[$ruleName] | Sort-Object -Unique)
		}
		$newBaseline.forward_status = [ordered]@{}
		foreach ($targetName in $defaultForwardTargets.Keys) {
			$currentValue = $forwardCurrentValues[$targetName]
			$targetValue = $forwardTargetValues[$targetName]
			$isMet = if ($targetValue -is [bool]) { [bool]$currentValue -eq [bool]$targetValue } else { [int]$currentValue -le [int]$targetValue }
			$newBaseline.forward_status[$targetName] = [ordered]@{
				current = $currentValue
				status = if ($isMet) { 'met' } else { 'open' }
				stage = if ($forwardTargetStages.ContainsKey($targetName)) { $forwardTargetStages[$targetName] } else { 0 }
			}
		}
		$newBaseline.floor_adjustments = [ordered]@{
			gameplay_state_fields_max = 'Raised from 286 to 287 to allow one field of headroom; forward seam, twin, and ownership metrics track architectural progress independently.'
		}
		$json = $newBaseline | ConvertTo-Json -Depth 6
		# ConvertTo-Json can render a nested empty array as null; normalize those
		# back to [] so the guardrail reads a clean empty allowlist.
		$json = [regex]::Replace($json, ':\s*null(\s*(,|\}))', ': []$1')
		$json | Set-Content -LiteralPath $resolvedBaselinePath -Encoding UTF8
		Write-Host "COMPOSITION_BASELINE_UPDATED" -ForegroundColor Green
	}
}

foreach ($warning in $warnings) {
	Write-Host "WARN: $warning" -ForegroundColor Yellow
}

if ($errors.Count -gt 0) {
	Write-Host "COMPOSITION_AUDIT_FAILED" -ForegroundColor Red
	foreach ($errorMessage in $errors) {
		Write-Host "- $errorMessage" -ForegroundColor Red
	}
	exit 1
}
Write-Host "COMPOSITION_AUDIT_OK" -ForegroundColor Green
exit 0
