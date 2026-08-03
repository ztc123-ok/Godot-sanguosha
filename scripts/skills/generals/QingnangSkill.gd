class_name QingnangSkill
extends Skill
## 青囊：出牌阶段限一次，弃置一张手牌，令一名已受伤角色回复1点体力。

func _init() -> void:
	super(
		&"qingnang",
		"青囊",
		"出牌阶段限一次，你可以弃置一张手牌并选择一名已受伤角色，令其回复1点体力。",
		ActivationMode.ACTIVE,
		[],
		UsageScope.PER_TURN,
		1
	)

func can_activate(game: Node, owner: Node) -> bool:
	if not game.is_play_phase_for(owner) or owner.hand.is_empty():
		return false
	var target: BattlePlayer = game.other_player(owner)
	return owner.hp < owner.max_hp or target.hp < target.max_hp

func requires_target() -> bool: return true

func allows_self_target() -> bool: return true

func validate_target(target: Node, _cards: Array[Card], _game: Node, _owner: Node) -> bool:
	if target == null:
		return false
	var player: BattlePlayer = target as BattlePlayer
	return player.hp < player.max_hp

func validate_cost(cards: Array[Card], _game: Node, owner: Node) -> bool:
	if cards.size() != 1:
		return false
	return cards[0] in owner.hand

func allows_equipment_cost() -> bool: return false

func build_resolution_request(_event_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {"action": "qingnang"}
