class_name JieyinSkill
extends Skill
## 结姻：出牌阶段限一次，弃置两张手牌并选择一名已受伤的男性角色，你和其各回复1点体力。

func _init() -> void:
	super(
		&"jieyin",
		"结姻",
		"出牌阶段限一次，你可以弃置两张手牌并选择一名已受伤的男性角色，然后你和该角色各回复1点体力。",
		ActivationMode.ACTIVE,
		[],
		UsageScope.PER_TURN,
		1
	)

func can_activate(game: Node, owner: Node) -> bool:
	if not game.is_play_phase_for(owner) or owner.hand.size() < 2:
		return false
	## 结姻可指定任意其他存活角色；多人局中目标不受阵营限制。
	for target: Node in game.living_players():
		if _target_valid(target, owner):
			return true
	return false

func _target_valid(target: Node, owner: Node) -> bool:
	if target == null or target == owner:
		return false
	var player: BattlePlayer = target as BattlePlayer
	return player.gender == GeneralDefinition.Gender.MALE and player.hp < player.max_hp

func requires_target() -> bool: return true

func validate_target(target: Node, cards: Array[Card], _game: Node, owner: Node) -> bool:
	return cards.size() == 2 and _target_valid(target, owner)

func validate_cost(cards: Array[Card], _game: Node, owner: Node) -> bool:
	if cards.size() != 2:
		return false
	for card: Card in cards:
		if card not in owner.hand:
			return false
	return true

func allows_equipment_cost() -> bool: return false

func build_resolution_request(_event_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {"action": "jieyin"}
