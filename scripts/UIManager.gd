class_name UIManager
extends CanvasLayer
## UI 管理器：监听 GameManager 信号并把所有输入转为规则请求。

@onready var turn_label: Label = %TurnLabel
@onready var phase_label: Label = %PhaseLabel
@onready var deck_label: Label = %DeckLabel
@onready var prompt_label: Label = %PromptLabel

@onready var opponent_zone: PlayerDropZone = %OpponentZone
@onready var player_zone: PlayerDropZone = %PlayerZone
@onready var opponent_name: Label = %OpponentName
@onready var player_name: Label = %PlayerName
@onready var opponent_hp: ProgressBar = %OpponentHP
@onready var player_hp: ProgressBar = %PlayerHP
@onready var opponent_hp_text: Label = %OpponentHPText
@onready var player_hp_text: Label = %PlayerHPText
@onready var opponent_status: Label = %OpponentStatus
@onready var player_status: Label = %PlayerStatus
@onready var opponent_hand: HBoxContainer = %OpponentHand
@onready var player_hand: HBoxContainer = %PlayerHand

@onready var end_play_button: Button = %EndPlayButton
@onready var cancel_button: Button = %CancelButton
@onready var dodge_button: Button = %DodgeButton
@onready var pass_button: Button = %PassButton
@onready var peach_button: Button = %PeachButton
@onready var wine_button: Button = %WineButton
@onready var give_up_button: Button = %GiveUpButton
@onready var restart_button: Button = %RestartButton
@onready var slash_response_button: Button = %SlashResponseButton
@onready var nullification_button: Button = %NullificationButton
@onready var pass_nullification_button: Button = %PassNullificationButton
@onready var fire_pass_button: Button = %FirePassButton
@onready var choice_buttons: Array[Button] = [
	%ChoiceButton0,
	%ChoiceButton1,
	%ChoiceButton2,
	%ChoiceButton3,
]
@onready var log_view: RichTextLabel = %LogView

var game: GameManager


func _ready() -> void:
	opponent_zone.card_dropped.connect(_on_card_dropped)
	player_zone.card_dropped.connect(_on_card_dropped)
	opponent_zone.target_clicked.connect(_on_target_clicked)
	player_zone.target_clicked.connect(_on_target_clicked)
	end_play_button.pressed.connect(_on_end_play)
	cancel_button.pressed.connect(_on_cancel)
	dodge_button.pressed.connect(_on_dodge)
	pass_button.pressed.connect(_on_pass_response)
	peach_button.pressed.connect(_on_rescue.bind(Card.CardType.PEACH))
	wine_button.pressed.connect(_on_rescue.bind(Card.CardType.WINE))
	give_up_button.pressed.connect(_on_give_up)
	restart_button.pressed.connect(_on_restart)
	slash_response_button.pressed.connect(_on_slash_response)
	nullification_button.pressed.connect(_on_nullification)
	pass_nullification_button.pressed.connect(_on_pass_nullification)
	fire_pass_button.pressed.connect(_on_fire_pass)
	for index: int in choice_buttons.size():
		choice_buttons[index].pressed.connect(_on_choice.bind(index))


func bind_game_manager(manager: GameManager) -> void:
	game = manager
	game.state_changed.connect(refresh)
	game.log_added.connect(_append_log)
	refresh()


func refresh() -> void:
	if game == null or game.players.is_empty():
		return
	var human: BattlePlayer = game.player1
	var ai: BattlePlayer = game.player2

	turn_label.text = "第 %d 回合 · %s" % [game.turn_number, game.current_player().player_name]
	phase_label.text = game.phase_text()
	deck_label.text = "牌堆 %d  ·  弃牌 %d" % [game.draw_pile.size(), game.discard_pile.size()]
	prompt_label.text = game.prompt_text()

	player_name.text = "%s  ·  %s" % [human.player_name, human.role_name]
	opponent_name.text = "%s  ·  %s（AI）" % [ai.player_name, ai.role_name]
	_update_hp(player_hp, player_hp_text, human)
	_update_hp(opponent_hp, opponent_hp_text, ai)
	player_status.text = _status_text(human)
	opponent_status.text = _status_text(ai)
	_rebuild_human_hand(human)
	_rebuild_opponent_hand(ai)
	_update_actions(human)
	_update_target_highlight()


func _update_hp(bar: ProgressBar, label: Label, player: BattlePlayer) -> void:
	bar.max_value = player.max_hp
	bar.value = maxi(player.hp, 0)
	label.text = "体力 %d / %d    手牌 %d / 上限 %d" % [
		player.hp,
		player.max_hp,
		player.hand.size(),
		player.hand_limit(),
	]


func _rebuild_human_hand(player: BattlePlayer) -> void:
	_clear_container(player_hand)
	if game.flow_state == GameManager.FlowState.CHOOSING_REVEALED:
		for index: int in game.revealed_cards.size():
			var revealed_view := CardView.new()
			revealed_view.configure(game.revealed_cards[index], index)
			revealed_view.card_clicked.connect(_on_revealed_card_clicked)
			player_hand.add_child(revealed_view)
		return
	for index: int in player.hand.size():
		var view := CardView.new()
		view.configure(player.hand[index], index)
		view.card_clicked.connect(_on_card_clicked)
		if (
			game.flow_state == GameManager.FlowState.SELECTING_TARGET
			and index == game.selected_hand_index
		):
			view.set_selected(true)
		player_hand.add_child(view)


func _rebuild_opponent_hand(player: BattlePlayer) -> void:
	_clear_container(opponent_hand)
	for index: int in player.hand.size():
		var back := CardView.new()
		back.custom_minimum_size = Vector2(62.0, 82.0)
		back.configure(null, index, true)
		opponent_hand.add_child(back)


func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _update_actions(human: BattlePlayer) -> void:
	var all_buttons: Array[Button] = [
		end_play_button,
		cancel_button,
		dodge_button,
		pass_button,
		peach_button,
		wine_button,
		give_up_button,
		restart_button,
		slash_response_button,
		nullification_button,
		pass_nullification_button,
		fire_pass_button,
	]
	all_buttons.append_array(choice_buttons)
	for button: Button in all_buttons:
		button.visible = false

	var is_human_play := (
		not game.current_player().is_ai
		and game.phase == GameManager.Phase.PLAY
		and game.flow_state in [
			GameManager.FlowState.PLAY_ACTIVE,
			GameManager.FlowState.SELECTING_TARGET,
		]
	)
	end_play_button.visible = is_human_play
	cancel_button.visible = game.flow_state == GameManager.FlowState.SELECTING_TARGET

	var responding_to_slash := (
		game.flow_state == GameManager.FlowState.RESPONDING_SLASH
		and game.pending_target == human
	)
	dodge_button.visible = responding_to_slash
	pass_button.visible = responding_to_slash
	pass_button.text = "不使用闪"
	dodge_button.disabled = human.find_card(Card.CardType.DODGE) < 0

	var aoe_response := (
		game.flow_state == GameManager.FlowState.AOE_RESPONSE
		and game.pending_target == human
	)
	if aoe_response:
		if game._response_card_type == Card.CardType.DODGE:
			dodge_button.visible = true
			dodge_button.disabled = human.find_card(Card.CardType.DODGE) < 0
		else:
			slash_response_button.visible = true
			slash_response_button.disabled = human.find_card(Card.CardType.SLASH) < 0
		pass_button.visible = true
		pass_button.text = "不响应"

	var duel_response := (
		game.flow_state == GameManager.FlowState.DUEL_RESPONSE
		and game._duel_responder == human
	)
	if duel_response:
		slash_response_button.visible = true
		slash_response_button.disabled = human.find_card(Card.CardType.SLASH) < 0
		pass_button.visible = true
		pass_button.text = "不出【杀】"

	var nullifying := (
		game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE
		and game.players[game._nullification_responder_index] == human
	)
	if nullifying:
		nullification_button.visible = true
		nullification_button.disabled = human.find_card(Card.CardType.NULLIFICATION) < 0
		pass_nullification_button.visible = true

	if game.flow_state == GameManager.FlowState.FIRE_DISCARD and game._fire_source == human:
		fire_pass_button.visible = true

	if game.flow_state == GameManager.FlowState.CHOOSING_OPTION and game.choice_owner == human:
		for index: int in mini(game.choice_labels.size(), choice_buttons.size()):
			choice_buttons[index].visible = true
			choice_buttons[index].text = game.choice_labels[index]

	var rescuing := (
		game.flow_state == GameManager.FlowState.DYING_RESCUE
		and game.dying_player == human
	)
	peach_button.visible = rescuing
	wine_button.visible = rescuing
	give_up_button.visible = rescuing
	peach_button.disabled = human.find_card(Card.CardType.PEACH) < 0
	wine_button.disabled = human.find_card(Card.CardType.WINE) < 0

	restart_button.visible = game.flow_state == GameManager.FlowState.GAME_OVER


func _status_text(player: BattlePlayer) -> String:
	var states: PackedStringArray = []
	states.append("连环：%s" % ("横置" if player.chained else "未横置"))
	states.append("武器：%s" % (player.weapon_card.display_name if player.weapon_card != null else "无"))
	var delayed: PackedStringArray = []
	if player.indulgence_card != null:
		delayed.append("乐")
	if player.supply_shortage_card != null:
		delayed.append("兵")
	if player.lightning_card != null:
		delayed.append("闪电")
	states.append("判定区：%s" % ("空" if delayed.is_empty() else "/".join(delayed)))
	return "  ·  ".join(states)


func _update_target_highlight() -> void:
	var selecting := game.flow_state == GameManager.FlowState.SELECTING_TARGET
	opponent_zone.modulate = Color("fff0a8") if selecting else Color.WHITE
	player_zone.modulate = Color.WHITE


func _on_card_clicked(hand_index: int) -> void:
	if game == null:
		return
	game.request_card_use(hand_index)


func _on_revealed_card_clicked(card_index: int) -> void:
	game.request_revealed_card(card_index)


func _on_card_dropped(hand_index: int, target_index: int) -> void:
	game.request_card_on_target(hand_index, target_index)


func _on_target_clicked(target_index: int) -> void:
	game.request_target(target_index)


func _on_end_play() -> void:
	game.request_end_play_phase()


func _on_cancel() -> void:
	game.request_cancel_selection()


func _on_dodge() -> void:
	game.request_dodge()


func _on_pass_response() -> void:
	game.request_pass_response()


func _on_rescue(card_type: Card.CardType) -> void:
	game.request_rescue(card_type)


func _on_give_up() -> void:
	game.request_give_up_rescue()


func _on_restart() -> void:
	log_view.clear()
	game.start_match()


func _on_slash_response() -> void:
	game.request_response_card()


func _on_nullification() -> void:
	game.request_nullification()


func _on_pass_nullification() -> void:
	game.request_pass_nullification()


func _on_fire_pass() -> void:
	game.request_pass_fire_discard()


func _on_choice(index: int) -> void:
	game.request_option(index)


func _append_log(message: String) -> void:
	log_view.append_text("%s\n" % message)
	log_view.scroll_to_line(log_view.get_line_count())
