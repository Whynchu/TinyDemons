extends RefCounted
class_name RunCheckpointService

const ActiveRunSnapshotScript = preload("res://scripts/content/active_run_snapshot.gd")
const ActiveRunSaveServiceScript = preload("res://scripts/runtime/services/active_run_save_service.gd")
const RunCheckpointResultScript = preload("res://scripts/runtime/contexts/run_checkpoint_result.gd")


static func save_safe_state(context: RunCheckpointContext) -> RunCheckpointResult:
	var result: RunCheckpointResult = RunCheckpointResultScript.new()
	if context != null and context.room_context != null:
		result.room_id = context.room_context.room_id
	if not OS.has_feature("web"):
		result.status = RunCheckpointResult.Status.NOT_AVAILABLE
		return result
	if context == null or not context.is_valid():
		return result
	var room_result := context.room_context.room_controller.save_current_room_state(context.room_context)
	if not room_result.succeeded():
		result.status = RunCheckpointResult.Status.ROOM_SAVE_FAILED
		return result
	if not save_profile_now(context.player_profile):
		result.status = RunCheckpointResult.Status.PROFILE_SAVE_FAILED
		return result
	var snapshot := ActiveRunSnapshotScript.create(context.snapshot_context)
	if snapshot.is_empty():
		result.status = RunCheckpointResult.Status.SNAPSHOT_INVALID
		return result
	if not ActiveRunSaveServiceScript.save_snapshot(snapshot, context.profile_slot):
		result.status = RunCheckpointResult.Status.SNAPSHOT_SAVE_FAILED
		return result
	result.status = RunCheckpointResult.Status.SAVED
	return result


## Settles any queued profile write before returning success, so a checkpoint can
## never report a persisted profile that is still sitting in the write queue.
static func save_profile_now(profile: PlayerProfile) -> bool:
	if ProfileSaveService.has_pending_save():
		return ProfileSaveService.flush_deferred_save(true)
	return ProfileSaveService.save_profile(profile)
