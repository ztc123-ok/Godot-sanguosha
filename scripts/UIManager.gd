class_name UIManager
extends CanvasLayer
## UI 管理器：监听 GameManager 信号并把所有输入转为规则请求。

@onready var root: Control = $Root
@onready var action_bar: HBoxContainer = $Root/Margin/Layout/ActionBar
@onready var turn_label: Label = %TurnLabel
@onready var phase_label: Label = %PhaseLabel
@onready var deck_label: Label = %DeckLabel
@onready var prompt_label: Label = %PromptLabel

@onready var enemy_container: HBoxContainer = %EnemyContainer
@onready var player_zone: PlayerDropZone = %PlayerZone
@onready var player_name: Label = %PlayerName
@onready var player_hp: ProgressBar = %PlayerHP
@onready var player_hp_text: Label = %PlayerHPText
@onready var player_status: Label = %PlayerStatus
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
@onready var bagua_button: Button = %BaguaButton
@onready var serpent_spear_button: Button = %SerpentSpearButton
@onready var choice_buttons: Array[Button] = [
	%ChoiceButton0,
	%ChoiceButton1,
	%ChoiceButton2,
	%ChoiceButton3,
]
@onready var log_view: RichTextLabel = %LogView

var game: GameManager
var general_backdrop: ColorRect
var general_panel: PanelContainer
var general_summary: Label
var start_match_button: Button
var default_generals_button: Button
var skill_buttons: Array[Button] = []
var skill_confirm_button: Button
var skill_decline_button: Button
var skill_cards_confirm_button: Button
var skill_cancel_button: Button
var reselect_button: Button
var skill_equipment_buttons: Array[Button] = []
var selected_private_card_index: int = -1
var guanxing_top_indices: Array[int] = []
## 与 game.enemies 一一对应的动态敌方区域。
var enemy_zones: Array[PlayerDropZone] = []
var enemy_zone_names: Array[Label] = []
var enemy_zone_hps: Array[ProgressBar] = []
var enemy_zone_hp_texts: Array[Label] = []
var enemy_zone_statuses: Array[Label] = []
var enemy_zone_hands: Array[HBoxContainer] = []


func _ready() -> void:
	_build_skill_action_buttons()
	_build_general_selection_panel()
	player_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	player_status.clip_text = true
	player_status.custom_minimum_size.x = 520.0
	player_zone.card_dropped.connect(_on_card_dropped)
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
	bagua_button.pressed.connect(_on_bagua)
	serpent_spear_button.pressed.connect(_on_serpent_spear)
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
	if game.flow_state != GameManager.FlowState.SKILL_ASSIGN_CARDS:
		selected_private_card_index = -1
	if game.flow_state != GameManager.FlowState.DECK_REORDER:
		guanxing_top_indices.clear()
	var human: BattlePlayer = game.player1

	if game.flow_state == GameManager.FlowState.GENERAL_SELECTION:
		turn_label.text = "选将阶段"
		phase_label.text = "对局尚未开始"
	else:
		turn_label.text = "第 %d 回合 · %s" % [game.turn_number, game.current_player().player_name]
		phase_label.text = game.phase_text()
	deck_label.text = "牌堆 %d  ·  弃牌 %d" % [game.draw_pile.size(), game.discard_pile.size()]
	prompt_label.text = game.prompt_text()

	player_name.text = "%s · %s · %s【%s】%s" % [
		human.player_name,
		human.role_name,
		human.kingdom if not human.kingdom.is_empty() else "未定",
		human.general_name,
		"（男）" if human.gender == GeneralDefinition.Gender.MALE else "（女）",
	]
	_update_hp(player_hp, player_hp_text, human)
	player_status.text = _status_text(human)
	player_status.tooltip_text = _skill_tooltip(human)
	_rebuild_human_hand(human)
	_ensure_enemy_zones()
	for index: int in game.enemies.size():
		_update_enemy_zone(index)
	_update_actions(human)
	_update_target_highlight()
	_update_general_panel()


func _update_hp(bar: ProgressBar, label: Label, player: BattlePlayer) -> void:
	bar.max_value = player.max_hp
	bar.value = maxi(player.hp, 0)
	label.text = "体力 %d / %d    手牌 %d / 上限 %d" % [
		player.hp,
		player.max_hp,
		player.hand.size(),
		game.hand_limit_for(player),
	]


func _rebuild_human_hand(player: BattlePlayer) -> void:
	_clear_container(player_hand)
	if game.flow_state in [GameManager.FlowState.SKILL_ASSIGN_CARDS, GameManager.FlowState.DECK_REORDER] and game.private_card_owner == player:
		for index: int in game.private_cards.size():
			var private_view := CardView.new()
			private_view.configure(game.private_cards[index], index)
			private_view.card_clicked.connect(_on_private_card_clicked)
			if index == selected_private_card_index or index in guanxing_top_indices:
				private_view.set_selected(true)
			player_hand.add_child(private_view)
		return
	if game.flow_state == GameManager.FlowState.CHOOSING_REVEALED:
		for index: int in game.revealed_cards.size():
			var revealed_view := CardView.new()
			revealed_view.configure(game.revealed_cards[index], index)
			## 亮出的牌双方都可见，但只有当前轮到的人能点击选择。
			if game._revealed_selecting_player == player:
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
		if (
			game.flow_state == GameManager.FlowState.SKILL_SELECT_CARDS
			and player.hand[index] in game.pending_skill_cards
		):
			view.set_selected(true)
		player_hand.add_child(view)


## 按敌人数量动态生成敌方角色区域（EnemyZone），数量变化时整体重建。
func _ensure_enemy_zones() -> void:
	if enemy_zones.size() == game.enemies.size():
		return
	_clear_container(enemy_container)
	enemy_zones.clear()
	enemy_zone_names.clear()
	enemy_zone_hps.clear()
	enemy_zone_hp_texts.clear()
	enemy_zone_statuses.clear()
	enemy_zone_hands.clear()
	for index: int in game.enemies.size():
		var enemy: BattlePlayer = game.enemies[index]
		var zone := PlayerDropZone.new()
		zone.name = "EnemyZone%d" % (index + 1)
		zone.custom_minimum_size = Vector2(0, 142)
		zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zone.player_index = game.players.find(enemy)
		zone.add_theme_stylebox_override("panel", _enemy_zone_style())
		zone.card_dropped.connect(_on_card_dropped)
		zone.target_clicked.connect(_on_target_clicked)
		enemy_container.add_child(zone)
		enemy_zones.append(zone)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 9)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 9)
		zone.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		margin.add_child(row)

		var avatar := PanelContainer.new()
		avatar.custom_minimum_size = Vector2(64, 0)
		avatar.add_theme_stylebox_override("panel", _avatar_style())
		row.add_child(avatar)
		var avatar_label := Label.new()
		avatar_label.text = "反"
		avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar_label.add_theme_color_override("font_color", Color(0.92, 0.44, 0.33))
		avatar_label.add_theme_font_size_override("font_size", 30)
		avatar.add_child(avatar_label)

		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(230, 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 6)
		row.add_child(info)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 18)
		info.add_child(name_label)
		enemy_zone_names.append(name_label)

		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(0, 20)
		hp_bar.show_percentage = false
		hp_bar.add_theme_stylebox_override("background", _bar_background_style())
		hp_bar.add_theme_stylebox_override("fill", _bar_enemy_style())
		info.add_child(hp_bar)
		enemy_zone_hps.append(hp_bar)

		var hp_text := Label.new()
		hp_text.add_theme_color_override("font_color", Color(0.95, 0.82, 0.78))
		info.add_child(hp_text)
		enemy_zone_hp_texts.append(hp_text)

		var status_label := Label.new()
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		status_label.clip_text = true
		status_label.add_theme_color_override("font_color", Color(0.82, 0.62, 0.55))
		info.add_child(status_label)
		enemy_zone_statuses.append(status_label)

		var hand_box := HBoxContainer.new()
		hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_box.alignment = BoxContainer.ALIGNMENT_END
		hand_box.add_theme_constant_override("separation", -22)
		row.add_child(hand_box)
		enemy_zone_hands.append(hand_box)


func _update_enemy_zone(index: int) -> void:
	if index < 0 or index >= game.enemies.size():
		return
	var enemy: BattlePlayer = game.enemies[index]
	var zone: PlayerDropZone = enemy_zones[index]
	var dead: bool = enemy.is_dying()
	enemy_zone_names[index].text = "%s · 反贼 · %s【%s】（AI）%s" % [
		enemy.player_name,
		enemy.kingdom if not enemy.kingdom.is_empty() else "未定",
		enemy.general_name,
		" · 已阵亡" if dead else "",
	]
	_update_hp(enemy_zone_hps[index], enemy_zone_hp_texts[index], enemy)
	enemy_zone_statuses[index].text = _status_text(enemy)
	enemy_zone_statuses[index].tooltip_text = _skill_tooltip(enemy)
	_clear_container(enemy_zone_hands[index])
	for hand_index: int in enemy.hand.size():
		var back := CardView.new()
		back.custom_minimum_size = Vector2(58.0, 78.0)
		back.configure(null, hand_index, true)
		enemy_zone_hands[index].add_child(back)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE if dead else Control.MOUSE_FILTER_STOP


func _enemy_zone_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.075, 0.068, 0.94)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.65, 0.22, 0.17)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	return style


func _avatar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.078, 0.071, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.66, 0.45, 0.22)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


func _bar_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.1, 0.9)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	return style


func _bar_enemy_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.26, 0.2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	return style


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
		bagua_button,
		serpent_spear_button,
	]
	all_buttons.append_array(choice_buttons)
	all_buttons.append_array(skill_buttons)
	all_buttons.append_array(skill_equipment_buttons)
	all_buttons.append_array([
		skill_confirm_button,
		skill_decline_button,
		skill_cards_confirm_button,
		skill_cancel_button,
		reselect_button,
	])
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
	serpent_spear_button.visible = is_human_play and game.can_use_serpent_spear(human)
	serpent_spear_button.text = "丈八两牌当【杀】"
	if game.is_selecting_iron_chain():
		skill_cards_confirm_button.visible = true
		skill_cards_confirm_button.text = "确认铁索目标（%d/2）" % game.iron_chain_selected_targets.size()
		skill_cards_confirm_button.disabled = game.iron_chain_selected_targets.is_empty()
		skill_cancel_button.visible = true
		skill_cancel_button.text = "重铸【铁索连环】（摸一张）"

	var responding_to_slash := (
		game.flow_state in [
			GameManager.FlowState.RESPONDING_SLASH,
			GameManager.FlowState.MULTI_RESPONSE,
		]
		and (
			game.flow_state != GameManager.FlowState.MULTI_RESPONSE
			or game._multi_response_origin == GameManager.FlowState.RESPONDING_SLASH
		)
		and game.pending_target == human
	)
	dodge_button.visible = responding_to_slash
	pass_button.visible = responding_to_slash
	pass_button.text = "不使用闪"
	dodge_button.disabled = human.find_card(Card.CardType.DODGE) < 0
	bagua_button.visible = responding_to_slash and game.can_use_bagua(human)

	var aoe_response := (
		game.flow_state == GameManager.FlowState.AOE_RESPONSE
		and game.pending_target == human
	)
	if aoe_response:
		if game._response_card_type == Card.CardType.DODGE:
			dodge_button.visible = true
			dodge_button.disabled = human.find_card(Card.CardType.DODGE) < 0
			bagua_button.visible = game.can_use_bagua(human)
		else:
			slash_response_button.visible = true
			slash_response_button.disabled = human.find_card(Card.CardType.SLASH) < 0
			serpent_spear_button.visible = game.can_use_serpent_spear(human)
		pass_button.visible = true
		pass_button.text = "不响应"

	var duel_response := (
		game.flow_state in [
			GameManager.FlowState.DUEL_RESPONSE,
			GameManager.FlowState.MULTI_RESPONSE,
		]
		and (
			game.flow_state != GameManager.FlowState.MULTI_RESPONSE
			or game._multi_response_origin == GameManager.FlowState.DUEL_RESPONSE
		)
		and game._duel_responder == human
	)
	if duel_response:
		slash_response_button.visible = true
		slash_response_button.disabled = human.find_card(Card.CardType.SLASH) < 0
		serpent_spear_button.visible = game.can_use_serpent_spear(human)
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

	if game.flow_state in [GameManager.FlowState.CHOOSING_OPTION, GameManager.FlowState.KILL_REWARD] and game.choice_owner == human:
		for index: int in mini(game.choice_labels.size(), choice_buttons.size()):
			choice_buttons[index].visible = true
			choice_buttons[index].text = game.choice_labels[index]
	if game.flow_state == GameManager.FlowState.CHOOSING_SUIT and game.choice_owner == human:
		for index: int in mini(game.choice_labels.size(), choice_buttons.size()):
			choice_buttons[index].visible = true
			choice_buttons[index].text = game.choice_labels[index]

	var rescuing := (
		game.flow_state == GameManager.FlowState.DYING_RESCUE
		and game.rescue_actor == human
	)
	peach_button.visible = rescuing
	wine_button.visible = rescuing
	give_up_button.visible = rescuing
	peach_button.disabled = human.find_card(Card.CardType.PEACH) < 0
	wine_button.disabled = (
		game.dying_player != human or human.find_card(Card.CardType.WINE) < 0
	)
	## 救援操作者不是濒死者本人时，酒按钮禁用；急救由技能按钮提供。

	restart_button.visible = game.flow_state == GameManager.FlowState.GAME_OVER
	reselect_button.visible = game.flow_state == GameManager.FlowState.GAME_OVER

	if game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.skill_actor == human:
		skill_confirm_button.visible = true
		if game.pending_skill.id == &"tieqi":
			skill_confirm_button.text = "发动判定"
		elif game.pending_skill.activation_mode == Skill.ActivationMode.TRIGGERED:
			skill_confirm_button.text = "发动"
		else:
			skill_confirm_button.text = "发动【%s】" % game.pending_skill.display_name
		skill_decline_button.visible = true
		skill_decline_button.text = "不发动"
	if game.flow_state == GameManager.FlowState.JUDGEMENT_REPLACE and game.skill_actor == human:
		skill_decline_button.visible = true
		skill_decline_button.text = "放弃改判"

	if game.flow_state == GameManager.FlowState.SKILL_ASSIGN_CARDS and game.private_card_owner == human:
		choice_buttons[0].visible = selected_private_card_index >= 0
		choice_buttons[0].text = "交给主公"
		choice_buttons[1].visible = selected_private_card_index >= 0
		choice_buttons[1].text = "交给反贼"
		skill_cards_confirm_button.visible = true
		skill_cards_confirm_button.text = "确认遗计分配"
		skill_cards_confirm_button.disabled = -1 in game.private_card_assignments
		skill_cancel_button.visible = true
		skill_cancel_button.text = "取消调整（全归自己）"
	if game.flow_state == GameManager.FlowState.DECK_REORDER and game.private_card_owner == human:
		skill_cards_confirm_button.visible = true
		skill_cards_confirm_button.text = "确认观星顺序"
		skill_cards_confirm_button.disabled = false
		skill_cancel_button.visible = true
		skill_cancel_button.text = "保持原顺序"

	if game.flow_state == GameManager.FlowState.SKILL_SELECT_CARDS and game.skill_actor == human:
		skill_cancel_button.visible = true
		skill_cancel_button.text = "取消弃牌" if game._ganglie_discard_active else "取消技能"
		var ganglie_discarding: bool = game._ganglie_discard_active
		skill_cards_confirm_button.visible = (
			game.pending_skill.activation_mode == Skill.ActivationMode.ACTIVE
			or ganglie_discarding
		)
		skill_cards_confirm_button.text = "确认弃置两张" if ganglie_discarding else "确认技能代价"
		skill_cards_confirm_button.disabled = (
			game.pending_skill_cards.size() != 2
			if ganglie_discarding
			else game.pending_skill_cards.is_empty()
		)
		_update_skill_equipment_buttons(human)

	if game.flow_state == GameManager.FlowState.SKILL_SELECT_TARGET and game.skill_actor == human:
		skill_cancel_button.visible = true

	var skill_button_visible := (
		game.flow_state not in [
			GameManager.FlowState.GENERAL_SELECTION,
			GameManager.FlowState.GAME_OVER,
			GameManager.FlowState.SKILL_CONFIRM,
			GameManager.FlowState.SKILL_SELECT_CARDS,
			GameManager.FlowState.SKILL_SELECT_TARGET,
			GameManager.FlowState.SKILL_RESOLVING,
			GameManager.FlowState.JUDGEMENT_REPLACE,
			GameManager.FlowState.DECK_REORDER,
			GameManager.FlowState.SKILL_ASSIGN_CARDS,
			GameManager.FlowState.CHOOSING_SUIT,
			GameManager.FlowState.KILL_REWARD,
		]
		or game.flow_state == GameManager.FlowState.DYING_RESCUE
	)
	if skill_button_visible:
		for index: int in mini(human.skills.size(), skill_buttons.size()):
			var skill: Skill = human.skills[index]
			if skill.activation_mode not in [Skill.ActivationMode.ACTIVE, Skill.ActivationMode.VIEW_AS]:
				continue
			var button: Button = skill_buttons[index]
			button.set_meta("skill_id", skill.id)
			button.visible = game.can_use_skill(human, skill)
			button.disabled = not game.can_use_skill(human, skill)
			button.text = "【%s】" % skill.display_name
			button.tooltip_text = skill.description


func _status_text(player: BattlePlayer) -> String:
	var states: PackedStringArray = []
	var skill_states: PackedStringArray = []
	## Buff 放在裁剪文本最前方，确保玩家能直接看到当前【孤军】收益。
	var combat_effects: PackedStringArray = game.combat_modifier_statuses_for(player)
	if not combat_effects.is_empty():
		states.append("增益:%s" % "/".join(combat_effects))
	for skill: Skill in player.skills:
		var state_text := "待触发"
		if skill.has_tag(Skill.SkillTag.LOCKED):
			state_text = "生效中"
		elif skill.usage_scope == Skill.UsageScope.PER_TURN:
			state_text = "已用" if player.skill_use_count(skill) >= skill.max_uses else "可用"
		elif skill.activation_mode in [Skill.ActivationMode.ACTIVE, Skill.ActivationMode.VIEW_AS]:
			state_text = "可用" if game.can_use_skill(player, skill) else "待时机"
		if skill.id == &"luoyi" and player.luoyi_active:
			state_text = "本回合生效"
		skill_states.append("%s(%s)" % [skill.display_name, state_text])
	states.append("技:%s" % ("无" if skill_states.is_empty() else "/".join(skill_states)))
	states.append("链:%s" % ("横" if player.chained else "未"))
	states.append("武:%s" % (player.weapon.display_name if player.weapon != null else "无"))
	states.append("防:%s" % (player.armor.display_name if player.armor != null else "无"))
	states.append("+1:%s" % (player.horse_plus.display_name if player.horse_plus != null else "无"))
	states.append("-1:%s" % (player.horse_minus.display_name if player.horse_minus != null else "无"))
	var delayed: PackedStringArray = []
	if player.indulgence_card != null:
		delayed.append("乐")
	if player.supply_shortage_card != null:
		delayed.append("兵")
	if player.lightning_card != null:
		delayed.append("闪电")
	states.append("判:%s" % ("空" if delayed.is_empty() else "/".join(delayed)))
	return " · ".join(states)


func _skill_tooltip(player: BattlePlayer) -> String:
	var lines: PackedStringArray = ["%s · %s · %s" % [player.role_name, player.general_name, player.kingdom]]
	for skill: Skill in player.skills:
		lines.append("【%s】%s / %s\n%s" % [skill.display_name, skill.activation_text(), skill.usage_text(), skill.description])
	return "\n\n".join(lines)


func _update_target_highlight() -> void:
	var selecting := game.flow_state in [
		GameManager.FlowState.SELECTING_TARGET,
		GameManager.FlowState.SKILL_SELECT_TARGET,
	]
	for index: int in enemy_zones.size():
		var enemy: BattlePlayer = game.enemies[index]
		var zone: PlayerDropZone = enemy_zones[index]
		if enemy.is_dying():
			zone.modulate = Color(0.45, 0.45, 0.45)
		elif game.is_selecting_iron_chain() and enemy in game.iron_chain_selected_targets:
			zone.modulate = Color("a8ffc2")
		elif selecting and _is_enemy_zone_selectable(enemy):
			zone.modulate = Color("fff0a8")
		else:
			zone.modulate = Color.WHITE
	if game.is_selecting_iron_chain():
		player_zone.modulate = (
			Color("a8ffc2")
			if game.player1 in game.iron_chain_selected_targets
			else Color("fff0a8")
		)
	elif (
		selecting
		and game._pending_borrow_slash_target
		and game.can_slash_target(game._borrow_target, game.player1)
	):
		player_zone.modulate = Color("fff0a8")
	else:
		player_zone.modulate = Color.WHITE


func _is_enemy_zone_selectable(player: BattlePlayer) -> bool:
	if game.flow_state == GameManager.FlowState.SKILL_SELECT_TARGET:
		if game.skill_actor == null:
			return false
		if player == game.skill_actor and not game.pending_skill.allows_self_target():
			return false
		return not player.is_dying()
	if game.flow_state == GameManager.FlowState.SELECTING_TARGET:
		if game._pending_borrow_slash_target:
			return game.can_slash_target(game._borrow_target, player)
		if not game._pending_serpent_spear.is_empty():
			return game.can_slash_target(game.player1, player)
		if game.is_selecting_iron_chain():
			return not player.is_dying()
		var hand_index: int = game.selected_hand_index
		if hand_index < 0 or hand_index >= game.current_player().hand.size():
			return false
		var card: Card = game.current_player().hand[hand_index]
		if card.card_type == Card.CardType.SLASH:
			return game.can_slash_target(game.current_player(), player)
		if card.is_trick() and not card.is_delayed_trick:
			return game._is_valid_trick_target(card, game.current_player(), player)
	return false


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
	game.request_restart_match()


func _on_slash_response() -> void:
	game.request_response_card()


func _on_nullification() -> void:
	game.request_nullification()


func _on_pass_nullification() -> void:
	game.request_pass_nullification()


func _on_fire_pass() -> void:
	game.request_pass_fire_discard()


func _on_bagua() -> void:
	game.request_bagua_judgement()


func _on_serpent_spear() -> void:
	game.request_serpent_spear()


func _on_choice(index: int) -> void:
	if game.flow_state == GameManager.FlowState.CHOOSING_SUIT:
		game.request_choose_suit(index)
	elif game.flow_state == GameManager.FlowState.SKILL_ASSIGN_CARDS and selected_private_card_index >= 0:
		game.request_assign_private_card(selected_private_card_index, index)
	else:
		game.request_option(index)


func _on_private_card_clicked(index: int) -> void:
	if game.flow_state == GameManager.FlowState.SKILL_ASSIGN_CARDS:
		selected_private_card_index = index
	elif game.flow_state == GameManager.FlowState.DECK_REORDER:
		if index in guanxing_top_indices:
			guanxing_top_indices.erase(index)
		else:
			guanxing_top_indices.append(index)
	refresh()


func _on_skill_pressed(button: Button) -> void:
	game.request_begin_skill(StringName(button.get_meta("skill_id", "")))


func _on_skill_confirm() -> void:
	game.request_confirm_skill()


func _on_skill_decline() -> void:
	if game.flow_state == GameManager.FlowState.JUDGEMENT_REPLACE:
		game.request_pass_judgement_replace()
	else:
		game.request_decline_skill()


func _on_skill_cards_confirm() -> void:
	if game.is_selecting_iron_chain():
		game.request_confirm_iron_chain_targets()
	elif game.flow_state == GameManager.FlowState.SKILL_ASSIGN_CARDS:
		game.request_confirm_card_assignment()
	elif game.flow_state == GameManager.FlowState.DECK_REORDER:
		game.request_confirm_deck_reorder(guanxing_top_indices)
	else:
		game.request_confirm_skill_cards()


func _on_skill_cancel() -> void:
	if game.is_selecting_iron_chain():
		game.request_recast_iron_chain()
	elif game.flow_state == GameManager.FlowState.SKILL_ASSIGN_CARDS:
		game.request_cancel_card_assignment()
	elif game.flow_state == GameManager.FlowState.DECK_REORDER:
		game.request_cancel_deck_reorder()
	else:
		game.request_cancel_skill()


func _on_skill_equipment(button: Button) -> void:
	game.request_skill_select_equipment(int(button.get_meta("equipment_slot", -1)))


func _on_reselect() -> void:
	log_view.clear()
	game.request_reselect_generals()


func _on_general_selected(general_id: StringName) -> void:
	game.request_select_general(general_id)


func _on_default_generals() -> void:
	game.request_use_default_generals()


func _on_start_match() -> void:
	log_view.clear()
	game.request_start_match()


func _append_log(message: String) -> void:
	log_view.append_text("%s\n" % message)
	log_view.scroll_to_line(log_view.get_line_count())


func _build_skill_action_buttons() -> void:
	for index: int in 3:
		var button := Button.new()
		button.visible = false
		button.pressed.connect(_on_skill_pressed.bind(button))
		action_bar.add_child(button)
		skill_buttons.append(button)

	skill_confirm_button = Button.new()
	skill_confirm_button.visible = false
	skill_confirm_button.pressed.connect(_on_skill_confirm)
	action_bar.add_child(skill_confirm_button)

	skill_decline_button = Button.new()
	skill_decline_button.visible = false
	skill_decline_button.pressed.connect(_on_skill_decline)
	action_bar.add_child(skill_decline_button)

	skill_cards_confirm_button = Button.new()
	skill_cards_confirm_button.text = "确认技能代价"
	skill_cards_confirm_button.visible = false
	skill_cards_confirm_button.pressed.connect(_on_skill_cards_confirm)
	action_bar.add_child(skill_cards_confirm_button)

	skill_cancel_button = Button.new()
	skill_cancel_button.text = "取消技能"
	skill_cancel_button.visible = false
	skill_cancel_button.pressed.connect(_on_skill_cancel)
	action_bar.add_child(skill_cancel_button)

	reselect_button = Button.new()
	reselect_button.text = "重新选将"
	reselect_button.visible = false
	reselect_button.pressed.connect(_on_reselect)
	action_bar.add_child(reselect_button)

	for _index: int in 4:
		var equipment_button := Button.new()
		equipment_button.visible = false
		equipment_button.pressed.connect(_on_skill_equipment.bind(equipment_button))
		action_bar.add_child(equipment_button)
		skill_equipment_buttons.append(equipment_button)


func _build_general_selection_panel() -> void:
	general_backdrop = ColorRect.new()
	general_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	general_backdrop.color = Color(0.008, 0.012, 0.018, 0.9)
	general_backdrop.z_index = 99
	general_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(general_backdrop)

	general_panel = PanelContainer.new()
	general_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	general_panel.offset_left = 54.0
	general_panel.offset_top = 28.0
	general_panel.offset_right = -54.0
	general_panel.offset_bottom = -28.0
	general_panel.z_index = 100
	general_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.045, 0.055, 0.99)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.68, 0.48, 0.22, 0.95)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	panel_style.shadow_size = 14
	general_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(general_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	general_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "选择主公武将"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.79, 0.42))
	layout.add_child(title)

	general_summary = Label.new()
	general_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	general_summary.text = "请选择武将"
	general_summary.add_theme_font_size_override("font_size", 16)
	general_summary.add_theme_color_override("font_color", Color(0.88, 0.9, 0.92))
	layout.add_child(general_summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for definition: GeneralDefinition in GeneralFactory.all_generals():
		var skill_names: PackedStringArray = []
		var skill_descriptions: PackedStringArray = []
		for skill_id: String in definition.skill_ids:
			var skill: Skill = SkillFactory.create_skill(StringName(skill_id))
			if skill != null:
				skill_names.append("【%s】" % skill.display_name)
				skill_descriptions.append("【%s】%s\n%s" % [skill.display_name, skill.activation_text(), skill.description])
		var card_panel := PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(340.0, 154.0)
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.075, 0.09, 0.105, 1.0)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.28, 0.34, 0.38, 1.0)
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_right = 8
		card_style.corner_radius_bottom_left = 8
		card_panel.add_theme_stylebox_override("panel", card_style)
		grid.add_child(card_panel)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 8)
		card_margin.add_theme_constant_override("margin_top", 8)
		card_margin.add_theme_constant_override("margin_right", 8)
		card_margin.add_theme_constant_override("margin_bottom", 8)
		card_panel.add_child(card_margin)
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 5)
		card_margin.add_child(card_box)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.5))
		button.text = "%s · %s · %s · %d体力\n%s" % [
			definition.display_name,
			definition.gender_text(),
			definition.kingdom,
			definition.max_hp,
			" ".join(skill_names),
		]
		button.tooltip_text = "\n\n".join(skill_descriptions)
		button.pressed.connect(_on_general_selected.bind(definition.id))
		card_box.add_child(button)
		var description := Label.new()
		description.text = "\n".join(skill_descriptions)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 13)
		description.add_theme_color_override("font_color", Color(0.84, 0.87, 0.9))
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_box.add_child(description)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)

	default_generals_button = Button.new()
	default_generals_button.text = "载入默认：曹操 VS 吕布"
	default_generals_button.pressed.connect(_on_default_generals)
	footer.add_child(default_generals_button)

	start_match_button = Button.new()
	start_match_button.text = "开始对局"
	start_match_button.pressed.connect(_on_start_match)
	footer.add_child(start_match_button)


func _update_general_panel() -> void:
	if general_panel == null:
		return
	var selection_visible := game.flow_state == GameManager.FlowState.GENERAL_SELECTION
	general_backdrop.visible = selection_visible
	general_panel.visible = selection_visible
	if not general_panel.visible:
		return
	var ready: bool = game.player1.general_id != &""
	for enemy: BattlePlayer in game.enemies:
		if enemy.general_id == &"":
			ready = false
			break
	start_match_button.disabled = not ready
	if ready:
		var enemy_summary: PackedStringArray = []
		for enemy: BattlePlayer in game.enemies:
			enemy_summary.append("%s（%s）" % [enemy.general_name, enemy.kingdom])
		general_summary.text = "主公：%s（%s）  VS  %s" % [
			game.player1.general_name,
			game.player1.kingdom,
			"、".join(enemy_summary),
		]
	else:
		general_summary.text = "请选择一名武将；全部反贼会从剩余武将中随机选择"


func _update_skill_equipment_buttons(player: BattlePlayer) -> void:
	if game._ganglie_discard_active:
		for button: Button in skill_equipment_buttons:
			button.visible = false
		return
	var equipment: Array[Card] = player.all_equipment()
	var visible_index: int = 0
	for card: Card in equipment:
		if visible_index >= skill_equipment_buttons.size():
			break
		if game.pending_skill.activation_mode == Skill.ActivationMode.ACTIVE and not game.pending_skill.allows_equipment_cost():
			continue
		if (
			game.pending_skill.activation_mode == Skill.ActivationMode.VIEW_AS
			and (not game.pending_skill.allows_view_as_equipment() or not game.pending_skill.can_view_as(
				card,
				game._skill_effective_card_type,
				game,
				player
			))
		):
			continue
		var slot: int = game._equipment_slot_for_card(player, card)
		var button: Button = skill_equipment_buttons[visible_index]
		button.visible = true
		button.text = "%s装备【%s】" % [
			"取消" if card in game.pending_skill_cards else "选择",
			card.display_name,
		]
		button.set_meta("equipment_slot", slot)
		visible_index += 1
