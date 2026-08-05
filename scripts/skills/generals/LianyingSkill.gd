class_name LianyingSkill
extends Skill
## 连营：每当一次原子牌移动令你失去所有手牌后，你可以摸一张牌。

const CardMoveContextScript = preload("res://scripts/skills/CardMoveContext.gd")

func _init() -> void:
	super(
		&"lianying",
		"连营",
		"每当你因使用、打出、被弃置、被获得、交给他人或作为技能代价而失去最后的手牌后，你可以摸一张牌。",
		ActivationMode.TRIGGERED
	)

func trigger_timing() -> StringName: return &"after_card_move"

func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	var move := context as CardMoveContextScript
	return move != null and move.owner == owner and move.lost_all_hand_cards()

func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return true
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "lianying_draw"}
