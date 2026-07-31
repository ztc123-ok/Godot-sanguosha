class_name JianxiongSkill
extends Skill


func _init() -> void:
	super(
		&"jianxiong",
		"奸雄",
		"每次受到一次伤害后，若造成伤害的实体牌仍在处理区，你可以获得该牌。",
		ActivationMode.TRIGGERED
	)


func trigger_timing() -> StringName:
	return &"after_damage"


func can_trigger(event_context: RefCounted, game: Node, owner: Node) -> bool:
	var damage := event_context as DamageContext
	return (
		damage != null
		and damage.target == owner
		and not damage.is_chain_transfer
		and damage.source_card != null
		and game.is_card_in_processing(damage.source_card)
	)


func should_ai_activate(_event_context: RefCounted, _game: Node, _owner: Node) -> bool:
	return true


func build_resolution_request(
	event_context: RefCounted,
	_game: Node,
	_owner: Node
) -> Dictionary:
	var damage := event_context as DamageContext
	return {
		"action": &"gain_processing_card",
		"card": damage.source_card,
	}
