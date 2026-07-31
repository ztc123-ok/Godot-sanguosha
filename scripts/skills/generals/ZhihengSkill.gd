class_name ZhihengSkill
extends Skill


func _init() -> void:
	super(
		&"zhiheng",
		"制衡",
		"出牌阶段限一次，你可以弃置至少一张手牌或装备牌，然后摸等量的牌。",
		ActivationMode.ACTIVE,
		[],
		UsageScope.PER_TURN,
		1
	)


func can_activate(game: Node, owner: Node) -> bool:
	return game.is_play_phase_for(owner) and owner.total_cards_in_hand_and_equipment() > 0


func validate_cost(cards: Array[Card], _game: Node, _owner: Node) -> bool:
	return not cards.is_empty()


func build_resolution_request(
	event_context: RefCounted,
	_game: Node,
	_owner: Node
) -> Dictionary:
	var use_context := event_context as SkillUseContext
	return {
		"action": &"discard_and_draw",
		"count": use_context.physical_cards.size(),
	}
