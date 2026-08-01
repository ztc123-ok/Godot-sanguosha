class_name KurouSkill
extends Skill

func _init() -> void:
	super(&"kurou", "苦肉", "出牌阶段，你可以失去1点体力，然后摸两张牌。", ActivationMode.ACTIVE)

func requires_card_cost() -> bool: return false
func can_activate(game: Node, owner: Node) -> bool: return game.is_play_phase_for(owner) and owner.hp > 0
func validate_cost(cards: Array[Card], _game: Node, _owner: Node) -> bool: return cards.is_empty()
func build_resolution_request(_event_context: RefCounted, _game: Node, _owner: Node) -> Dictionary: return {"action": &"kurou"}
