class_name GameManager
extends Node
## 对局总控：以显式阶段 + 流程状态驱动所有卡牌响应与伤害结算。
## UI 和 AI 都只能调用这里的公开请求方法，不可绕过结算顺序修改玩家。

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
	DYING_RESCUE,
	DISCARDING,
	GAME_OVER,
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

var selected_hand_index: int = -1
var pending_attacker: BattlePlayer
var pending_target: BattlePlayer
var pending_damage: int = 0
var dying_player: BattlePlayer
var winner: BattlePlayer

var _action_generation: int = 0


func _ready() -> void:
	players = [player1, player2]
	call_deferred("start_match")


func start_match() -> void:
	_action_generation += 1
	draw_pile = CardFactory.create_basic_deck()
	discard_pile.clear()
	current_player_index = 0
	turn_number = 0
	winner = null
	pending_attacker = null
	pending_target = null
	dying_player = null
	selected_hand_index = -1
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


func player_index(player: BattlePlayer) -> int:
	return players.find(player)


func is_play_phase_for(user: Node) -> bool:
	return (
		user == current_player()
		and phase == Phase.PLAY
		and flow_state in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]
	)


func is_waiting_for_dodge_from(user: Node) -> bool:
	return flow_state == FlowState.RESPONDING_SLASH and user == pending_target


func is_waiting_for_rescue_from(user: Node) -> bool:
	return flow_state == FlowState.DYING_RESCUE and user == dying_player


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
		return "已选择【杀】——点击或拖到对方角色区域"
	if flow_state == FlowState.RESPONDING_SLASH:
		return "%s 正被【杀】指定：使用【闪】或选择不响应" % pending_target.player_name
	if flow_state == FlowState.DYING_RESCUE:
		return "%s 濒死（体力 %d）：连续使用【桃】/【酒】直到体力回到 1" % [
			dying_player.player_name,
			dying_player.hp,
		]
	if flow_state == FlowState.DISCARDING:
		var excess: int = current_player().hand.size() - current_player().hand_limit()
		if excess > 0:
			return "弃牌阶段：还需弃置 %d 张牌（点击手牌弃置）" % excess
	if flow_state == FlowState.PLAY_ACTIVE:
		if current_player().is_ai:
			return "反贼正在思考……"
		return "你的出牌阶段：点击卡牌使用，或将卡牌拖到角色区域"
	return "%s · %s" % [current_player().player_name, phase_text()]


func request_card_use(hand_index: int) -> void:
	if flow_state == FlowState.GAME_OVER or current_player().is_ai:
		return
	if phase != Phase.PLAY:
		_reject("当前不是出牌阶段。")
		return
	if hand_index < 0 or hand_index >= current_player().hand.size():
		return

	if flow_state == FlowState.SELECTING_TARGET:
		selected_hand_index = -1
		flow_state = FlowState.PLAY_ACTIVE

	if flow_state != FlowState.PLAY_ACTIVE:
		return

	var card: Card = current_player().hand[hand_index]
	match card.card_type:
		Card.CardType.SLASH:
			if not card.can_use_in_play(self, current_player()):
				_reject("本回合已经使用过【杀】。")
				return
			selected_hand_index = hand_index
			flow_state = FlowState.SELECTING_TARGET
			_add_log("%s 选择了【杀】，等待指定目标。" % current_player().player_name)
			_emit_state()
		Card.CardType.PEACH:
			if not card.can_use_in_play(self, current_player()):
				_reject("体力已满，不能主动使用【桃】。")
				return
			_play_peach(current_player(), hand_index)
		Card.CardType.WINE:
			if not card.can_use_in_play(self, current_player()):
				_reject("本回合已有【酒】效果，不能重复饮酒。")
				return
			_play_wine(current_player(), hand_index)
		Card.CardType.DODGE:
			_reject("【闪】只能在成为【杀】的目标时响应使用。")


func request_card_on_target(hand_index: int, target_index: int) -> void:
	if flow_state == FlowState.GAME_OVER or current_player().is_ai:
		return
	if hand_index < 0 or hand_index >= current_player().hand.size():
		return
	if target_index < 0 or target_index >= players.size():
		return
	var card: Card = current_player().hand[hand_index]
	var target: BattlePlayer = players[target_index]

	if card.card_type == Card.CardType.SLASH:
		if target == current_player():
			_reject("【杀】必须指定对方为目标。")
			return
		if not card.can_use_in_play(self, current_player()):
			_reject("现在不能使用【杀】。")
			return
		_play_slash(current_player(), target, hand_index)
	elif target == current_player():
		request_card_use(hand_index)
	else:
		_reject("这张牌不能对敌方角色使用。")


func request_target(target_index: int) -> void:
	if flow_state != FlowState.SELECTING_TARGET:
		return
	if target_index < 0 or target_index >= players.size():
		return
	var target: BattlePlayer = players[target_index]
	if target == current_player():
		_reject("【杀】必须指定对方为目标。")
		return
	_play_slash(current_player(), target, selected_hand_index)


func request_cancel_selection() -> void:
	if flow_state != FlowState.SELECTING_TARGET:
		return
	selected_hand_index = -1
	flow_state = FlowState.PLAY_ACTIVE
	_emit_state()


func request_dodge() -> void:
	if flow_state != FlowState.RESPONDING_SLASH or pending_target.is_ai:
		return
	var dodge_index: int = pending_target.find_card(Card.CardType.DODGE)
	if dodge_index < 0:
		_reject("手牌中没有【闪】。")
		return
	_resolve_dodge(dodge_index)


func request_pass_response() -> void:
	if flow_state != FlowState.RESPONDING_SLASH or pending_target.is_ai:
		return
	_add_log("%s 未使用【闪】。" % pending_target.player_name)
	_resolve_slash_damage()


func request_rescue(card_type: Card.CardType) -> void:
	if flow_state != FlowState.DYING_RESCUE or dying_player.is_ai:
		return
	if card_type not in [Card.CardType.PEACH, Card.CardType.WINE]:
		return
	var card_index: int = dying_player.find_card(card_type)
	if card_index < 0:
		_reject("没有可用于自救的%s。" % ("【桃】" if card_type == Card.CardType.PEACH else "【酒】"))
		return
	_use_rescue_card(dying_player, card_index)


func request_give_up_rescue() -> void:
	if flow_state != FlowState.DYING_RESCUE or dying_player.is_ai:
		return
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
	_add_log("%s 弃置了【%s】。" % [current_player().player_name, card.display_name])
	if current_player().hand.size() <= current_player().hand_limit():
		_finish_discard_phase()
	else:
		_emit_state()


func draw_cards(player: BattlePlayer, count: int) -> void:
	for _index: int in count:
		if draw_pile.is_empty():
			_refill_draw_pile()
		if draw_pile.is_empty():
			return
		player.add_card(draw_pile.pop_back())


func _begin_turn() -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	turn_number += 1
	var active_player: BattlePlayer = current_player()
	active_player.reset_turn_flags()

	phase = Phase.START
	flow_state = FlowState.IDLE
	_add_log("—— 第 %d 回合：%s 的回合 ——" % [turn_number, active_player.player_name])
	_add_log("开始阶段。")
	_emit_state()

	phase = Phase.JUDGEMENT
	_add_log("判定阶段：当前没有延时锦囊，跳过。")
	_emit_state()

	phase = Phase.DRAW
	draw_cards(active_player, 2)
	_add_log("摸牌阶段：%s 摸了 2 张牌。" % active_player.player_name)
	_emit_state()

	phase = Phase.PLAY
	flow_state = FlowState.PLAY_ACTIVE
	_add_log("进入出牌阶段。")
	_emit_state()
	if active_player.is_ai:
		_schedule("_perform_ai_play", 0.65)


func _play_peach(user: BattlePlayer, hand_index: int) -> void:
	var card: Card = _consume_hand_card(user, hand_index)
	if card == null:
		return
	user.recover(1)
	_add_log("%s 使用【桃】，回复 1 点体力（%d/%d）。" % [
		user.player_name,
		user.hp,
		user.max_hp,
	])
	_emit_state()


func _play_wine(user: BattlePlayer, hand_index: int) -> void:
	var card: Card = _consume_hand_card(user, hand_index)
	if card == null:
		return
	user.wine_active = true
	_add_log("%s 使用【酒】：本回合下一张【杀】伤害 +1。" % user.player_name)
	_emit_state()


func _play_slash(attacker: BattlePlayer, target: BattlePlayer, hand_index: int) -> void:
	if flow_state not in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]:
		return
	var card: Card = _consume_hand_card(attacker, hand_index)
	if card == null or card.card_type != Card.CardType.SLASH:
		return
	attacker.slash_used_this_turn = true
	selected_hand_index = -1
	pending_attacker = attacker
	pending_target = target
	pending_damage = 2 if attacker.wine_active else 1
	attacker.wine_active = false
	flow_state = FlowState.RESPONDING_SLASH
	_add_log("%s 对 %s 使用【杀】%s。" % [
		attacker.player_name,
		target.player_name,
		"（酒杀，伤害 2）" if pending_damage == 2 else "",
	])
	_emit_state()
	if target.is_ai:
		_schedule("_perform_ai_slash_response", 0.65)


func _perform_ai_slash_response() -> void:
	if flow_state != FlowState.RESPONDING_SLASH or not pending_target.is_ai:
		return
	var dodge_index: int = pending_target.find_card(Card.CardType.DODGE)
	if dodge_index >= 0:
		_resolve_dodge(dodge_index)
	else:
		_add_log("%s 没有【闪】，无法响应。" % pending_target.player_name)
		_resolve_slash_damage()


func _resolve_dodge(dodge_index: int) -> void:
	var defender: BattlePlayer = pending_target
	var dodge: Card = _consume_hand_card(defender, dodge_index)
	if dodge == null or dodge.card_type != Card.CardType.DODGE:
		return
	_add_log("%s 使用【闪】，本次【杀】无效。" % defender.player_name)
	_resume_after_attack()


func _resolve_slash_damage() -> void:
	if flow_state != FlowState.RESPONDING_SLASH:
		return
	var target: BattlePlayer = pending_target
	target.take_damage(pending_damage)
	_add_log("%s 受到 %d 点伤害，当前体力 %d/%d。" % [
		target.player_name,
		pending_damage,
		target.hp,
		target.max_hp,
	])
	_emit_state()
	if target.is_dying():
		_enter_dying(target)
	else:
		_resume_after_attack()


func _enter_dying(player: BattlePlayer) -> void:
	dying_player = player
	flow_state = FlowState.DYING_RESCUE
	_add_log("%s 进入濒死状态，需要将体力回复至 1。" % player.player_name)
	_emit_state()
	if player.is_ai:
		_schedule("_perform_ai_rescue", 0.7)


func _perform_ai_rescue() -> void:
	if flow_state != FlowState.DYING_RESCUE or not dying_player.is_ai:
		return
	var rescue_index: int = dying_player.find_card(Card.CardType.PEACH)
	if rescue_index < 0:
		rescue_index = dying_player.find_card(Card.CardType.WINE)
	if rescue_index >= 0:
		_use_rescue_card(dying_player, rescue_index)
	else:
		_add_log("%s 没有【桃】或【酒】，无法自救。" % dying_player.player_name)
		_declare_death(dying_player)


func _use_rescue_card(player: BattlePlayer, hand_index: int) -> void:
	var card: Card = _consume_hand_card(player, hand_index)
	if card == null:
		return
	player.recover(1)
	_add_log("%s 濒死时使用【%s】，体力回复至 %d。" % [
		player.player_name,
		card.display_name,
		player.hp,
	])
	if player.is_dying():
		_emit_state()
		if player.is_ai:
			_schedule("_perform_ai_rescue", 0.55)
	else:
		_add_log("%s 脱离濒死状态。" % player.player_name)
		dying_player = null
		_resume_after_attack()


func _declare_death(loser: BattlePlayer) -> void:
	winner = other_player(loser)
	flow_state = FlowState.GAME_OVER
	_action_generation += 1
	_add_log("%s 阵亡。%s（%s）获胜！" % [
		loser.player_name,
		winner.player_name,
		winner.role_name,
	])
	_emit_state()
	match_finished.emit(winner, loser)


func _resume_after_attack() -> void:
	pending_attacker = null
	pending_target = null
	pending_damage = 0
	if flow_state == FlowState.GAME_OVER:
		return
	flow_state = FlowState.PLAY_ACTIVE
	_emit_state()
	if current_player().is_ai:
		_schedule("_perform_ai_play", 0.65)


func _perform_ai_play() -> void:
	if (
		flow_state != FlowState.PLAY_ACTIVE
		or phase != Phase.PLAY
		or not current_player().is_ai
	):
		return
	var ai: BattlePlayer = current_player()

	if ai.hp < ai.max_hp:
		var peach_index: int = ai.find_card(Card.CardType.PEACH)
		if peach_index >= 0:
			_play_peach(ai, peach_index)
			_schedule("_perform_ai_play", 0.5)
			return

	var slash_index: int = ai.find_card(Card.CardType.SLASH)
	if slash_index >= 0 and not ai.slash_used_this_turn:
		var wine_index: int = ai.find_card(Card.CardType.WINE)
		if wine_index >= 0 and not ai.wine_active:
			_play_wine(ai, wine_index)
			_schedule("_perform_ai_play", 0.5)
			return
		_play_slash(ai, other_player(ai), slash_index)
		return

	_enter_discard_phase()


func _enter_discard_phase() -> void:
	phase = Phase.DISCARD
	flow_state = FlowState.DISCARDING
	_add_log("进入弃牌阶段：手牌上限等于当前体力。")
	_emit_state()
	if current_player().hand.size() <= current_player().hand_limit():
		_schedule("_finish_discard_phase", 0.35)
	elif current_player().is_ai:
		_schedule("_perform_ai_discard", 0.55)


func _perform_ai_discard() -> void:
	if flow_state != FlowState.DISCARDING or not current_player().is_ai:
		return
	var ai: BattlePlayer = current_player()
	while ai.hand.size() > ai.hand_limit():
		var card: Card = ai.remove_card_at(ai.hand.size() - 1)
		discard_pile.append(card)
		_add_log("%s 弃置了 1 张牌。" % ai.player_name)
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
	_schedule("_begin_turn", 0.65)


func _consume_hand_card(player: BattlePlayer, hand_index: int) -> Card:
	var card: Card = player.remove_card_at(hand_index)
	if card != null:
		discard_pile.append(card)
	return card


func _refill_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()
	_add_log("牌堆已空，洗混弃牌堆形成新的摸牌堆。")


func _schedule(method_name: StringName, delay: float) -> void:
	var generation: int = _action_generation
	var callback := func() -> void:
		if generation == _action_generation and is_inside_tree():
			call(method_name)
	get_tree().create_timer(delay).timeout.connect(callback)


func _reject(message: String) -> void:
	_add_log("提示：%s" % message)
	_emit_state()


func _add_log(message: String) -> void:
	log_added.emit(message)


func _emit_state() -> void:
	state_changed.emit()
