class_name LuoshenSkill
extends Skill

func _init() -> void:
	super(&"luoshen", "洛神", "准备阶段，你可以判定；黑色则获得判定牌并可继续，红色则结束。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"start_phase"
func can_trigger(_context: RefCounted, _game: Node, owner: Node) -> bool: return owner.hp > 0
func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return true
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "luoshen"}
