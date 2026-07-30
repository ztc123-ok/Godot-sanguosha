class_name GameManager
extends Node
## 双人局唯一规则入口。
## 所有主动牌、响应牌、锦囊、判定、伤害和濒死均经过本状态机结算。

const EquipmentScript = preload("res://scripts/cards/equipment/Equipment.gd")

signal state_changed
signal log_added(message: String)
signal match_finished(winner: BattlePlayer, loser: BattlePlayer)

enum Phase {
	START,
	JUDGEMENT,
	DRAW,
	PLAY,
	DISCARD,
	END,
}

enum FlowState {
	IDLE,
	PLAY_ACTIVE,
	SELECTING_TARGET,
	RESPONDING_SLASH,
	NULLIFICATION_RESPONSE,
	CHOOSING_OPTION,
	CHOOSING_REVEALED,
	AOE_RESPONSE,
	DUEL_RESPONSE,
	FIRE_REVEAL,
	FIRE_DISCARD,
	BORROW_RESPONSE,
	DYING_RESCUE,
	DISCARDING,
	GAME_OVER,
}

enum DamageNature {
	NORMAL,
	FIRE,
	THUNDER,
}

@onready var player1: BattlePlayer = $Players/Player1
@onready var player2: BattlePlayer = $Players/Player2

var players: Array[BattlePlayer] = []
var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []

var current_player_index: int = 0
var turn_number: int = 0
var phase: Phase = Phase.START
var flow_state: FlowState = FlowState.IDLE
var winner: BattlePlayer

var selected_hand_index: int = -1
var pending_attacker: BattlePlayer
var pending_target: BattlePlayer
var pending_damage: int = 0
var dying_player: BattlePlayer

var revealed_cards: Array[Card] = []
var choice_labels: Array[String] = []
var choice_owner: BattlePlayer

var _action_generation: int = 0
var _skip_draw_phase: bool = false
var _skip_play_phase: bool = false

## 普通【杀】/借刀【杀】上下文。
var _attack_after: Callable = Callable()
var _attack_nature: DamageNature = DamageNature.NORMAL
var _slash_ignores_armor: bool = false
var _ice_sword_checked: bool = false
var _bagua_attempted: bool = false
var _pending_weapon_skill: Card.CardType = Card.CardType.SLASH

## 通用伤害队列；属性伤害连环传播也走此队列。
var _damage_source: BattlePlayer
var _damage_amount: int = 0
var _damage_nature: DamageNature = DamageNature.NORMAL
var _damage_queue: Array[BattlePlayer] = []
var _damage_after: Callable = Callable()
var _damage_ignore_armor_for: BattlePlayer
var _dying_after: Callable = Callable()

## 无懈可击链上下文。
var _effect_card: Card
var _effect_source: BattlePlayer
var _effect_target: BattlePlayer
var _effect_apply: Callable = Callable()
var _effect_cancel: Callable = Callable()
var _effect_finish: Callable = Callable()
var _effect_harmful: bool = true
var _nullification_count: int = 0
var _nullification_passes: int = 0
var _nullification_responder_index: int = 0

## 通用选项上下文。
var _choice_handler: Callable = Callable()
var _zone_choice_codes: Array[String] = []

## 群体锦囊上下文。
var _global_card: Card
var _global_source: BattlePlayer
var _global_targets: Array[BattlePlayer] = []
var _global_index: int = 0

## AOE、决斗、火攻、借刀上下文。
var _response_card_type: Card.CardType = Card.CardType.SLASH
var _duel_responder: BattlePlayer
var _duel_other: BattlePlayer
var _fire_revealed_card: Card
var _fire_source: BattlePlayer
var _fire_target: BattlePlayer
var _borrow_source: BattlePlayer
var _borrow_target: BattlePlayer

## 五谷丰登选择上下文。
var _revealed_selecting_player: BattlePlayer

## 铁索连环逐目标结算。
var _chain_card: Card
var _chain_source: BattlePlayer
var _chain_targets: Array[BattlePlayer] = []
var _chain_index: int = 0

## 判定阶段上下文。
var _judgement_queue: Array[Card] = []
var _judgement_index: int = 0
var _judging_card: Card


func _ready() -> void:
	players = [player1, player2]
	call_deferred("start_match")


func start_match() -> void:
	_action_generation += 1
	draw_pile = CardFactory.create_basic_deck()
	discard_pile.clear()
	revealed_cards.clear()
	current_player_index = 0
	turn_number = 0
	winner = null
	selected_hand_index = -1
	pending_attacker = null
	pending_target = null
	dying_player = null
	flow_state = FlowState.IDLE

	for player: BattlePlayer in players:
		player.reset_for_match()
		draw_cards(player, 4)

	_add_log("游戏开始：主公 Player1 对阵反贼 Player2。")
	_add_log("双方各摸 4 张起始手牌，主公先手。")
	_begin_turn()


func current_player() -> BattlePlayer:
	return players[current_player_index]


func other_player(player: BattlePlayer) -> BattlePlayer:
	return player2 if player == player1 else player1


func two_player_action_order(starting_player: BattlePlayer) -> Array[BattlePlayer]:
	## 双人局的行动顺序固定从当前效果的起点开始，再轮到另一名角色。
	return [starting_player, other_player(starting_player)]


func player_index(player: BattlePlayer) -> int:
	return players.find(player)


func phase_text() -> String:
	match phase:
		Phase.START:
			return "开始阶段"
		Phase.JUDGEMENT:
			return "判定阶段"
		Phase.DRAW:
			return "摸牌阶段"
		Phase.PLAY:
			return "出牌阶段"
		Phase.DISCARD:
			return "弃牌阶段"
		Phase.END:
			return "结束阶段"
	return "未知阶段"


func prompt_text() -> String:
	if flow_state == FlowState.GAME_OVER:
		return "%s 获胜！点击“重新开始”再来一局。" % winner.player_name
	if flow_state == FlowState.SELECTING_TARGET:
		return "已选择【%s】——点击或拖到合法角色区域" % _selected_card_name()
	if flow_state == FlowState.RESPONDING_SLASH:
		return "%s 正被【杀】指定：使用【闪】或不响应" % pending_target.player_name
	if flow_state == FlowState.NULLIFICATION_RESPONSE:
		return "%s：可使用【无懈可击】或放弃响应（当前链数 %d）" % [
			players[_nullification_responder_index].player_name,
			_nullification_count,
		]
	if flow_state == FlowState.CHOOSING_OPTION:
		return "%s：请选择一项" % choice_owner.player_name
	if flow_state == FlowState.CHOOSING_REVEALED:
		return "%s 从【五谷丰登】亮出的牌中选择一张" % _revealed_selecting_player.player_name
	if flow_state == FlowState.AOE_RESPONSE:
		return "%s 需打出%s，否则受到 1 点伤害" % [
			pending_target.player_name,
			"【杀】" if _response_card_type == Card.CardType.SLASH else "【闪】",
		]
	if flow_state == FlowState.DUEL_RESPONSE:
		return "【决斗】：%s 需打出【杀】，否则受到 1 点伤害" % _duel_responder.player_name
	if flow_state == FlowState.FIRE_REVEAL:
		return "%s 请选择一张手牌展示" % _fire_target.player_name
	if flow_state == FlowState.FIRE_DISCARD:
		return "%s 可弃置一张%s牌发动【火攻】，或放弃" % [
			_fire_source.player_name,
			_fire_revealed_card.suit_text(),
		]
	if flow_state == FlowState.BORROW_RESPONSE:
		return "%s：对 %s 使用【杀】，否则交出武器" % [
			_borrow_target.player_name,
			_borrow_source.player_name,
		]
	if flow_state == FlowState.DYING_RESCUE:
		return "%s 濒死（体力 %d）：使用【桃】/【酒】直到体力回到 1" % [
			dying_player.player_name,
			dying_player.hp,
		]
	if flow_state == FlowState.DISCARDING:
		var excess: int = current_player().hand.size() - current_player().hand_limit()
		if excess > 0:
			return "弃牌阶段：还需弃置 %d 张牌（点击手牌弃置）" % excess
	if flow_state == FlowState.PLAY_ACTIVE:
		return "反贼正在思考……" if current_player().is_ai else "你的出牌阶段：点击卡牌使用，或拖到角色区域"
	return "%s · %s" % [current_player().player_name, phase_text()]


func is_play_phase_for(user: Node) -> bool:
	return (
		user == current_player()
		and phase == Phase.PLAY
		and flow_state in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]
	)


func can_play_trick(card: Card, user: Node) -> bool:
	if not is_play_phase_for(user):
		return false
	var owner: BattlePlayer = user as BattlePlayer
	var target: BattlePlayer = other_player(owner)
	match card.card_type:
		Card.CardType.NULLIFICATION:
			return false
		Card.CardType.DISMANTLE:
			return target.total_cards_in_hand_and_equipment() > 0
		Card.CardType.STEAL:
			return distance_between(owner, target) == 1 and not target.hand.is_empty()
		Card.CardType.BORROW_SWORD:
			return (
				distance_between(owner, target) == 1
				and target.weapon != null
				and can_slash_target(target, owner)
			)
		Card.CardType.FIRE_ATTACK:
			return not target.hand.is_empty() or not owner.hand.is_empty()
		Card.CardType.INDULGENCE, Card.CardType.SUPPLY_SHORTAGE:
			return not target.has_delayed_trick(card.card_type)
		Card.CardType.LIGHTNING:
			return not owner.has_delayed_trick(Card.CardType.LIGHTNING)
	return true


func can_equip(user: Node) -> bool:
	return is_play_phase_for(user)


func can_equip_weapon(user: Node) -> bool:
	## 兼容旧卡牌脚本调用；所有装备现在均走 can_equip。
	return can_equip(user)


func distance_between(source: BattlePlayer, target: BattlePlayer) -> int:
	if source == null or target == null or source == target:
		return 0
	var distance: int = 1
	if target.horse_plus != null:
		distance += 1
	if source.horse_minus != null:
		distance -= 1
	return maxi(distance, 1)


func attack_range(player: BattlePlayer) -> int:
	if player != null and player.weapon != null:
		return int(player.weapon.attack_range)
	return 1


func can_slash_target(source: BattlePlayer, target: BattlePlayer) -> bool:
	return (
		source != null
		and target != null
		and source != target
		and distance_between(source, target) <= attack_range(source)
	)


func can_use_slash_in_play(user: Node) -> bool:
	if not is_play_phase_for(user):
		return false
	var player: BattlePlayer = user as BattlePlayer
	var unlimited: bool = (
		player.weapon != null
		and player.weapon.card_type == Card.CardType.CROSSBOW
	)
	return (not player.slash_used_this_turn or unlimited) and can_slash_target(player, other_player(player))


func can_use_serpent_spear(player: BattlePlayer) -> bool:
	if player == null or player.weapon == null or player.weapon.card_type != Card.CardType.SERPENT_SPEAR:
		return false
	if player.hand.size() < 2:
		return false
	if is_play_phase_for(player):
		return can_use_slash_in_play(player)
	return is_waiting_for_slash_from(player)


func can_use_bagua(player: BattlePlayer) -> bool:
	if player == null or player.armor == null or player.armor.card_type != Card.CardType.EIGHT_TRIGRAMS:
		return false
	if not is_waiting_for_dodge_from(player):
		return false
	if _bagua_attempted:
		return false
	return not (
		flow_state == FlowState.RESPONDING_SLASH
		and _slash_ignores_armor
		and player == pending_target
	)


func is_waiting_for_dodge_from(user: Node) -> bool:
	return (
		(flow_state == FlowState.RESPONDING_SLASH and user == pending_target)
		or (
			flow_state == FlowState.AOE_RESPONSE
			and user == pending_target
			and _response_card_type == Card.CardType.DODGE
		)
	)


func is_waiting_for_slash_from(user: Node) -> bool:
	return (
		(flow_state == FlowState.AOE_RESPONSE and user == pending_target and _response_card_type == Card.CardType.SLASH)
		or (flow_state == FlowState.DUEL_RESPONSE and user == _duel_responder)
		or (flow_state == FlowState.BORROW_RESPONSE and user == _borrow_target)
	)


func is_waiting_for_nullification_from(user: Node) -> bool:
	return (
		flow_state == FlowState.NULLIFICATION_RESPONSE
		and user == players[_nullification_responder_index]
	)


func is_waiting_for_rescue_from(user: Node) -> bool:
	return flow_state == FlowState.DYING_RESCUE and user == dying_player


func request_card_use(hand_index: int) -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	if hand_index < 0 or hand_index >= player1.hand.size():
		return
	var card: Card = player1.hand[hand_index]

	match flow_state:
		FlowState.DISCARDING:
			request_discard(hand_index)
			return
		FlowState.NULLIFICATION_RESPONSE:
			if card.card_type == Card.CardType.NULLIFICATION:
				request_nullification()
			return
		FlowState.AOE_RESPONSE, FlowState.DUEL_RESPONSE, FlowState.BORROW_RESPONSE:
			if card.card_type == _response_card_type or (
				flow_state in [FlowState.DUEL_RESPONSE, FlowState.BORROW_RESPONSE]
				and card.card_type == Card.CardType.SLASH
			):
				request_response_card()
			return
		FlowState.RESPONDING_SLASH:
			if card.card_type == Card.CardType.DODGE:
				request_dodge()
			return
		FlowState.FIRE_REVEAL:
			request_fire_reveal(hand_index)
			return
		FlowState.FIRE_DISCARD:
			request_fire_discard(hand_index)
			return
		FlowState.DYING_RESCUE:
			if card.card_type in [Card.CardType.PEACH, Card.CardType.WINE]:
				request_rescue(card.card_type)
			return

	## 当前回合属于 AI 时，玩家仍可在上面的响应状态中点击手牌。
	## 只有主动出牌入口需要阻止玩家代替 AI 操作。
	if current_player().is_ai:
		return
	if phase != Phase.PLAY:
		_reject("当前不是出牌阶段。")
		return
	if flow_state == FlowState.SELECTING_TARGET:
		request_cancel_selection()
	if flow_state != FlowState.PLAY_ACTIVE:
		return
	_activate_play_card(player1, hand_index)


func request_card_on_target(hand_index: int, target_index: int) -> void:
	if flow_state == FlowState.GAME_OVER or current_player().is_ai:
		return
	if phase != Phase.PLAY or hand_index < 0 or hand_index >= player1.hand.size():
		return
	var card: Card = player1.hand[hand_index]
	var target: BattlePlayer = players[target_index]
	if card.card_type == Card.CardType.SLASH:
		if target == player1:
			_reject("【杀】必须指定对方。")
			return
		_play_slash(player1, target, hand_index)
	elif card.category == Card.CardCategory.EQUIPMENT and target == player1:
		_play_equipment(player1, hand_index)
	elif card.is_trick():
		if card.target_mode == Card.TargetMode.SELF and target == player1:
			_use_self_or_global_trick(player1, hand_index)
		elif _is_valid_trick_target(card, player1, target):
			_use_target_trick(player1, target, hand_index)
		else:
			_reject("该角色不是【%s】的合法目标。" % card.display_name)
	else:
		request_card_use(hand_index)


func request_target(target_index: int) -> void:
	if flow_state != FlowState.SELECTING_TARGET:
		return
	if selected_hand_index < 0 or selected_hand_index >= current_player().hand.size():
		request_cancel_selection()
		return
	var card: Card = current_player().hand[selected_hand_index]
	var target: BattlePlayer = players[target_index]
	if card.card_type == Card.CardType.SLASH:
		if target == current_player():
			_reject("【杀】必须指定对方。")
			return
		_play_slash(current_player(), target, selected_hand_index)
	elif _is_valid_trick_target(card, current_player(), target):
		_use_target_trick(current_player(), target, selected_hand_index)
	else:
		_reject("该角色不是【%s】的合法目标。" % card.display_name)


func request_cancel_selection() -> void:
	if flow_state != FlowState.SELECTING_TARGET:
		return
	selected_hand_index = -1
	flow_state = FlowState.PLAY_ACTIVE
	_emit_state()


func request_dodge() -> void:
	if flow_state == FlowState.RESPONDING_SLASH and not pending_target.is_ai:
		var index: int = pending_target.find_card(Card.CardType.DODGE)
		if index < 0:
			_reject("手牌中没有【闪】。")
			return
		_resolve_slash_dodge(index)
	elif (
		flow_state == FlowState.AOE_RESPONSE
		and _response_card_type == Card.CardType.DODGE
		and not pending_target.is_ai
	):
		request_response_card()


func request_pass_response() -> void:
	if flow_state == FlowState.RESPONDING_SLASH and not pending_target.is_ai:
		_add_log("%s 未使用【闪】。" % pending_target.player_name)
		_resolve_slash_damage()
	elif flow_state in [FlowState.AOE_RESPONSE, FlowState.DUEL_RESPONSE, FlowState.BORROW_RESPONSE]:
		if _current_response_player() != null and not _current_response_player().is_ai:
			_pass_current_response()


func request_bagua_judgement() -> void:
	var defender: BattlePlayer = _current_response_player()
	if defender == null or defender.is_ai or not can_use_bagua(defender):
		return
	_resolve_bagua_judgement(defender)


func request_serpent_spear() -> void:
	var user: BattlePlayer = current_player()
	if flow_state not in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]:
		user = _current_response_player()
	if user == null or user.is_ai or not can_use_serpent_spear(user):
		return
	_use_serpent_spear(user)


func request_response_card() -> void:
	match flow_state:
		FlowState.AOE_RESPONSE:
			var index: int = pending_target.find_card(_response_card_type)
			if index < 0:
				_reject("没有所需的响应牌。")
				return
			var response: Card = _consume_hand_card(pending_target, index)
			_add_log("%s 打出【%s】，响应成功。" % [pending_target.player_name, response.display_name])
			_finish_nullifiable_effect()
		FlowState.DUEL_RESPONSE:
			var duel_index: int = _duel_responder.find_card(Card.CardType.SLASH)
			if duel_index < 0:
				_reject("没有【杀】可用于决斗。")
				return
			_consume_hand_card(_duel_responder, duel_index)
			_add_log("%s 在【决斗】中打出【杀】。" % _duel_responder.player_name)
			var previous: BattlePlayer = _duel_responder
			_duel_responder = _duel_other
			_duel_other = previous
			flow_state = FlowState.DUEL_RESPONSE
			_emit_state()
			if _duel_responder.is_ai:
				_schedule("_perform_ai_response", 0.55)
		FlowState.BORROW_RESPONSE:
			_borrow_use_slash()


func request_nullification() -> void:
	if flow_state != FlowState.NULLIFICATION_RESPONSE:
		return
	var responder: BattlePlayer = players[_nullification_responder_index]
	if responder.is_ai:
		return
	var index: int = responder.find_card(Card.CardType.NULLIFICATION)
	if index < 0:
		_reject("手牌中没有【无懈可击】。")
		return
	_play_nullification(responder, index)


func request_pass_nullification() -> void:
	if flow_state != FlowState.NULLIFICATION_RESPONSE:
		return
	var responder: BattlePlayer = players[_nullification_responder_index]
	if responder.is_ai:
		return
	_pass_nullification(responder)


func request_option(option_index: int) -> void:
	if flow_state != FlowState.CHOOSING_OPTION or choice_owner == null or choice_owner.is_ai:
		return
	if option_index < 0 or option_index >= choice_labels.size():
		return
	var handler: Callable = _choice_handler
	choice_labels.clear()
	_choice_handler = Callable()
	handler.call(option_index)


func request_revealed_card(card_index: int) -> void:
	if (
		flow_state != FlowState.CHOOSING_REVEALED
		or _revealed_selecting_player == null
		or _revealed_selecting_player.is_ai
	):
		return
	_take_amazing_grace_card(card_index)


func request_fire_reveal(hand_index: int) -> void:
	if flow_state != FlowState.FIRE_REVEAL or _fire_target.is_ai:
		return
	if hand_index < 0 or hand_index >= _fire_target.hand.size():
		return
	_reveal_for_fire_attack(_fire_target.hand[hand_index])


func request_fire_discard(hand_index: int) -> void:
	if flow_state != FlowState.FIRE_DISCARD or _fire_source.is_ai:
		return
	if hand_index < 0 or hand_index >= _fire_source.hand.size():
		return
	var card: Card = _fire_source.hand[hand_index]
	if card.suit != _fire_revealed_card.suit:
		_reject("必须弃置与展示牌花色相同的牌。")
		return
	_consume_hand_card(_fire_source, hand_index)
	_add_log("%s 弃置%s，火攻成功。" % [_fire_source.player_name, card.identity_text()])
	_start_damage(
		_fire_source,
		_fire_target,
		1,
		DamageNature.FIRE,
		Callable(self, "_finish_nullifiable_effect")
	)


func request_pass_fire_discard() -> void:
	if flow_state == FlowState.FIRE_DISCARD and not _fire_source.is_ai:
		_add_log("%s 放弃弃置同花色牌，【火攻】未造成伤害。" % _fire_source.player_name)
		_finish_nullifiable_effect()


func request_rescue(card_type: Card.CardType) -> void:
	if flow_state != FlowState.DYING_RESCUE or dying_player.is_ai:
		return
	var card_index: int = dying_player.find_card(card_type)
	if card_index < 0:
		_reject("没有可用于自救的牌。")
		return
	_use_rescue_card(dying_player, card_index)


func request_give_up_rescue() -> void:
	if flow_state == FlowState.DYING_RESCUE and not dying_player.is_ai:
		_declare_death(dying_player)


func request_end_play_phase() -> void:
	if (
		flow_state not in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]
		or phase != Phase.PLAY
		or current_player().is_ai
	):
		return
	selected_hand_index = -1
	_enter_discard_phase()


func request_discard(hand_index: int) -> void:
	if flow_state != FlowState.DISCARDING or current_player().is_ai:
		return
	if current_player().hand.size() <= current_player().hand_limit():
		_finish_discard_phase()
		return
	var card: Card = current_player().remove_card_at(hand_index)
	if card == null:
		return
	discard_pile.append(card)
	_add_log("%s 弃置了%s。" % [current_player().player_name, card.identity_text()])
	if current_player().hand.size() <= current_player().hand_limit():
		_finish_discard_phase()
	else:
		_emit_state()


func draw_cards(player: BattlePlayer, count: int) -> void:
	for _index: int in count:
		var card: Card = _draw_one_from_pile()
		if card == null:
			return
		player.add_card(card)


func _activate_play_card(user: BattlePlayer, hand_index: int) -> void:
	var card: Card = user.hand[hand_index]
	match card.card_type:
		Card.CardType.SLASH:
			if not card.can_use_in_play(self, user):
				_reject("本回合已经使用过【杀】。")
				return
			_select_target(hand_index, card)
		Card.CardType.PEACH:
			if not card.can_use_in_play(self, user):
				_reject("体力已满，不能主动使用【桃】。")
				return
			_play_peach(user, hand_index)
		Card.CardType.WINE:
			if not card.can_use_in_play(self, user):
				_reject("本回合已有【酒】效果。")
				return
			_play_wine(user, hand_index)
		Card.CardType.DODGE, Card.CardType.NULLIFICATION:
			_reject("该牌只能在对应的响应时机使用。")
		Card.CardType.IRON_CHAIN:
			_begin_iron_chain_choice(user, hand_index)
		_:
			if card.category == Card.CardCategory.EQUIPMENT:
				_play_equipment(user, hand_index)
			elif not card.can_use_in_play(self, user):
				_reject("当前没有【%s】的合法目标。" % card.display_name)
			elif card.target_mode in [Card.TargetMode.SELF, Card.TargetMode.ALL]:
				_use_self_or_global_trick(user, hand_index)
			else:
				_select_target(hand_index, card)


func _select_target(hand_index: int, card: Card) -> void:
	selected_hand_index = hand_index
	flow_state = FlowState.SELECTING_TARGET
	_add_log("%s 选择【%s】，等待指定目标。" % [current_player().player_name, card.display_name])
	_emit_state()


func _is_valid_trick_target(card: Card, source: BattlePlayer, target: BattlePlayer) -> bool:
	match card.card_type:
		Card.CardType.DISMANTLE:
			return target != source and target.total_cards_in_hand_and_equipment() > 0
		Card.CardType.STEAL:
			return target != source and distance_between(source, target) == 1 and not target.hand.is_empty()
		Card.CardType.DUEL:
			return target != source
		Card.CardType.BORROW_SWORD:
			return (
				target != source
				and distance_between(source, target) == 1
				and target.weapon != null
				and can_slash_target(target, source)
			)
		Card.CardType.FIRE_ATTACK:
			return not target.hand.is_empty()
		Card.CardType.INDULGENCE, Card.CardType.SUPPLY_SHORTAGE:
			return target != source and not target.has_delayed_trick(card.card_type)
	return target != source


func _use_self_or_global_trick(user: BattlePlayer, hand_index: int) -> void:
	var card: Card = user.hand[hand_index]
	if card.card_type == Card.CardType.LIGHTNING:
		var delayed: Card = _take_hand_card(user, hand_index)
		_start_delayed_placement(delayed, user, user)
		return
	var used: Card = _consume_hand_card(user, hand_index)
	_add_log("%s 使用%s。" % [user.player_name, used.identity_text()])
	match used.card_type:
		Card.CardType.DRAW_TWO:
			_start_nullifiable_effect(
				used, user, user,
				Callable(self, "_apply_draw_two"),
				Callable(self, "_finish_nullifiable_effect"),
				Callable(self, "_return_to_play"),
				false
			)
		Card.CardType.AMAZING_GRACE, Card.CardType.PEACH_GARDEN, Card.CardType.BARBARIAN_INVASION, Card.CardType.ARROW_BARRAGE:
			_start_global_trick(used, user)


func _use_target_trick(user: BattlePlayer, target: BattlePlayer, hand_index: int) -> void:
	if hand_index < 0 or hand_index >= user.hand.size():
		return
	var card: Card = user.hand[hand_index]
	if not _is_valid_trick_target(card, user, target):
		_reject("目标已不再合法。")
		return
	selected_hand_index = -1
	if card.is_delayed_trick:
		var delayed: Card = _take_hand_card(user, hand_index)
		_start_delayed_placement(delayed, user, target)
		return
	var used: Card = _consume_hand_card(user, hand_index)
	_add_log("%s 对 %s 使用%s。" % [user.player_name, target.player_name, used.identity_text()])
	match used.card_type:
		Card.CardType.DISMANTLE:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_dismantle"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)
		Card.CardType.STEAL:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_steal"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)
		Card.CardType.DUEL:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_duel"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)
		Card.CardType.BORROW_SWORD:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_borrow_sword"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)
		Card.CardType.FIRE_ATTACK:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_fire_attack"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)


func _play_peach(user: BattlePlayer, hand_index: int) -> void:
	_consume_hand_card(user, hand_index)
	user.recover(1)
	_add_log("%s 使用【桃】，回复至 %d/%d。" % [user.player_name, user.hp, user.max_hp])
	_emit_state()


func _play_wine(user: BattlePlayer, hand_index: int) -> void:
	_consume_hand_card(user, hand_index)
	user.wine_active = true
	_add_log("%s 使用【酒】：本回合下一张【杀】伤害 +1。" % user.player_name)
	_emit_state()


func _play_equipment(user: BattlePlayer, hand_index: int) -> void:
	if not can_equip(user):
		return
	if (
		hand_index < 0
		or hand_index >= user.hand.size()
		or user.hand[hand_index].category != Card.CardCategory.EQUIPMENT
	):
		return
	var equipment: Card = _take_hand_card(user, hand_index)
	var replaced: Card = user.equip(equipment)
	if replaced != null:
		_lose_equipment(user, replaced, "被同类装备替换")
	_add_log("%s 装备【%s】到%s。" % [user.player_name, equipment.display_name, _equipment_slot_text(equipment.equipment_slot)])
	_emit_state()
	if user.is_ai:
		_schedule("_perform_ai_play", 0.45)


func _play_slash(attacker: BattlePlayer, target: BattlePlayer, hand_index: int) -> void:
	if attacker == target or not can_use_slash_in_play(attacker):
		_reject("现在不能使用【杀】。")
		return
	if not can_slash_target(attacker, target):
		_reject("目标距离为 %d，超出攻击范围 %d。" % [distance_between(attacker, target), attack_range(attacker)])
		return
	var card: Card = _consume_hand_card(attacker, hand_index)
	if card == null or card.card_type != Card.CardType.SLASH:
		return
	attacker.slash_used_this_turn = true
	selected_hand_index = -1
	var amount: int = 2 if attacker.wine_active else 1
	attacker.wine_active = false
	var nature: DamageNature = DamageNature.FIRE if _has_equipment(attacker, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
	_add_log("%s 对 %s 使用%s【杀】%s（距离 %d / 范围 %d）。" % [
		attacker.player_name,
		target.player_name,
		"火属性" if nature == DamageNature.FIRE else "",
		"（酒杀，伤害 2）" if amount == 2 else "",
		distance_between(attacker, target),
		attack_range(attacker),
	])
	_start_slash_response(attacker, target, amount, Callable(self, "_return_to_play"), nature)


func _start_slash_response(
	attacker: BattlePlayer,
	target: BattlePlayer,
	amount: int,
	after: Callable,
	nature: DamageNature = DamageNature.NORMAL
) -> void:
	pending_attacker = attacker
	pending_target = target
	pending_damage = amount
	_attack_after = after
	_attack_nature = nature
	_slash_ignores_armor = _has_equipment(attacker, Card.CardType.QINGGANG_SWORD)
	_ice_sword_checked = false
	_bagua_attempted = false
	if _slash_ignores_armor:
		_add_log("【青釭剑】锁定技：本次【杀】无视 %s 的防具。" % target.player_name)
	flow_state = FlowState.RESPONDING_SLASH
	_emit_state()
	if target.is_ai:
		_schedule("_perform_ai_response", 0.55)


func _resolve_slash_dodge(dodge_index: int) -> void:
	var defender: BattlePlayer = pending_target
	_consume_hand_card(defender, dodge_index)
	_add_log("%s 使用【闪】，抵消本次【杀】。" % defender.player_name)
	_handle_slash_dodged()


func _handle_slash_dodged() -> void:
	var attacker: BattlePlayer = pending_attacker
	if _has_equipment(attacker, Card.CardType.GREEN_DRAGON_BLADE) and _can_supply_slash(attacker):
		_pending_weapon_skill = Card.CardType.GREEN_DRAGON_BLADE
		_show_choices(attacker, ["发动【青龙偃月刀】继续出杀", "结束本次攻击"], Callable(self, "_resolve_after_dodge_weapon"))
		return
	if (
		_has_equipment(attacker, Card.CardType.ROCK_CLEAVING_AXE)
		and attacker.total_cards_in_hand_and_equipment() >= 2
	):
		_pending_weapon_skill = Card.CardType.ROCK_CLEAVING_AXE
		_show_choices(attacker, ["弃两张牌发动【贯石斧】", "结束本次攻击"], Callable(self, "_resolve_after_dodge_weapon"))
		return
	_add_log("本次【杀】被【闪】抵消。")
	_finish_attack()


func _resolve_after_dodge_weapon(option_index: int) -> void:
	if option_index != 0:
		_add_log("%s 放弃发动武器技能。" % pending_attacker.player_name)
		_finish_attack()
		return
	if _pending_weapon_skill == Card.CardType.GREEN_DRAGON_BLADE:
		_use_follow_up_slash()
	elif _pending_weapon_skill == Card.CardType.ROCK_CLEAVING_AXE:
		var discarded: Array[Card] = _discard_n_cards(pending_attacker, 2)
		if discarded.size() < 2:
			_add_log("可弃置牌不足，【贯石斧】发动失败。")
			_finish_attack()
			return
		_add_log("%s 弃置%s，发动【贯石斧】：【杀】依然命中。" % [
			pending_attacker.player_name,
			_card_list_text(discarded),
		])
		_resolve_slash_damage()


func _use_follow_up_slash() -> void:
	var attacker: BattlePlayer = pending_attacker
	var target: BattlePlayer = pending_target
	var after: Callable = _attack_after
	var slash_index: int = attacker.find_card(Card.CardType.SLASH)
	if slash_index >= 0:
		_consume_hand_card(attacker, slash_index)
	else:
		var paid: Array[Card] = _consume_serpent_spear_cost(attacker)
		if paid.size() < 2:
			_finish_attack()
			return
	_add_log("%s 发动【青龙偃月刀】，继续对 %s 使用【杀】。" % [attacker.player_name, target.player_name])
	var nature: DamageNature = DamageNature.FIRE if _has_equipment(attacker, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
	_start_slash_response(attacker, target, 1, after, nature)


func _resolve_slash_damage() -> void:
	if (
		not _ice_sword_checked
		and _has_equipment(pending_attacker, Card.CardType.ICE_SWORD)
		and pending_target.total_cards_in_hand_and_equipment() >= 2
	):
		_ice_sword_checked = true
		_show_choices(
			pending_attacker,
			["发动【寒冰剑】防止伤害并弃其两张牌", "正常造成伤害"],
			Callable(self, "_resolve_ice_sword_choice")
		)
		return
	var ignore_for: BattlePlayer = pending_target if _slash_ignores_armor else null
	_start_damage(
		pending_attacker,
		pending_target,
		pending_damage,
		_attack_nature,
		Callable(self, "_after_slash_damage"),
		ignore_for
	)


func _resolve_ice_sword_choice(option_index: int) -> void:
	if option_index == 0:
		var discarded: Array[Card] = _discard_n_cards(pending_target, 2)
		_add_log("%s 发动【寒冰剑】，防止本次伤害并弃置 %s 的%s。" % [
			pending_attacker.player_name,
			pending_target.player_name,
			_card_list_text(discarded),
		])
		_finish_attack()
	else:
		_resolve_slash_damage()


func _after_slash_damage() -> void:
	if (
		pending_attacker != null
		and pending_target != null
		and _has_equipment(pending_attacker, Card.CardType.QILIN_BOW)
		and (pending_target.horse_plus != null or pending_target.horse_minus != null)
	):
		var labels: Array[String] = []
		_zone_choice_codes.clear()
		if pending_target.horse_plus != null:
			labels.append("弃置其【+1马】")
			_zone_choice_codes.append("horse_plus")
		if pending_target.horse_minus != null:
			labels.append("弃置其【-1马】")
			_zone_choice_codes.append("horse_minus")
		labels.append("不发动【麒麟弓】")
		_zone_choice_codes.append("pass")
		_show_choices(pending_attacker, labels, Callable(self, "_resolve_qilin_bow_choice"))
		return
	_finish_attack()


func _resolve_qilin_bow_choice(option_index: int) -> void:
	if option_index >= 0 and option_index < _zone_choice_codes.size():
		var code: String = _zone_choice_codes[option_index]
		var slot: int
		if code == "horse_plus":
			slot = EquipmentScript.Slot.HORSE_PLUS
		elif code == "horse_minus":
			slot = EquipmentScript.Slot.HORSE_MINUS
		else:
			_add_log("%s 不发动【麒麟弓】。" % pending_attacker.player_name)
			_finish_attack()
			return
		var removed: Card = pending_target.remove_equipment(slot)
		if removed != null:
			_lose_equipment(pending_target, removed, "被【麒麟弓】弃置")
			_add_log("%s 发动【麒麟弓】，弃置 %s 的【%s】。" % [
				pending_attacker.player_name,
				pending_target.player_name,
				removed.display_name,
			])
	_finish_attack()


func _finish_attack() -> void:
	var after: Callable = _attack_after
	_clear_attack_context()
	_call_safe(after)


func _clear_attack_context() -> void:
	pending_attacker = null
	pending_target = null
	pending_damage = 0
	_attack_after = Callable()
	_attack_nature = DamageNature.NORMAL
	_slash_ignores_armor = false
	_ice_sword_checked = false
	_bagua_attempted = false


func _start_nullifiable_effect(
	card: Card,
	source: BattlePlayer,
	target: BattlePlayer,
	apply_callback: Callable,
	cancel_callback: Callable,
	finish_callback: Callable,
	harmful: bool
) -> void:
	_effect_card = card
	_effect_source = source
	_effect_target = target
	_effect_apply = apply_callback
	_effect_cancel = cancel_callback
	_effect_finish = finish_callback
	_effect_harmful = harmful
	_nullification_count = 0
	_nullification_passes = 0
	_nullification_responder_index = player_index(other_player(source))
	flow_state = FlowState.NULLIFICATION_RESPONSE
	_add_log("【%s】即将对 %s 生效，进入【无懈可击】响应链。" % [card.display_name, target.player_name])
	_emit_state()
	if players[_nullification_responder_index].is_ai:
		_schedule("_perform_ai_nullification", 0.5)


func _play_nullification(responder: BattlePlayer, hand_index: int) -> void:
	_consume_hand_card(responder, hand_index)
	_nullification_count += 1
	_nullification_passes = 0
	_add_log("%s 使用【无懈可击】（链数 %d）。" % [responder.player_name, _nullification_count])
	_nullification_responder_index = 1 - _nullification_responder_index
	flow_state = FlowState.NULLIFICATION_RESPONSE
	_emit_state()
	if players[_nullification_responder_index].is_ai:
		_schedule("_perform_ai_nullification", 0.45)


func _pass_nullification(responder: BattlePlayer) -> void:
	_add_log("%s 放弃使用【无懈可击】。" % responder.player_name)
	_nullification_passes += 1
	if _nullification_passes >= 2:
		_finalize_nullification_chain()
		return
	_nullification_responder_index = 1 - _nullification_responder_index
	flow_state = FlowState.NULLIFICATION_RESPONSE
	_emit_state()
	if players[_nullification_responder_index].is_ai:
		_schedule("_perform_ai_nullification", 0.35)


func _perform_ai_nullification() -> void:
	if flow_state != FlowState.NULLIFICATION_RESPONSE:
		return
	var responder: BattlePlayer = players[_nullification_responder_index]
	if not responder.is_ai:
		return
	var currently_enabled: bool = _nullification_count % 2 == 0
	var target_is_ai: bool = _effect_target == responder
	var desired_enabled: bool = target_is_ai != _effect_harmful
	var index: int = responder.find_card(Card.CardType.NULLIFICATION)
	if index >= 0 and currently_enabled != desired_enabled:
		_play_nullification(responder, index)
	else:
		_pass_nullification(responder)


func _finalize_nullification_chain() -> void:
	if _nullification_count % 2 == 0:
		_add_log("无懈链为偶数，【%s】对 %s 生效。" % [_effect_card.display_name, _effect_target.player_name])
		_call_safe(_effect_apply)
	else:
		_add_log("无懈链为奇数，【%s】对 %s 的效果被抵消。" % [_effect_card.display_name, _effect_target.player_name])
		_call_safe(_effect_cancel)


func _finish_nullifiable_effect() -> void:
	var finish: Callable = _effect_finish
	_effect_card = null
	_effect_source = null
	_effect_target = null
	_effect_apply = Callable()
	_effect_cancel = Callable()
	_effect_finish = Callable()
	_call_safe(finish)


func _apply_draw_two() -> void:
	draw_cards(_effect_target, 2)
	_add_log("%s 因【无中生有】摸两张牌。" % _effect_target.player_name)
	_finish_nullifiable_effect()


func _apply_dismantle() -> void:
	var target: BattlePlayer = _effect_target
	_zone_choice_codes.clear()
	var labels: Array[String] = []
	if not target.hand.is_empty():
		_zone_choice_codes.append("hand")
		labels.append("弃置其随机手牌")
	for entry: Dictionary in _equipment_choice_entries(target):
		_zone_choice_codes.append(entry["code"])
		labels.append("弃置%s【%s】" % [entry["slot_name"], (entry["card"] as Card).display_name])
	if labels.size() == 1:
		_resolve_dismantle_choice(0)
	else:
		_show_choices(_effect_source, labels, Callable(self, "_resolve_dismantle_choice"))


func _resolve_dismantle_choice(option_index: int) -> void:
	if option_index < 0 or option_index >= _zone_choice_codes.size():
		_finish_nullifiable_effect()
		return
	var code: String = _zone_choice_codes[option_index]
	if code == "hand" and not _effect_target.hand.is_empty():
		var index: int = randi_range(0, _effect_target.hand.size() - 1)
		var removed: Card = _effect_target.remove_card_at(index)
		discard_pile.append(removed)
		_add_log("%s 随机弃置了 %s 的一张手牌。" % [_effect_source.player_name, _effect_target.player_name])
	else:
		var slot: int = _slot_from_code(code)
		var equipment: Card = _effect_target.remove_equipment(slot)
		if equipment != null:
			_lose_equipment(_effect_target, equipment, "被【过河拆桥】弃置")
			_add_log("%s 弃置了 %s 的【%s】。" % [
				_effect_source.player_name,
				_effect_target.player_name,
				equipment.display_name,
			])
	_finish_nullifiable_effect()


func _apply_steal() -> void:
	if _effect_target.hand.is_empty():
		_add_log("目标已无手牌，【顺手牵羊】无可获得之牌。")
	else:
		var index: int = randi_range(0, _effect_target.hand.size() - 1)
		var stolen: Card = _effect_target.remove_card_at(index)
		_effect_source.add_card(stolen)
		_add_log("%s 从 %s 获得一张手牌。" % [_effect_source.player_name, _effect_target.player_name])
	_finish_nullifiable_effect()


func _apply_duel() -> void:
	_duel_responder = _effect_target
	_duel_other = _effect_source
	flow_state = FlowState.DUEL_RESPONSE
	_add_log("【决斗】开始，由 %s 先打出【杀】。" % _duel_responder.player_name)
	_emit_state()
	if _duel_responder.is_ai:
		_schedule("_perform_ai_response", 0.55)


func _apply_borrow_sword() -> void:
	_borrow_source = _effect_source
	_borrow_target = _effect_target
	if _borrow_target.weapon == null:
		_add_log("目标已失去武器，【借刀杀人】结束。")
		_finish_nullifiable_effect()
		return
	flow_state = FlowState.BORROW_RESPONSE
	_emit_state()
	if _borrow_target.is_ai:
		_schedule("_perform_ai_response", 0.55)
	else:
		var labels: Array[String] = []
		if _can_supply_slash(_borrow_target):
			labels.append("对使用者打出【杀】")
		labels.append("交出武器")
		_show_choices(_borrow_target, labels, Callable(self, "_resolve_borrow_choice"))


func _resolve_borrow_choice(option_index: int) -> void:
	if choice_labels.size() == 1 or option_index == 0:
		_borrow_use_slash()
	else:
		_borrow_give_weapon()


func _borrow_use_slash() -> void:
	var slash_index: int = _borrow_target.find_card(Card.CardType.SLASH)
	if slash_index < 0:
		if can_use_serpent_spear(_borrow_target):
			_use_serpent_spear(_borrow_target)
			return
		_borrow_give_weapon()
		return
	_consume_hand_card(_borrow_target, slash_index)
	_add_log("%s 响应【借刀杀人】，对 %s 使用【杀】。" % [_borrow_target.player_name, _borrow_source.player_name])
	var nature: DamageNature = DamageNature.FIRE if _has_equipment(_borrow_target, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
	_start_slash_response(_borrow_target, _borrow_source, 1, Callable(self, "_finish_nullifiable_effect"), nature)


func _borrow_give_weapon() -> void:
	var weapon: Card = _borrow_target.remove_equipment(EquipmentScript.Slot.WEAPON)
	if weapon != null:
		_borrow_source.add_card(weapon)
		_add_log("%s 未出【杀】，将武器【%s】交给 %s。" % [_borrow_target.player_name, weapon.display_name, _borrow_source.player_name])
	_finish_nullifiable_effect()


func _apply_fire_attack() -> void:
	_fire_source = _effect_source
	_fire_target = _effect_target
	if _fire_target.hand.is_empty():
		_add_log("%s 已无手牌，【火攻】结束。" % _fire_target.player_name)
		_finish_nullifiable_effect()
		return
	if _fire_target.is_ai:
		var index: int = randi_range(0, _fire_target.hand.size() - 1)
		_reveal_for_fire_attack(_fire_target.hand[index])
	else:
		flow_state = FlowState.FIRE_REVEAL
		_emit_state()


func _reveal_for_fire_attack(card: Card) -> void:
	_fire_revealed_card = card
	_add_log("%s 为【火攻】展示了%s。" % [_fire_target.player_name, card.identity_text()])
	if _fire_source.is_ai:
		flow_state = FlowState.FIRE_DISCARD
		_emit_state()
		_schedule("_perform_ai_fire_discard", 0.5)
	else:
		flow_state = FlowState.FIRE_DISCARD
		_emit_state()


func _perform_ai_fire_discard() -> void:
	if _fire_source == null or _fire_revealed_card == null:
		return
	for index: int in _fire_source.hand.size():
		if _fire_source.hand[index].suit == _fire_revealed_card.suit:
			var discarded: Card = _consume_hand_card(_fire_source, index)
			_add_log("%s 弃置%s，火攻成功。" % [_fire_source.player_name, discarded.identity_text()])
			_start_damage(_fire_source, _fire_target, 1, DamageNature.FIRE, Callable(self, "_finish_nullifiable_effect"))
			return
	_add_log("%s 没有同花色牌，【火攻】未造成伤害。" % _fire_source.player_name)
	_finish_nullifiable_effect()


func _start_global_trick(card: Card, source: BattlePlayer) -> void:
	_global_card = card
	_global_source = source
	_global_targets.clear()
	_global_index = 0
	match card.card_type:
		Card.CardType.BARBARIAN_INVASION, Card.CardType.ARROW_BARRAGE:
			_global_targets = [other_player(source)]
		Card.CardType.PEACH_GARDEN, Card.CardType.AMAZING_GRACE:
			_global_targets = two_player_action_order(source)
	if card.card_type == Card.CardType.AMAZING_GRACE:
		revealed_cards.clear()
		for _index: int in _global_targets.size():
			var revealed: Card = _draw_one_from_pile()
			if revealed != null:
				revealed_cards.append(revealed)
		_add_log("【五谷丰登】亮出：%s。" % _card_list_text(revealed_cards))
		_add_log("【五谷丰登】选择顺序：%s → %s（使用者优先）。" % [
			_global_targets[0].player_name,
			_global_targets[1].player_name,
		])
	_process_next_global_target()


func _process_next_global_target() -> void:
	if _global_index >= _global_targets.size():
		if _global_card != null and _global_card.card_type == Card.CardType.AMAZING_GRACE:
			for leftover: Card in revealed_cards:
				discard_pile.append(leftover)
			revealed_cards.clear()
		_global_card = null
		_global_source = null
		_global_targets.clear()
		_return_to_play()
		return
	var target: BattlePlayer = _global_targets[_global_index]
	_global_index += 1
	var harmful: bool = _global_card.card_type in [Card.CardType.BARBARIAN_INVASION, Card.CardType.ARROW_BARRAGE]
	var apply: Callable
	match _global_card.card_type:
		Card.CardType.BARBARIAN_INVASION:
			apply = Callable(self, "_apply_aoe").bind(Card.CardType.SLASH)
		Card.CardType.ARROW_BARRAGE:
			apply = Callable(self, "_apply_aoe").bind(Card.CardType.DODGE)
		Card.CardType.PEACH_GARDEN:
			apply = Callable(self, "_apply_peach_garden")
		Card.CardType.AMAZING_GRACE:
			apply = Callable(self, "_apply_amazing_grace")
	_start_nullifiable_effect(
		_global_card,
		_global_source,
		target,
		apply,
		Callable(self, "_finish_nullifiable_effect"),
		Callable(self, "_process_next_global_target"),
		harmful
	)


func _apply_aoe(required_type: Card.CardType) -> void:
	_response_card_type = required_type
	pending_target = _effect_target
	_bagua_attempted = false
	if _has_equipment(pending_target, Card.CardType.VINE_ARMOR):
		_add_log("【藤甲】锁定技：【%s】对 %s 无效。" % [_effect_card.display_name, pending_target.player_name])
		_finish_nullifiable_effect()
		return
	flow_state = FlowState.AOE_RESPONSE
	_emit_state()
	if pending_target.is_ai:
		_schedule("_perform_ai_response", 0.5)


func _resolve_bagua_judgement(defender: BattlePlayer) -> void:
	if not can_use_bagua(defender):
		return
	_bagua_attempted = true
	var judged: Card = _draw_one_from_pile()
	if judged == null:
		_add_log("牌堆无牌，【八卦阵】判定失败。")
		return
	discard_pile.append(judged)
	_add_log("%s 发动【八卦阵】，判定为%s（%s）。" % [
		defender.player_name,
		judged.identity_text(),
		"红色" if judged.is_red() else "黑色",
	])
	if judged.is_red():
		_add_log("【八卦阵】判定成功，视为 %s 打出【闪】。" % defender.player_name)
		if flow_state == FlowState.RESPONDING_SLASH:
			_handle_slash_dodged()
		elif flow_state == FlowState.AOE_RESPONSE:
			_finish_nullifiable_effect()
	else:
		_add_log("【八卦阵】判定失败，仍可从手牌打出【闪】。")
		_emit_state()
		if defender.is_ai:
			_schedule("_perform_ai_response", 0.35)


func _apply_peach_garden() -> void:
	var old_hp: int = _effect_target.hp
	_effect_target.recover(1)
	_add_log("%s 因【桃园结义】回复 %d 点体力。" % [_effect_target.player_name, _effect_target.hp - old_hp])
	_finish_nullifiable_effect()


func _apply_amazing_grace() -> void:
	if revealed_cards.is_empty():
		_finish_nullifiable_effect()
		return
	_revealed_selecting_player = _effect_target
	flow_state = FlowState.CHOOSING_REVEALED
	_emit_state()
	if _revealed_selecting_player.is_ai:
		_schedule("_perform_ai_amazing_grace", 0.45)


func _perform_ai_amazing_grace() -> void:
	if revealed_cards.is_empty():
		_finish_nullifiable_effect()
		return
	var best_index: int = 0
	var best_score: int = -999
	for index: int in revealed_cards.size():
		var score: int = _ai_card_value(revealed_cards[index])
		if score > best_score:
			best_score = score
			best_index = index
	_take_amazing_grace_card(best_index)


func _take_amazing_grace_card(card_index: int) -> void:
	if card_index < 0 or card_index >= revealed_cards.size():
		return
	var chosen: Card = revealed_cards.pop_at(card_index)
	_revealed_selecting_player.add_card(chosen)
	_add_log("%s 从【五谷丰登】获得%s。" % [_revealed_selecting_player.player_name, chosen.identity_text()])
	_revealed_selecting_player = null
	_finish_nullifiable_effect()


func _begin_iron_chain_choice(user: BattlePlayer, hand_index: int) -> void:
	selected_hand_index = hand_index
	choice_labels = ["切换自己连环", "切换对手连环", "切换双方连环", "重铸（摸一张）"]
	choice_owner = user
	_choice_handler = Callable(self, "_resolve_iron_chain_choice")
	flow_state = FlowState.CHOOSING_OPTION
	_emit_state()


func _resolve_iron_chain_choice(option_index: int) -> void:
	var user: BattlePlayer = current_player()
	if selected_hand_index < 0 or selected_hand_index >= user.hand.size():
		_return_to_play()
		return
	var card: Card = _consume_hand_card(user, selected_hand_index)
	selected_hand_index = -1
	if option_index == 3:
		draw_cards(user, 1)
		_add_log("%s 重铸【铁索连环】，摸一张牌。" % user.player_name)
		_return_to_play()
		return
	var targets: Array[BattlePlayer] = []
	match option_index:
		0:
			targets = [user]
		1:
			targets = [other_player(user)]
		2:
			targets = [user, other_player(user)]
	_start_iron_chain(card, user, targets)


func _start_iron_chain(card: Card, source: BattlePlayer, targets: Array[BattlePlayer]) -> void:
	_chain_card = card
	_chain_source = source
	_chain_targets = targets
	_chain_index = 0
	_add_log("%s 使用【铁索连环】，指定 %d 名角色。" % [source.player_name, targets.size()])
	_process_next_chain_target()


func _process_next_chain_target() -> void:
	if _chain_index >= _chain_targets.size():
		_chain_card = null
		_chain_source = null
		_chain_targets.clear()
		_return_to_play()
		return
	var target: BattlePlayer = _chain_targets[_chain_index]
	_chain_index += 1
	_start_nullifiable_effect(
		_chain_card,
		_chain_source,
		target,
		Callable(self, "_apply_chain_toggle"),
		Callable(self, "_finish_nullifiable_effect"),
		Callable(self, "_process_next_chain_target"),
		not target.chained
	)


func _apply_chain_toggle() -> void:
	_effect_target.chained = not _effect_target.chained
	_add_log("%s 的连环状态变为：%s。" % [_effect_target.player_name, "横置" if _effect_target.chained else "重置"])
	_finish_nullifiable_effect()


func _start_delayed_placement(card: Card, source: BattlePlayer, target: BattlePlayer) -> void:
	_add_log("%s 对 %s 使用延时锦囊%s。" % [source.player_name, target.player_name, card.identity_text()])
	_effect_card = card
	_start_nullifiable_effect(
		card,
		source,
		target,
		Callable(self, "_apply_delayed_placement"),
		Callable(self, "_cancel_delayed_placement"),
		Callable(self, "_return_to_play"),
		true
	)


func _apply_delayed_placement() -> void:
	var card: Card = _effect_card
	if _effect_target.add_delayed_trick(card):
		_add_log("【%s】置入 %s 的判定区。" % [card.display_name, _effect_target.player_name])
	else:
		discard_pile.append(card)
		_add_log("判定区已有同名牌，【%s】进入弃牌堆。" % card.display_name)
	_finish_nullifiable_effect()


func _cancel_delayed_placement() -> void:
	discard_pile.append(_effect_card)
	_finish_nullifiable_effect()


func _show_choices(owner: BattlePlayer, labels: Array[String], handler: Callable) -> void:
	choice_owner = owner
	choice_labels = labels
	_choice_handler = handler
	flow_state = FlowState.CHOOSING_OPTION
	_emit_state()
	if owner.is_ai:
		_schedule("_perform_ai_choice", 0.4)


func _perform_ai_choice() -> void:
	if flow_state != FlowState.CHOOSING_OPTION or choice_owner == null or not choice_owner.is_ai:
		return
	var handler: Callable = _choice_handler
	choice_labels.clear()
	_choice_handler = Callable()
	handler.call(0)


func _begin_turn() -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	turn_number += 1
	var active: BattlePlayer = current_player()
	active.reset_turn_flags()
	_skip_draw_phase = false
	_skip_play_phase = false

	phase = Phase.START
	flow_state = FlowState.IDLE
	_add_log("—— 第 %d 回合：%s 的回合 ——" % [turn_number, active.player_name])
	_add_log("开始阶段。")
	_emit_state()
	_begin_judgement_phase()


func _begin_judgement_phase() -> void:
	phase = Phase.JUDGEMENT
	_judgement_queue = current_player().delayed_tricks_in_judgement_order()
	_judgement_index = 0
	if _judgement_queue.is_empty():
		_add_log("判定阶段：判定区为空。")
		_finish_judgement_phase()
	else:
		_add_log("判定阶段：共有 %d 张延时锦囊待结算。" % _judgement_queue.size())
		_process_next_judgement()


func _process_next_judgement() -> void:
	if _judgement_index >= _judgement_queue.size():
		_finish_judgement_phase()
		return
	_judging_card = _judgement_queue[_judgement_index]
	_judgement_index += 1
	if not current_player().has_delayed_trick(_judging_card.card_type):
		_process_next_judgement()
		return
	_start_nullifiable_effect(
		_judging_card,
		current_player(),
		current_player(),
		Callable(self, "_perform_judgement"),
		Callable(self, "_cancel_delayed_judgement"),
		Callable(self, "_process_next_judgement"),
		true
	)


func _perform_judgement() -> void:
	var judged_card: Card = current_player().remove_delayed_trick(_judging_card.card_type)
	var result: Card = _draw_one_from_pile()
	if result == null:
		discard_pile.append(judged_card)
		_finish_nullifiable_effect()
		return
	discard_pile.append(result)
	_add_log("【%s】判定牌为%s。" % [judged_card.display_name, result.identity_text()])
	match judged_card.card_type:
		Card.CardType.INDULGENCE:
			discard_pile.append(judged_card)
			if result.suit != Card.Suit.HEART:
				_skip_play_phase = true
				_add_log("判定不为红桃：%s 跳过出牌阶段。" % current_player().player_name)
			else:
				_add_log("判定为红桃：【乐不思蜀】未生效。")
			_finish_nullifiable_effect()
		Card.CardType.SUPPLY_SHORTAGE:
			discard_pile.append(judged_card)
			if result.suit != Card.Suit.CLUB:
				_skip_draw_phase = true
				_add_log("判定不为梅花：%s 跳过摸牌阶段。" % current_player().player_name)
			else:
				_add_log("判定为梅花：【兵粮寸断】未生效。")
			_finish_nullifiable_effect()
		Card.CardType.LIGHTNING:
			if result.suit == Card.Suit.SPADE and result.rank >= 2 and result.rank <= 9:
				discard_pile.append(judged_card)
				_add_log("黑桃 2~9：【闪电】命中！")
				_start_damage(
					null,
					current_player(),
					3,
					DamageNature.THUNDER,
					Callable(self, "_finish_nullifiable_effect")
				)
			else:
				_pass_lightning(judged_card)
				_finish_nullifiable_effect()


func _cancel_delayed_judgement() -> void:
	var card: Card = current_player().remove_delayed_trick(_judging_card.card_type)
	if card != null and card.card_type == Card.CardType.LIGHTNING:
		_pass_lightning(card)
	elif card != null:
		discard_pile.append(card)
	_add_log("【%s】本次判定效果被【无懈可击】抵消。" % _judging_card.display_name)
	_finish_nullifiable_effect()


func _pass_lightning(card: Card) -> void:
	var next: BattlePlayer = other_player(current_player())
	if not next.has_delayed_trick(Card.CardType.LIGHTNING):
		next.add_delayed_trick(card)
		_add_log("【闪电】未命中，传递到 %s 的判定区。" % next.player_name)
	else:
		discard_pile.append(card)
		_add_log("下一名角色已有【闪电】，此【闪电】进入弃牌堆。")


func _finish_judgement_phase() -> void:
	phase = Phase.DRAW
	if _skip_draw_phase:
		_add_log("摸牌阶段被【兵粮寸断】跳过。")
	else:
		draw_cards(current_player(), 2)
		_add_log("摸牌阶段：%s 摸两张牌。" % current_player().player_name)
	phase = Phase.PLAY
	if _skip_play_phase:
		_add_log("出牌阶段被【乐不思蜀】跳过。")
		_enter_discard_phase()
		return
	flow_state = FlowState.PLAY_ACTIVE
	_add_log("进入出牌阶段。")
	_emit_state()
	if current_player().is_ai:
		_schedule("_perform_ai_play", 0.6)


func _start_damage(
	source: BattlePlayer,
	target: BattlePlayer,
	amount: int,
	nature: DamageNature,
	after: Callable,
	ignore_armor_for: BattlePlayer = null
) -> void:
	_damage_source = source
	_damage_amount = amount
	_damage_nature = nature
	_damage_after = after
	_damage_ignore_armor_for = ignore_armor_for
	_damage_queue.clear()
	if nature != DamageNature.NORMAL and target.chained:
		_damage_queue.append(target)
		for player: BattlePlayer in players:
			if player != target and player.chained:
				_damage_queue.append(player)
		for player: BattlePlayer in _damage_queue:
			player.chained = false
		_add_log("%s属性伤害触发铁索连环，所有横置角色重置并依次传导。" % _nature_text(nature))
	else:
		_damage_queue.append(target)
	_process_damage_queue()


func _process_damage_queue() -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	if _damage_queue.is_empty():
		var after: Callable = _damage_after
		_damage_after = Callable()
		_damage_ignore_armor_for = null
		_call_safe(after)
		return
	var target: BattlePlayer = _damage_queue.pop_front()
	var actual_amount: int = _damage_amount
	var armor_ignored: bool = target == _damage_ignore_armor_for
	if not armor_ignored and _has_equipment(target, Card.CardType.VINE_ARMOR) and _damage_nature == DamageNature.FIRE:
		actual_amount += 1
		_add_log("【藤甲】锁定技：%s 受到的火焰伤害 +1。" % target.player_name)
	if not armor_ignored and _has_equipment(target, Card.CardType.SILVER_LION) and actual_amount > 1:
		_add_log("【白银狮子】锁定技：%s 本次伤害由 %d 限制为 1。" % [target.player_name, actual_amount])
		actual_amount = 1
	target.take_damage(actual_amount)
	_add_log("%s 受到 %d 点%s伤害，当前体力 %d/%d。" % [
		target.player_name,
		actual_amount,
		_nature_text(_damage_nature),
		target.hp,
		target.max_hp,
	])
	_emit_state()
	if target.is_dying():
		_enter_dying(target, Callable(self, "_process_damage_queue"))
	else:
		_process_damage_queue()


func _enter_dying(player: BattlePlayer, after: Callable) -> void:
	dying_player = player
	_dying_after = after
	flow_state = FlowState.DYING_RESCUE
	_add_log("%s 进入濒死状态，需要将体力回复至 1。" % player.player_name)
	_emit_state()
	if player.is_ai:
		_schedule("_perform_ai_rescue", 0.6)


func _perform_ai_rescue() -> void:
	if flow_state != FlowState.DYING_RESCUE or not dying_player.is_ai:
		return
	var index: int = dying_player.find_card(Card.CardType.PEACH)
	if index < 0:
		index = dying_player.find_card(Card.CardType.WINE)
	if index >= 0:
		_use_rescue_card(dying_player, index)
	else:
		_add_log("%s 没有【桃】或【酒】，无法自救。" % dying_player.player_name)
		_declare_death(dying_player)


func _use_rescue_card(player: BattlePlayer, hand_index: int) -> void:
	var card: Card = _consume_hand_card(player, hand_index)
	player.recover(1)
	_add_log("%s 濒死时使用【%s】，体力回复至 %d。" % [player.player_name, card.display_name, player.hp])
	if player.is_dying():
		_emit_state()
		if player.is_ai:
			_schedule("_perform_ai_rescue", 0.45)
	else:
		_add_log("%s 脱离濒死状态。" % player.player_name)
		dying_player = null
		var after: Callable = _dying_after
		_dying_after = Callable()
		_call_safe(after)


func _declare_death(loser: BattlePlayer) -> void:
	winner = other_player(loser)
	flow_state = FlowState.GAME_OVER
	_action_generation += 1
	_add_log("%s 阵亡。%s（%s）获胜！" % [loser.player_name, winner.player_name, winner.role_name])
	_emit_state()
	match_finished.emit(winner, loser)


func _perform_ai_response() -> void:
	match flow_state:
		FlowState.RESPONDING_SLASH:
			var dodge_index: int = pending_target.find_card(Card.CardType.DODGE)
			if dodge_index >= 0:
				_resolve_slash_dodge(dodge_index)
			elif can_use_bagua(pending_target):
				_resolve_bagua_judgement(pending_target)
			else:
				_add_log("%s 没有【闪】。" % pending_target.player_name)
				_resolve_slash_damage()
		FlowState.AOE_RESPONSE:
			var aoe_index: int = pending_target.find_card(_response_card_type)
			if aoe_index >= 0:
				request_response_card()
			elif _response_card_type == Card.CardType.DODGE and can_use_bagua(pending_target):
				_resolve_bagua_judgement(pending_target)
			elif _response_card_type == Card.CardType.SLASH and can_use_serpent_spear(pending_target):
				_use_serpent_spear(pending_target)
			else:
				_pass_current_response()
		FlowState.DUEL_RESPONSE:
			if _duel_responder.find_card(Card.CardType.SLASH) >= 0:
				request_response_card()
			elif can_use_serpent_spear(_duel_responder):
				_use_serpent_spear(_duel_responder)
			else:
				_pass_current_response()
		FlowState.BORROW_RESPONSE:
			if _can_supply_slash(_borrow_target):
				_borrow_use_slash()
			else:
				_borrow_give_weapon()


func _pass_current_response() -> void:
	match flow_state:
		FlowState.AOE_RESPONSE:
			var target: BattlePlayer = pending_target
			_add_log("%s 未打出所需响应牌。" % target.player_name)
			_start_damage(_global_source, target, 1, DamageNature.NORMAL, Callable(self, "_finish_nullifiable_effect"))
		FlowState.DUEL_RESPONSE:
			var loser: BattlePlayer = _duel_responder
			var source: BattlePlayer = _duel_other
			_add_log("%s 未在【决斗】中打出【杀】。" % loser.player_name)
			_start_damage(source, loser, 1, DamageNature.NORMAL, Callable(self, "_finish_nullifiable_effect"))
		FlowState.BORROW_RESPONSE:
			_borrow_give_weapon()


func _current_response_player() -> BattlePlayer:
	match flow_state:
		FlowState.AOE_RESPONSE, FlowState.RESPONDING_SLASH:
			return pending_target
		FlowState.DUEL_RESPONSE:
			return _duel_responder
		FlowState.BORROW_RESPONSE:
			return _borrow_target
	return null


func _perform_ai_play() -> void:
	if flow_state != FlowState.PLAY_ACTIVE or phase != Phase.PLAY or not current_player().is_ai:
		return
	var ai: BattlePlayer = current_player()
	var enemy: BattlePlayer = other_player(ai)

	if ai.hp < ai.max_hp:
		var peach_index: int = ai.find_card(Card.CardType.PEACH)
		if peach_index >= 0:
			_play_peach(ai, peach_index)
			_schedule("_perform_ai_play", 0.4)
			return

	var equipment_index: int = _find_equipment_in_hand(ai)
	if equipment_index >= 0:
		_play_equipment(ai, equipment_index)
		return

	var self_tricks: Array[Card.CardType] = [Card.CardType.DRAW_TWO, Card.CardType.AMAZING_GRACE]
	for type: Card.CardType in self_tricks:
		var self_index: int = ai.find_card(type)
		if self_index >= 0:
			_use_self_or_global_trick(ai, self_index)
			return

	if ai.hp < ai.max_hp:
		var garden_index: int = ai.find_card(Card.CardType.PEACH_GARDEN)
		if garden_index >= 0:
			_use_self_or_global_trick(ai, garden_index)
			return

	var harmful_types: Array[Card.CardType] = [
		Card.CardType.DISMANTLE,
		Card.CardType.STEAL,
		Card.CardType.BORROW_SWORD,
		Card.CardType.INDULGENCE,
		Card.CardType.SUPPLY_SHORTAGE,
		Card.CardType.FIRE_ATTACK,
		Card.CardType.DUEL,
	]
	for type: Card.CardType in harmful_types:
		var index: int = ai.find_card(type)
		if index >= 0 and _is_valid_trick_target(ai.hand[index], ai, enemy):
			_use_target_trick(ai, enemy, index)
			return

	var aoe_types: Array[Card.CardType] = [Card.CardType.BARBARIAN_INVASION, Card.CardType.ARROW_BARRAGE]
	for type: Card.CardType in aoe_types:
		var aoe_index: int = ai.find_card(type)
		if aoe_index >= 0:
			_use_self_or_global_trick(ai, aoe_index)
			return

	var lightning_index: int = ai.find_card(Card.CardType.LIGHTNING)
	if lightning_index >= 0 and not ai.has_delayed_trick(Card.CardType.LIGHTNING):
		_use_self_or_global_trick(ai, lightning_index)
		return

	var chain_index: int = ai.find_card(Card.CardType.IRON_CHAIN)
	if chain_index >= 0:
		var chain_card: Card = _consume_hand_card(ai, chain_index)
		if not enemy.chained:
			_start_iron_chain(chain_card, ai, [enemy])
		else:
			draw_cards(ai, 1)
			_add_log("%s 重铸【铁索连环】，摸一张牌。" % ai.player_name)
			_schedule("_perform_ai_play", 0.4)
		return

	var slash_index: int = ai.find_card(Card.CardType.SLASH)
	if slash_index >= 0 and can_use_slash_in_play(ai):
		var wine_index: int = ai.find_card(Card.CardType.WINE)
		if wine_index >= 0 and not ai.wine_active:
			_play_wine(ai, wine_index)
			_schedule("_perform_ai_play", 0.4)
			return
		_play_slash(ai, enemy, slash_index)
		return
	if can_use_serpent_spear(ai):
		_use_serpent_spear(ai)
		return
	_enter_discard_phase()


func _return_to_play() -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	flow_state = FlowState.PLAY_ACTIVE
	selected_hand_index = -1
	choice_labels.clear()
	choice_owner = null
	_emit_state()
	if current_player().is_ai:
		_schedule("_perform_ai_play", 0.5)


func _enter_discard_phase() -> void:
	phase = Phase.DISCARD
	flow_state = FlowState.DISCARDING
	_add_log("进入弃牌阶段：手牌上限等于当前体力。")
	_emit_state()
	if current_player().hand.size() <= current_player().hand_limit():
		_schedule("_finish_discard_phase", 0.3)
	elif current_player().is_ai:
		_schedule("_perform_ai_discard", 0.45)


func _perform_ai_discard() -> void:
	if flow_state != FlowState.DISCARDING or not current_player().is_ai:
		return
	while current_player().hand.size() > current_player().hand_limit():
		var card: Card = current_player().remove_card_at(current_player().hand.size() - 1)
		discard_pile.append(card)
		_add_log("%s 弃置一张牌。" % current_player().player_name)
	_finish_discard_phase()


func _finish_discard_phase() -> void:
	if flow_state != FlowState.DISCARDING:
		return
	phase = Phase.END
	flow_state = FlowState.IDLE
	current_player().wine_active = false
	_add_log("结束阶段。")
	_emit_state()
	current_player_index = 1 - current_player_index
	_schedule("_begin_turn", 0.6)


func _take_hand_card(player: BattlePlayer, hand_index: int) -> Card:
	return player.remove_card_at(hand_index)


func _consume_hand_card(player: BattlePlayer, hand_index: int) -> Card:
	var card: Card = _take_hand_card(player, hand_index)
	if card != null:
		discard_pile.append(card)
	return card


func _has_equipment(player: BattlePlayer, card_type: Card.CardType) -> bool:
	if player == null:
		return false
	for equipment: Card in player.all_equipment():
		if equipment.card_type == card_type:
			return true
	return false


func _find_equipment_in_hand(player: BattlePlayer) -> int:
	for index: int in player.hand.size():
		if player.hand[index].category == Card.CardCategory.EQUIPMENT:
			return index
	return -1


func _equipment_slot_text(slot: int) -> String:
	match slot:
		EquipmentScript.Slot.WEAPON:
			return "武器区"
		EquipmentScript.Slot.ARMOR:
			return "防具区"
		EquipmentScript.Slot.HORSE_PLUS:
			return "+1马区"
		EquipmentScript.Slot.HORSE_MINUS:
			return "-1马区"
	return "装备区"


func _equipment_choice_entries(player: BattlePlayer) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if player.weapon != null:
		entries.append({"code": "weapon", "slot_name": "武器", "card": player.weapon})
	if player.armor != null:
		entries.append({"code": "armor", "slot_name": "防具", "card": player.armor})
	if player.horse_plus != null:
		entries.append({"code": "horse_plus", "slot_name": "+1马", "card": player.horse_plus})
	if player.horse_minus != null:
		entries.append({"code": "horse_minus", "slot_name": "-1马", "card": player.horse_minus})
	return entries


func _slot_from_code(code: String) -> int:
	match code:
		"armor":
			return EquipmentScript.Slot.ARMOR
		"horse_plus":
			return EquipmentScript.Slot.HORSE_PLUS
		"horse_minus":
			return EquipmentScript.Slot.HORSE_MINUS
	return EquipmentScript.Slot.WEAPON


func _lose_equipment(owner: BattlePlayer, equipment: Card, reason: String) -> void:
	if equipment == null:
		return
	discard_pile.append(equipment)
	_add_log("%s 的【%s】%s，进入弃牌堆。" % [owner.player_name, equipment.display_name, reason])
	if equipment.card_type == Card.CardType.SILVER_LION and owner.hp < owner.max_hp:
		owner.recover(1)
		_add_log("【白银狮子】离开装备区，%s 回复1点体力至 %d/%d。" % [
			owner.player_name,
			owner.hp,
			owner.max_hp,
		])


func _discard_n_cards(player: BattlePlayer, count: int) -> Array[Card]:
	var discarded: Array[Card] = []
	while discarded.size() < count and not player.hand.is_empty():
		var hand_card: Card = player.remove_card_at(player.hand.size() - 1)
		discard_pile.append(hand_card)
		discarded.append(hand_card)
	var slot_order: Array[int] = [
		EquipmentScript.Slot.HORSE_PLUS,
		EquipmentScript.Slot.HORSE_MINUS,
		EquipmentScript.Slot.ARMOR,
		EquipmentScript.Slot.WEAPON,
	]
	for slot: int in slot_order:
		if discarded.size() >= count:
			break
		var equipment: Card = player.remove_equipment(slot)
		if equipment != null:
			_lose_equipment(player, equipment, "被弃置")
			discarded.append(equipment)
	return discarded


func _can_supply_slash(player: BattlePlayer) -> bool:
	return player.find_card(Card.CardType.SLASH) >= 0 or (
		_has_equipment(player, Card.CardType.SERPENT_SPEAR)
		and player.hand.size() >= 2
	)


func _consume_serpent_spear_cost(player: BattlePlayer) -> Array[Card]:
	var paid: Array[Card] = []
	for _index: int in 2:
		if player.hand.is_empty():
			break
		var card: Card = _consume_hand_card(player, player.hand.size() - 1)
		if card != null:
			paid.append(card)
	return paid


func _use_serpent_spear(user: BattlePlayer) -> void:
	if not can_use_serpent_spear(user):
		return
	var paid: Array[Card] = _consume_serpent_spear_cost(user)
	if paid.size() < 2:
		return
	_add_log("%s 弃置%s，发动【丈八蛇矛】视为使用/打出【杀】。" % [
		user.player_name,
		_card_list_text(paid),
	])
	if is_play_phase_for(user):
		var target: BattlePlayer = other_player(user)
		user.slash_used_this_turn = true
		var amount: int = 2 if user.wine_active else 1
		user.wine_active = false
		var nature: DamageNature = DamageNature.FIRE if _has_equipment(user, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
		_start_slash_response(user, target, amount, Callable(self, "_return_to_play"), nature)
		return
	match flow_state:
		FlowState.AOE_RESPONSE:
			_finish_nullifiable_effect()
		FlowState.DUEL_RESPONSE:
			var previous: BattlePlayer = _duel_responder
			_duel_responder = _duel_other
			_duel_other = previous
			flow_state = FlowState.DUEL_RESPONSE
			_emit_state()
			if _duel_responder.is_ai:
				_schedule("_perform_ai_response", 0.45)
		FlowState.BORROW_RESPONSE:
			_add_log("%s 以【丈八蛇矛】响应【借刀杀人】，对 %s 使用【杀】。" % [
				_borrow_target.player_name,
				_borrow_source.player_name,
			])
			_start_slash_response(_borrow_target, _borrow_source, 1, Callable(self, "_finish_nullifiable_effect"))


func _draw_one_from_pile() -> Card:
	if draw_pile.is_empty():
		_refill_draw_pile()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()


func _refill_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()
	_add_log("牌堆已空，洗混弃牌堆形成新的摸牌堆。")


func _selected_card_name() -> String:
	if selected_hand_index >= 0 and selected_hand_index < current_player().hand.size():
		return current_player().hand[selected_hand_index].display_name
	return "牌"


func _card_list_text(cards: Array[Card]) -> String:
	var names: PackedStringArray = []
	for card: Card in cards:
		names.append(card.identity_text())
	return "、".join(names)


func _nature_text(nature: DamageNature) -> String:
	match nature:
		DamageNature.FIRE:
			return "火焰"
		DamageNature.THUNDER:
			return "雷电"
	return "普通"


func _ai_card_value(card: Card) -> int:
	match card.card_type:
		Card.CardType.PEACH:
			return 100
		Card.CardType.NULLIFICATION:
			return 90
		Card.CardType.DODGE:
			return 80
		Card.CardType.SLASH:
			return 70
		Card.CardType.DRAW_TWO:
			return 65
		Card.CardType.WINE:
			return 60
		Card.CardType.CROSSBOW, Card.CardType.QINGGANG_SWORD, Card.CardType.ICE_SWORD, \
		Card.CardType.GREEN_DRAGON_BLADE, Card.CardType.SERPENT_SPEAR, \
		Card.CardType.ROCK_CLEAVING_AXE, Card.CardType.HALBERD, \
		Card.CardType.VERMILION_FAN, Card.CardType.QILIN_BOW, \
		Card.CardType.EIGHT_TRIGRAMS, Card.CardType.VINE_ARMOR, \
		Card.CardType.SILVER_LION, Card.CardType.HORSE_PLUS, Card.CardType.HORSE_MINUS:
			return 55
	return 45


func _schedule(method_name: StringName, delay: float) -> void:
	var generation: int = _action_generation
	var callback := func() -> void:
		if generation == _action_generation and is_inside_tree():
			call(method_name)
	get_tree().create_timer(delay).timeout.connect(callback)


func _call_safe(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


func _reject(message: String) -> void:
	_add_log("提示：%s" % message)
	_emit_state()


func _add_log(message: String) -> void:
	print(message)
	log_added.emit(message)


func _emit_state() -> void:
	state_changed.emit()
