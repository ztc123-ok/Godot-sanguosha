class_name BiyueSkill
extends Skill
## 闭月：结束阶段开始时，你可以摸一张牌。

func _init() -> void:
	super(
		&"biyue",
		"闭月",
		"结束阶段开始时，你可以摸一张牌。",
		ActivationMode.TRIGGERED
	)

func trigger_timing() -> StringName: return &"end_phase_start"

func can_trigger(_context: RefCounted, game: Node, owner: Node) -> bool:
	return owner == game.current_player() and owner.hp > 0

func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return true
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "biyue_draw"}
