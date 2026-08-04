class_name LijianSkill
extends Skill
## 离间：出牌阶段限一次，弃置一张手牌或装备牌并选择两名男性角色，令其中一名视为对另一名使用【决斗】。
## 当前严格双人局中最多只有一名男性角色，因此没有合法目标组合，不可发动。

func _init() -> void:
	super(
		&"lijian",
		"离间",
		"出牌阶段限一次，你可以弃置一张手牌或装备牌并选择两名男性角色，令其中一名视为对另一名使用【决斗】。双人局中不足两名男性角色，因此不可发动。",
		ActivationMode.ACTIVE,
		[],
		UsageScope.PER_TURN,
		1
	)

func can_activate(game: Node, owner: Node) -> bool:
	if not game.is_play_phase_for(owner) or owner.total_cards_in_hand_and_equipment() < 1:
		return false
	## 双人局最多只有一名除貂蝉外的男性角色，无法选出两名不同男性。
	var male_count: int = 0
	for player: BattlePlayer in game.players:
		if player != owner and player.gender == GeneralDefinition.Gender.MALE:
			male_count += 1
	return male_count >= 2

func requires_target() -> bool: return true

func validate_target(_target: Node, _cards: Array[Card], _game: Node, _owner: Node) -> bool:
	## 单目标校验：男性且非使用者本人即可；两名目标的组合选择由 GameManager 分两步处理。
	if _target == null or _target == _owner:
		return false
	var player: BattlePlayer = _target as BattlePlayer
	return player.gender == GeneralDefinition.Gender.MALE and not player.is_dying()

func validate_cost(cards: Array[Card], _game: Node, owner: Node) -> bool:
	if cards.size() != 1:
		return false
	return cards[0] in owner.hand or cards[0] in owner.all_equipment()

func build_resolution_request(_event_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {"action": "lijian"}
