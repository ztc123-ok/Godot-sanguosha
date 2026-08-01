class_name FanjianSkill
extends Skill

func _init() -> void:
	super(&"fanjian", "反间", "出牌阶段限一次，令对手选择一种花色并随机获得你的一张暗置手牌；花色不同则你对其造成1点伤害。", ActivationMode.ACTIVE, [], UsageScope.PER_TURN, 1)

func requires_card_cost() -> bool: return false
func can_activate(game: Node, owner: Node) -> bool: return game.is_play_phase_for(owner) and not owner.hand.is_empty()
func validate_cost(cards: Array[Card], _game: Node, _owner: Node) -> bool: return cards.is_empty()
func build_resolution_request(_event_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": &"fanjian"}
