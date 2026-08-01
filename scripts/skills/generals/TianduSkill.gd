class_name TianduSkill
extends Skill

const JudgementContextScript = preload("res://scripts/skills/JudgementContext.gd")

func _init() -> void:
	super(&"tiandu", "天妒", "你的判定牌生效后、进入弃牌堆前，你可以获得最终生效的判定牌。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"after_judgement"
func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	return context is JudgementContextScript and context.judged_player == owner and context.effective_card != null and not context.is_claimed()
func should_ai_activate(context: RefCounted, game: Node, owner: Node) -> bool: return can_trigger(context, game, owner)
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "tiandu"}
