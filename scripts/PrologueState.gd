extends Node
## 序章场景间共享的最小进度状态。

signal progress_changed

const BATTLE_COUNT := 2

var completed_battles: int = 0
var active_battle: int = 0


func can_start_battle(battle_index: int) -> bool:
	return battle_index >= 1 and battle_index <= completed_battles + 1 and battle_index <= BATTLE_COUNT


func start_battle(battle_index: int) -> bool:
	if not can_start_battle(battle_index):
		return false
	active_battle = battle_index
	return true


func complete_active_battle() -> void:
	if active_battle >= 1 and active_battle <= BATTLE_COUNT:
		completed_battles = maxi(completed_battles, active_battle)
	active_battle = 0
	progress_changed.emit()


func can_enter_village() -> bool:
	return completed_battles >= BATTLE_COUNT
