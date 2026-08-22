$ErrorActionPreference = "Stop"
$root = "C:\Development\Tiny-Demons\TinyDemons"
$godot = "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$logFile = Join-Path $root ".godot_user/smoke.log"
$tests = @("composition_root_baseline_smoke", "title_boot_scene_smoke", "run_grade_smoke", "progression_smoke", "item_economy_smoke", "rogue_slime_smoke", "speed_scale_smoke", "fusion_tooltip_smoke", "palette_smoke", "combat_momentum_smoke", "chroma_state_smoke", "chroma_pickup_smoke", "aspect_ability_smoke", "starter_flame_smoke", "actor_geometry_scene_smoke", "boss_geometry_scene_smoke", "input_router_smoke", "chroma_projectile_scene_smoke", "frame_time_smoke")
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
