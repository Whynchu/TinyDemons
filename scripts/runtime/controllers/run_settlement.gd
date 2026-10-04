extends RefCounted
class_name RunSettlement

const RunSettlementResultScript = preload("res://scripts/runtime/contexts/run_settlement_result.gd")


static func settle(context: RunSettlementContext) -> RunSettlementResult:
	var outcome: RunSettlementResult = RunSettlementResultScript.new()
	if context != null:
		outcome.result = context.result
	if context == null or not context.is_valid():
		return outcome
	if context.run_state.settled:
		outcome.status = RunSettlementResult.Status.ALREADY_SETTLED
		return outcome
	if not can_settle(context.run_state, context.result):
		outcome.status = RunSettlementResult.Status.NOT_SETTLEABLE
		return outcome
	if not RunCheckpointService.save_profile_now(context.player_profile):
		outcome.status = RunSettlementResult.Status.SAVE_FAILED
		return outcome
	if not context.run_state.mark_settled(context.result):
		outcome.status = RunSettlementResult.Status.ALREADY_SETTLED
		return outcome
	outcome.status = RunSettlementResult.Status.SETTLED
	return outcome


static func can_settle(run_state: RunState, result: StringName) -> bool:
	return run_state != null and run_state.active and not run_state.settled and not result.is_empty()
