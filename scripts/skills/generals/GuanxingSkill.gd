class_name GuanxingSkill
extends Skill

func _init() -> void:
	super(
		&"guanxing",
		"观星",
		"准备阶段，你可以观看牌堆顶的X张牌（X为存活角色数且最多为5），将其中任意数量的牌以任意顺序置于牌堆顶，其余以任意顺序置于牌堆底。",
		ActivationMode.TRIGGERED
	)

func trigger_timing() -> StringName: return &"start_phase"
func can_trigger(_context: RefCounted, game: Node, owner: Node) -> bool:
	return owner.hp > 0 and (not game.draw_pile.is_empty() or not game.discard_pile.is_empty())
func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return true
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "guanxing"}
