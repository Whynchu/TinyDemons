extends EnemyBrainBehaviorComponent
class_name SlimeBrainBehaviorComponent

## Slimes approach their preferred melee ring, widening it while support
## casting is available.


func preferred_attack_distance(_default_distance: float, attack_range: float, support_preferred_range: float, support_positioning: bool) -> float:
	var desired_distance := attack_range * 0.72
	if support_positioning:
		desired_distance = maxf(desired_distance, support_preferred_range)
	return desired_distance


func adjust_approach_interest(interest: float, distance: float, desired_distance: float) -> float:
	return -interest if distance < desired_distance else interest
