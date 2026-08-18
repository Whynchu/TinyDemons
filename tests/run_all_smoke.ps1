$ErrorActionPreference = "Stop"
$root = "C:\Development\Tiny-Demons\TinyDemons"
$godot = "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$tests = @("run_grade_smoke", "progression_smoke", "item_economy_smoke", "rogue_slime_smoke", "speed_scale_smoke", "fusion_tooltip_smoke", "palette_smoke", "combat_momentum_smoke")
$failed = $false
foreach ($test in $tests) {
	Write-Host "=== $test ==="
	& $godot --headless --path $root -s ("res://tests/{0}.gd" -f $test)
	if ($LASTEXITCODE -ne 0) {
		Write-Host "FAILED: $test (exit $LASTEXITCODE)" -ForegroundColor Red
		$failed = $true
	} else {
		Write-Host "PASSED: $test" -ForegroundColor Green
	}
}
Write-Host "=== main scene headless run ==="
& $godot --headless --path $root --quit-after 30
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