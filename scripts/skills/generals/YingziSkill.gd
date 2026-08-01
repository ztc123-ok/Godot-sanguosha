class_name YingziSkill
extends Skill

func _init() -> void:
	super(&"yingzi", "英姿", "摸牌阶段，你可以令本次正常摸牌数+1。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"before_draw"
func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool: return context is DrawContext and context.player == owner and not context.draw_replaced
func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return true
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "yingzi"}
