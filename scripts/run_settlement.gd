extends RefCounted
class_name RunSettlement


static func settle(profile: PlayerProfile, run_state: RunState, result: StringName) -> bool:
	if profile == null or run_state == null:
		return false
	if run_state.settled:
		return false
	if not ProfileSaveService.save_profile(profile):
		return false
	return run_state.mark_settled(result)
