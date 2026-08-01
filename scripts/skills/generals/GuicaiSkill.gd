class_name GuicaiSkill
extends Skill

const JudgementContextScript = preload("res://scripts/skills/JudgementContext.gd")

func _init() -> void:
	super(&"guicai", "鬼才", "任意角色的判定牌生效前，你可以打出一张手牌代替之。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"judgement_replace"
func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	return context is JudgementContextScript and not owner.hand.is_empty() and owner.general_id not in context.offered_guicai_owners
func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool: return false
func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": "guicai"}
