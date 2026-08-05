extends Node
## 序章场景间共享的最小进度状态。

signal progress_changed

const BATTLE_COUNT := 2

var completed_battles: int = 0
## 兼容旧代码的序章整数视图；新系统以 BattleSession.active_battle_id 为准。
var active_battle: int:
	get:
		return BattleCatalog.legacy_index_for_id(BattleSession.active_battle_id)
	set(value):
		if value <= 0:
			BattleSession.clear_active_battle()
		else:
			var battle_id := BattleCatalog.id_for_legacy_index(value)
			if battle_id == &"" or not BattleSession.activate_battle(battle_id):
				BattleSession.clear_active_battle()


func _ready() -> void:
	BattleSession.battle_completed.connect(_on_battle_completed)


func can_start_battle(battle_index: int) -> bool:
	return battle_index >= 1 and battle_index <= completed_battles + 1 and battle_index <= BATTLE_COUNT


func start_battle(battle_index: int) -> bool:
	if not can_start_battle(battle_index):
		return false
	return BattleSession.activate_battle(BattleCatalog.id_for_legacy_index(battle_index))


func complete_active_battle() -> void:
	BattleSession.report_outcome(true)


func _on_battle_completed(battle_id: StringName, player_won: bool, definition: Dictionary) -> void:
	if not player_won or StringName(definition.get("chapter_id", &"")) != &"prologue":
		return
	var completed_index := int(definition.get(
		"chapter_battle_index",
		BattleCatalog.legacy_index_for_id(battle_id)
	))
	if completed_index >= 1 and completed_index <= BATTLE_COUNT:
		completed_battles = maxi(completed_battles, completed_index)
	progress_changed.emit()


func can_enter_village() -> bool:
	return completed_battles >= BATTLE_COUNT
