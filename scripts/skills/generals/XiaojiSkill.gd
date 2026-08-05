class_name XiaojiSkill
extends Skill
## 枭姬：每当你失去装备区里的一张牌后，你可以摸两张牌。

const CardMoveContextScript = preload("res://scripts/skills/CardMoveContext.gd")

func _init() -> void:
	super(
		&"xiaoji",
		"枭姬",
		"每当你失去装备区里的一张牌后，你可以摸两张牌。",
		ActivationMode.TRIGGERED
	)

func trigger_timing() -> StringName: return &"after_card_move"

func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	var move := context as CardMoveContextScript
	return move != null and move.owner == owner and not move.lost_equipment_cards().is_empty()

## 一次移动失去多张装备时，按实际失去的每张装备分别生成触发。
func trigger_repeat_count(context: RefCounted, _game: Node, _owner: Node) -> int:
	var move := context as CardMoveContextScript
	return move.lost_equipment_cards().size() if move != null else 0

func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return true
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "xiaoji_draw"}
