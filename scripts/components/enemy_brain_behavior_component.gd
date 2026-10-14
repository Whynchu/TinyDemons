extends Node
class_name EnemyBrainBehaviorComponent

## Family-owned steering preferences consumed by the shared EnemyBrain.
## Keep this component independent of actor identity and runtime roots.


func preferred_attack_distance(default_distance: float, _attack_range: float, _support_preferred_range: float, _support_positioning: bool) -> float:
	return default_distance


func adjust_approach_interest(interest: float, distance: float, desired_distance: float) -> float:
	return interest
