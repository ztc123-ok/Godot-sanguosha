class_name RendeSkill
extends Skill

func _init() -> void:
	super(&"rende", "仁德", "出牌阶段，你可以将至少一张手牌交给对手；本阶段累计首次达到两张时尝试回复1点体力。", ActivationMode.ACTIVE)

func can_activate(game: Node, owner: Node) -> bool: return game.is_play_phase_for(owner) and not owner.hand.is_empty()
func requires_target() -> bool: return true
func validate_target(target: Node, _cards: Array[Card], _game: Node, owner: Node) -> bool:
	if target == null or target == owner:
		return false
	var player: BattlePlayer = target as BattlePlayer
	return not player.is_dying()
func validate_cost(cards: Array[Card], _game: Node, owner: Node) -> bool:
	if cards.is_empty(): return false
	for card: Card in cards:
		if card not in owner.hand: return false
	return true
func allows_equipment_cost() -> bool: return false
func build_resolution_request(_event_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": &"rende"}
