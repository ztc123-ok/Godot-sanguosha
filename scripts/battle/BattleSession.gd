extends Node
## 当前战斗会话。章节进度状态不再承担全项目的活动关卡身份。

signal active_battle_changed(battle_id: StringName)
## 章节进度对象监听此信号；战斗场景不直接依赖任何具体章节。
signal battle_completed(battle_id: StringName, player_won: bool, definition: Dictionary)

var active_battle_id: StringName = &""


func activate_battle(battle_selector: Variant) -> bool:
	var battle_id := BattleCatalog.resolve_battle_id(battle_selector)
	if battle_id == &"":
		return false
	active_battle_id = battle_id
	active_battle_changed.emit(active_battle_id)
	return true


func clear_active_battle() -> void:
	active_battle_id = &""
	active_battle_changed.emit(active_battle_id)


func active_definition() -> Dictionary:
	return BattleCatalog.definition(active_battle_id)


func has_active_battle() -> bool:
	return not active_battle_id.is_empty() and BattleCatalog.has_battle(active_battle_id)


func report_outcome(player_won: bool) -> Dictionary:
	var finished_id := active_battle_id
	var finished_definition := active_definition()
	if finished_definition.is_empty():
		return {}
	battle_completed.emit(finished_id, player_won, finished_definition.duplicate(true))
	if player_won or not bool(finished_definition.get("retry_on_loss", true)):
		clear_active_battle()
	return finished_definition
