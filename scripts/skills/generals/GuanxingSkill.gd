class_name GuanxingSkill
extends Skill

func _init() -> void:
	super(&"guanxing", "观星", "准备阶段，你可以观看牌堆顶两张牌，并以指定顺序置于牌堆顶或牌堆底。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"start_phase"
func can_trigger(_context: RefCounted, game: Node, owner: Node) -> bool:
	return owner.hp > 0 and (not game.draw_pile.is_empty() or not game.discard_pile.is_empty())
func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return true
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "guanxing"}
