$ErrorActionPreference = "Stop"
$root = "C:\Development\Tiny-Demons\TinyDemons"
$godot = "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$logFile = Join-Path $root ".godot_user/smoke.log"
$tests = @("composition_root_baseline_smoke", "title_boot_scene_smoke", "settings_service_smoke", "settings_panel_scene_smoke", "run_grade_smoke", "element_catalog_smoke", "elemental_damage_smoke", "slime_variant_smoke", "typed_combat_path_smoke", "typed_damage_feedback_smoke", "progression_smoke", "item_economy_smoke", "chest_reward_smoke", "fusion_candidate_cache_smoke", "rogue_slime_smoke", "speed_scale_smoke", "fusion_tooltip_smoke", "palette_smoke", "entry_orb_visual_smoke", "run1_map_contract_smoke", "run1_room_prefab_smoke", "run1_door_path_smoke", "run2_authored_layout_smoke", "enemy_room_engagement_smoke", "enemy_room_entrance_scene_smoke", "generated_layout_smoke", "generated_flame_progression_smoke", "elemental_binding_smoke", "hub_binding_smoke", "generated_fusion_gate_scene_smoke", "generated_minimap_smoke", "generated_run_scene_smoke", "hub_door_scene_smoke", "orb_interaction_scene_smoke", "run1_orb_door_scene_smoke", "boss_soul_drop_smoke", "special_respawn_policy_smoke", "treasure_chest_persistence_smoke", "run1_minimap_smoke", "run1_reference_map_smoke", "run1_door_color_smoke", "combat_momentum_smoke", "chroma_state_smoke", "chroma_pickup_smoke", "item_drop_scene_smoke", "chest_interaction_scene_smoke", "run_label_progression_smoke", "aspect_ability_smoke", "starter_flame_smoke", "actor_geometry_scene_smoke", "target_facing_scene_smoke", "attack_shadow_scene_smoke", "boss_geometry_scene_smoke", "popcorn_respawn_smoke", "boss_exit_path_scene_smoke", "input_router_smoke", "input_device_tracker_smoke", "touch_controls_smoke", "dialogue_choice_smoke", "chroma_projectile_scene_smoke", "imbue_spell_scene_smoke", "sound_mix_profile_smoke", "sound_mix_live_reload_smoke", "run_music_flame_gate_smoke", "sound_balance_smoke", "frame_time_smoke")
$tests += "dungeon_map_event_smoke"
$tests += "display_layout_smoke"
$tests += "display_responsive_scene_smoke"
$tests += "pause_menu_scene_smoke"
$tests += "soul_pickup_smoke"
$tests += "fire_exchange_smoke"
$tests += "circular_input_smoke"
$tests += "spin_damage_smoke"
$tests += "spin_charge_scene_smoke"
$tests += "six_stat_profile_migration_smoke"
$tests += "six_stat_calculator_smoke"
$tests += "composite_elemental_damage_smoke"
$tests += "six_stat_equipment_smoke"
$tests += "six_stat_menu_scene_smoke"
$tests += "generated_bound_reachability_smoke"
$tests += "equipment_menu_scene_smoke"
$tests += "name_entry_scene_smoke"
$tests += "demon_hub_menu_scene_smoke"
$tests += "menu_text_smoke"
$tests += "imbue_intelligence_smoke"
$tests += "menu_route_scene_smoke"
$tests += "run_locomotion_smoke"
$tests += "wall_socket_geometry_smoke"
$tests += "starter_flame_hub_scene_smoke"
$tests += "gear_catalogue_expansion_smoke"
$tests += "gear_effect_contract_smoke"
$tests += "gear_slot_migration_smoke"
$tests += "gear_drop_policy_smoke"
$tests += "gear_system_rework_smoke"
$tests += "player_hud_scene_smoke"
$tests += "cloud_save_contract_smoke"
$failed = $false
foreach ($test in $tests) {
	Write-Host "=== $test ==="
	& $godot --headless --path $root --log-file $logFile -s ("res://tests/{0}.gd" -f $test)
	if ($LASTEXITCODE -ne 0) {
		Write-Host "FAILED: $test (exit $LASTEXITCODE)" -ForegroundColor Red
		$failed = $true
	} else {
		Write-Host "PASSED: $test" -ForegroundColor Green
	}
}
Write-Host "=== sfx lab pytest ==="
$sfxLabPy = "C:\Development\Tiny-Demons\TinyDemons\tools\sfx_reconstruction\.venv311\Scripts\python.exe"
$sfxLabTests = "C:\Development\Tiny-Demons\TinyDemons\tools\sfx_lab\tests"
& $sfxLabPy -m pytest $sfxLabTests -q
if ($LASTEXITCODE -ne 0) {
	Write-Host "FAILED: sfx lab pytest (exit $LASTEXITCODE)" -ForegroundColor Red
	$failed = $true
} else {
	Write-Host "PASSED: sfx lab pytest" -ForegroundColor Green
}
Write-Host "=== web export smoke ==="
$webSmoke = Join-Path $PSScriptRoot "web_export_smoke.ps1"
$webSmokeArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $webSmoke)
if ($env:REQUIRE_WEB_EXPORT -eq "1") { $webSmokeArgs += "-RequireExport" }
& pwsh @webSmokeArgs
if ($LASTEXITCODE -ne 0) {
	Write-Host "FAILED: web export smoke (exit $LASTEXITCODE)" -ForegroundColor Red
	$failed = $true
} else {
	Write-Host "PASSED: web export smoke" -ForegroundColor Green
}
Write-Host "=== main scene headless run ==="
& $godot --headless --path $root --log-file $logFile --quit-after 30
if ($LASTEXITCODE -ne 0) {
	Write-Host "FAILED: main scene (exit $LASTEXITCODE)" -ForegroundColor Red
	$failed = $true
} else {
	Write-Host "PASSED: main scene" -ForegroundColor Green
}
if ($failed) {
	Write-Host "SMOKE SUITE FAILED" -ForegroundColor Red
	exit 1
}
Write-Host "SMOKE SUITE OK" -ForegroundColor Green
exit 0
