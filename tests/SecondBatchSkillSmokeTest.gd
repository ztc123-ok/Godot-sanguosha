extends Node
## 第二批九名标准武将、统一判定、串行触发、私有牌与失去体力的确定性回归。

@onready var game: GameManager = $GameManager
@onready var p1: BattlePlayer = $GameManager/Players/Player1
@onready var p2: BattlePlayer = $GameManager/Players/Player2

var failures: Array[String] = []
var captured_judgement: JudgementContext


func _ready() -> void:
	await get_tree().process_frame
	game._action_generation += 1
	_test_factory_and_metadata()
	_test_fankui()
	_test_guicai_and_tiandu()
	_test_ganglie()
	_test_yiji()
	_test_qingguo_and_wushuang()
	_test_luoshen()
	_test_rende()
	_test_guanxing_and_kongcheng()
	_test_keji_effective_use_record()
	_test_kurou()
	_test_yingzi_and_fanjian()
	_test_second_batch_ai()
	_test_generation_reset()
	game._action_generation += 1
	if failures.is_empty():
		print("SECOND_BATCH_SKILL_SMOKE_TEST: PASS (9 additional standard generals; 25 total)")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("SECOND_BATCH_SKILL_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)


func _test_factory_and_metadata() -> void:
	var ids: Array[StringName] = GeneralFactory.all_general_ids()
	var unique: Dictionary = {}
	## 第三批新增 7 名标准武将后总数为 25；该断言随扩展后的总池更新。
	_expect(ids.size() == 25, "GeneralFactory 创建25名武将")
	for general_id: StringName in ids:
		_expect(not unique.has(general_id), "武将id唯一：%s" % general_id)
		unique[general_id] = true
		var definition: GeneralDefinition = GeneralFactory.create_general(general_id)
		_expect(definition != null, "武将定义存在：%s" % general_id)
		for skill_id: String in definition.skill_ids:
			_expect(SkillFactory.create_skill(StringName(skill_id)) != null, "技能脚本存在：%s" % skill_id)
	var hp3: Array[StringName] = [&"simayi", &"guojia", &"zhenji", &"zhugeliang", &"zhouyu"]
	for general_id: StringName in hp3:
		_expect(GeneralFactory.create_general(general_id).max_hp == 3, "%s体力上限为3" % general_id)
	var expected: Dictionary = {
		&"fankui": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"guicai": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"ganglie": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"tiandu": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"yiji": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"qingguo": [Skill.ActivationMode.VIEW_AS, Skill.UsageScope.UNLIMITED, 0, false],
		&"luoshen": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"rende": [Skill.ActivationMode.ACTIVE, Skill.UsageScope.UNLIMITED, 0, false],
		&"guanxing": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"kongcheng": [Skill.ActivationMode.MODIFIER, Skill.UsageScope.UNLIMITED, 0, true],
		&"keji": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"kurou": [Skill.ActivationMode.ACTIVE, Skill.UsageScope.UNLIMITED, 0, false],
		&"yingzi": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"fanjian": [Skill.ActivationMode.ACTIVE, Skill.UsageScope.PER_TURN, 1, false],
	}
	for skill_id: StringName in expected:
		var skill: Skill = SkillFactory.create_skill(skill_id)
		var spec: Array = expected[skill_id]
		_expect(skill.activation_mode == spec[0] and skill.usage_scope == spec[1] and skill.max_uses == spec[2] and skill.has_tag(Skill.SkillTag.LOCKED) == spec[3], "技能分类正确：%s" % skill_id)
	_expect(Skill.ActivationMode.keys().size() == 4 and Skill.SkillTag.keys() == ["LOCKED"] and Skill.UsageScope.keys().size() == 2, "未添加未使用技能类型")


func _test_fankui() -> void:
	_prepare(&"simayi", &"xiahoudun", 1)
	var source_card := PeachCard.new()
	_set_hand(p1, [])
	_set_hand(p2, [source_card])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "反馈测试")
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "反馈在伤害事件后询问")
	game.request_confirm_skill()
	_expect(game.flow_state == GameManager.FlowState.CHOOSING_OPTION and game.choice_owner == p1, "反馈由真实受伤者选择区域")
	game.request_option(0)
	_expect(source_card in p1.hand and source_card not in p2.hand, "反馈随机取得暗手牌且实体只移动一次")
	_prepare(&"simayi", &"liubei", 1)
	var weapon := QinggangSword.new(); p2.weapon = weapon; _set_hand(p2, [])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "反馈装备")
	game.request_confirm_skill(); game.request_option(0)
	_expect(p2.weapon == null and weapon in p1.hand and weapon not in game.discard_pile, "反馈可具体获得明置装备并正确走失去装备入口")
	_prepare(&"simayi", &"liubei", 1)
	var delayed := IndulgenceCard.new(); p2.add_delayed_trick(delayed); _set_hand(p2, [])
	var delayed_only := DamageContext.new(p2, p1, 1, GameManager.DamageNature.NORMAL)
	_expect(
		not p1.get_skill(&"fankui").can_trigger(delayed_only, game, p1)
		and p2.indulgence_card == delayed,
		"反馈不能获得伤害来源判定区的延时锦囊"
	)
	var no_source := DamageContext.new(null, p1, 1, GameManager.DamageNature.NORMAL)
	_expect(not p1.get_skill(&"fankui").can_trigger(no_source, game, p1), "反馈对无来源伤害安全跳过")


func _test_guicai_and_tiandu() -> void:
	_prepare(&"simayi", &"guojia")
	p2.is_ai = false
	var original := SlashCard.new(); original.suit = Card.Suit.SPADE; original.rank = 5
	var replacement := PeachCard.new(); replacement.suit = Card.Suit.HEART; replacement.rank = 7
	_set_hand(p1, [replacement])
	_set_draw_top_first([original])
	captured_judgement = null
	game._start_judgement(&"bagua", p2, Callable(self, "_capture_judgement_result"), Callable(self, "_capture_judgement_done"))
	_expect(game.flow_state == GameManager.FlowState.JUDGEMENT_REPLACE, "鬼才在判定生效前进入改判状态")
	game.request_judgement_replace(0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"tiandu", "改判后按最终牌进入天妒触发")
	game.request_confirm_skill()
	_expect(original in game.discard_pile and replacement in p2.hand and replacement not in game.discard_pile, "原判定牌弃置，天妒获得唯一最终判定牌")
	_expect(captured_judgement != null and captured_judgement.effective_card == replacement, "后续结果只读取鬼才后的最终花色点数")
	_prepare(&"simayi", &"xiahoudun")
	var kept := DodgeCard.new(); kept.suit = Card.Suit.CLUB
	_set_hand(p1, [PeachCard.new()]); _set_draw_top_first([kept])
	game._start_judgement(&"ganglie", p2, Callable(self, "_capture_judgement_result"), Callable(self, "_capture_judgement_done"))
	game.request_pass_judgement_replace()
	_expect(kept in game.discard_pile and p1.hand.size() == 1, "放弃鬼才不支付手牌且原判定正常弃置")
	_prepare(&"guojia", &"liubei", 1)
	var bagua_card := PeachCard.new(); bagua_card.suit = Card.Suit.HEART
	p1.armor = EightTrigrams.new(); _set_hand(p1, []); _set_hand(p2, [SlashCard.new()]); _set_draw_top_first([bagua_card])
	game._play_slash(p2, p1, 0); game._resolve_bagua_judgement(p1)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"tiandu", "八卦阵复用统一判定并在弃牌前触发天妒")
	game.request_confirm_skill()
	_expect(bagua_card in p1.hand and p1.hp == 3, "天妒获得八卦阵最终判定牌且八卦只响应一张闪")


func _test_ganglie() -> void:
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.is_ai = false
	var h1 := PeachCard.new(); var h2 := DodgeCard.new()
	_set_hand(p2, [h1, h2]); _set_hand(p1, [])
	var non_heart := SlashCard.new(); non_heart.suit = Card.Suit.CLUB
	_set_draw_top_first([non_heart])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈测试")
	game.request_confirm_skill()
	_expect(game.flow_state == GameManager.FlowState.CHOOSING_OPTION and game.choice_owner == p2, "非红桃刚烈由伤害来源选择")
	game.request_option(0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_CARDS and game.skill_actor == p2, "刚烈弃牌进入选择两张手牌")
	game.request_skill_toggle_hand_card(0)
	game.request_skill_toggle_hand_card(1)
	game.request_confirm_skill_cards()
	_expect(p2.hand.is_empty() and h1 in game.discard_pile and h2 in game.discard_pile, "刚烈可弃置两张手牌")
	## 伤害来源可以自行选择弃哪两张，未选中的保留
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.is_ai = false
	var keep := WineCard.new()
	_set_hand(p2, [h1, keep, h2]); _set_hand(p1, [])
	_set_draw_top_first([non_heart])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈选牌")
	game.request_confirm_skill()
	game.request_option(0)
	game.request_skill_toggle_hand_card(0)
	game.request_skill_toggle_hand_card(2)
	game.request_confirm_skill_cards()
	_expect(h1 in game.discard_pile and h2 in game.discard_pile and keep in p2.hand and p2.hand.size() == 1, "刚烈弃牌由来源选择弃哪两张")
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.is_ai = false; _set_hand(p2, [])
	var club := SlashCard.new(); club.suit = Card.Suit.CLUB
	_set_draw_top_first([club])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈强制伤害")
	game.request_confirm_skill()
	game.request_option(0)
	_expect(p2.hp == 3, "不足两张手牌时刚烈强制受到1点反伤")
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.is_ai = false; _set_hand(p2, [PeachCard.new(), DodgeCard.new()])
	var heart := SlashCard.new(); heart.suit = Card.Suit.HEART
	_set_draw_top_first([heart])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈红桃")
	game.request_confirm_skill()
	_expect(p2.hand.size() == 2 and p2.hp == 4, "刚烈红桃无后续惩罚")
	## AI 作为伤害来源时的刚烈选择：手牌充足优先弃两张低价值牌保体力，保留桃
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.hp = 4; _set_hand(p2, [SlashCard.new(), DodgeCard.new(), PeachCard.new()]); _set_hand(p1, [])
	_set_draw_top_first([non_heart])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈AI弃牌")
	game.request_confirm_skill()
	_expect(p2.hp == 4 and p2.hand.size() == 1 and p2.hand[0].card_type == Card.CardType.PEACH, "AI 手牌充足时弃两张低价值牌保体力且保留桃")
	## 杀+桃：弃牌会失去桃，AI 选择受伤保留桃
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.hp = 4; _set_hand(p2, [SlashCard.new(), PeachCard.new()]); _set_hand(p1, [])
	_set_draw_top_first([non_heart])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈AI杀桃")
	game.request_confirm_skill()
	_expect(p2.hp == 3 and p2.hand.size() == 2, "AI 杀+桃时选择受伤保留桃")
	## 杀+闪：弃牌不触及关键牌，弃两张手牌保体力
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.hp = 4; _set_hand(p2, [SlashCard.new(), DodgeCard.new()]); _set_hand(p1, [])
	_set_draw_top_first([non_heart])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈AI杀闪")
	game.request_confirm_skill()
	_expect(p2.hp == 4 and p2.hand.is_empty(), "AI 杀+闪时弃两张手牌保体力")
	## 恰好两张高价值牌时 AI 选择受伤保留好牌（血量健康时）
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.hp = 4; _set_hand(p2, [PeachCard.new(), PeachCard.new()]); _set_hand(p1, [])
	_set_draw_top_first([non_heart])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈AI保桃")
	game.request_confirm_skill()
	_expect(p2.hp == 3 and p2.hand.size() == 2, "AI 双高价值桃时选择受伤保留手牌")
	## 双桃且血量低（受伤会濒死）时：AI 受伤后用桃自救，而不是弃两张桃
	_prepare(&"xiahoudun", &"liubei", 1)
	p2.hp = 1; _set_hand(p2, [PeachCard.new(), PeachCard.new()]); _set_hand(p1, [])
	_set_draw_top_first([non_heart])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "刚烈AI自救")
	game.request_confirm_skill()
	game._perform_ai_rescue()
	_expect(p2.hp == 1 and p2.hand.size() == 1, "AI 双桃低血量时受伤后用桃自救并保留一张桃")


func _test_yiji() -> void:
	_prepare(&"guojia", &"xiahoudun", 1)
	_set_hand(p1, []); _set_hand(p2, [])
	var cards: Array[Card] = [PeachCard.new(), DodgeCard.new(), SlashCard.new(), WineCard.new()]
	_set_draw_top_first(cards)
	game._start_damage(p2, p1, 2, GameManager.DamageNature.NORMAL, Callable(), null, null, "遗计两点伤害")
	game.request_confirm_skill()
	_expect(game.flow_state == GameManager.FlowState.SKILL_ASSIGN_CARDS and game.private_cards.size() == 2, "遗计每点伤害观看两张私有牌")
	game.request_assign_private_card(0, 0); game.request_assign_private_card(1, 1); game.request_confirm_card_assignment()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "2点伤害生成第二轮遗计而非一次四张")
	game.request_confirm_skill()
	game.request_assign_private_card(0, 0); game.request_assign_private_card(1, 0); game.request_confirm_card_assignment()
	_expect(p1.hand.size() == 3 and p2.hand.size() == 1 and game.private_cards.is_empty(), "遗计支持同方和双方分配且不丢牌不复制")
	_prepare(&"guojia", &"xiahoudun", 1)
	_set_hand(p1, []); _set_draw_top_first([PeachCard.new(), DodgeCard.new()])
	game._start_damage(p2, p1, 1, GameManager.DamageNature.NORMAL, Callable(), null, null, "遗计取消")
	game.request_confirm_skill(); game.request_cancel_card_assignment()
	_expect(p1.hand.size() == 2 and game.private_cards.is_empty(), "遗计取消调整时两张牌归技能拥有者，不丢失不复制")


func _test_qingguo_and_wushuang() -> void:
	_prepare(&"zhenji", &"lvbu", 1)
	var black1 := PeachCard.new(); black1.suit = Card.Suit.SPADE
	var black2 := WineCard.new(); black2.suit = Card.Suit.CLUB
	_set_hand(p1, [black1, black2]); _set_hand(p2, [SlashCard.new()])
	game._play_slash(p2, p1, 0)
	game.request_begin_skill(&"qingguo"); game.request_skill_toggle_hand_card(0)
	_expect(game.response_received_count == 1 and game.flow_state == GameManager.FlowState.MULTI_RESPONSE, "倾国一次只为无双提供一张闪")
	game.request_begin_skill(&"qingguo"); game.request_skill_toggle_hand_card(0)
	_expect(p1.hp == 3 and p1.hand.is_empty(), "两张黑手牌可连续倾国抵消无双杀")
	_prepare(&"zhenji", &"lvbu", 1)
	var red := PeachCard.new(); red.suit = Card.Suit.HEART
	var black_armor := EightTrigrams.new(); black_armor.suit = Card.Suit.SPADE
	_set_hand(p1, [red]); p1.armor = black_armor
	game.pending_target = p1; game._response_card_type = Card.CardType.DODGE; game.flow_state = GameManager.FlowState.AOE_RESPONSE
	_expect(not game.can_use_skill(p1, p1.get_skill(&"qingguo")), "倾国拒绝红手牌和黑色装备牌")


func _test_luoshen() -> void:
	_prepare(&"zhenji", &"xiahoudun")
	var black := SlashCard.new(); black.suit = Card.Suit.SPADE
	var red := PeachCard.new(); red.suit = Card.Suit.HEART
	_set_hand(p1, []); _set_draw_top_first([black, red, DodgeCard.new(), WineCard.new()])
	game.phase = GameManager.Phase.START; game.flow_state = GameManager.FlowState.IDLE
	game._enqueue_triggers(&"start_phase", RefCounted.new(), [p1], Callable())
	game.request_confirm_skill()
	_expect(black in p1.hand and game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "洛神黑色判定牌获得后可继续")
	game.request_confirm_skill()
	_expect(red in game.discard_pile and p1.luoshen_cards_gained == 1, "洛神红色终止且黑牌获得数正确")
	_prepare(&"zhenji", &"xiahoudun")
	var another_black := DodgeCard.new(); another_black.suit = Card.Suit.CLUB
	_set_draw_top_first([another_black])
	game._enqueue_triggers(&"start_phase", RefCounted.new(), [p1], Callable())
	game.request_confirm_skill(); game.request_decline_skill()
	_expect(another_black in p1.hand, "洛神黑色后可主动停止且不额外翻牌")


func _test_rende() -> void:
	_prepare(&"liubei", &"xiahoudun")
	p1.hp = 3; p1.hp_changed.emit(p1.hp, p1.max_hp)
	var a := SlashCard.new(); var b := DodgeCard.new(); _set_hand(p1, [a, b]); _set_hand(p2, [])
	## 多人化后仁德需要先选择接收者（此处固定选 Player2）。
	game.request_begin_skill(&"rende"); game.request_skill_toggle_hand_card(0); game.request_confirm_skill_cards(); game.request_skill_target(1)
	game.request_begin_skill(&"rende"); game.request_skill_toggle_hand_card(0); game.request_confirm_skill_cards(); game.request_skill_target(1)
	_expect(p2.hand.size() == 2 and p1.hp == 4 and p1.rende_recovery_consumed, "仁德可多次交牌且累计两张仅回复一次")
	var c := PeachCard.new(); p1.add_card(c); p1.hp = 3
	game.request_begin_skill(&"rende"); game.request_skill_toggle_hand_card(0); game.request_confirm_skill_cards(); game.request_skill_target(1)
	_expect(p1.hp == 3, "仁德回复机会消耗后本阶段不再次回复")
	var retained := WineCard.new(); p1.add_card(retained)
	game.request_begin_skill(&"rende"); game.request_skill_toggle_hand_card(0); game.request_cancel_skill()
	_expect(retained in p1.hand, "取消仁德不移动牌")


func _test_guanxing_and_kongcheng() -> void:
	_prepare(&"zhugeliang", &"xiahoudun")
	var first := SlashCard.new(); var second := PeachCard.new(); var rest := DodgeCard.new()
	_set_draw_top_first([first, second, rest])
	game._begin_guanxing(p1, Callable())
	game.request_confirm_deck_reorder([1])
	_expect(game._draw_one_from_pile() == second and game.draw_pile.front() == first, "观星支持1张置顶且置顶/置底顺序正确")
	_prepare(&"zhugeliang", &"xiahoudun")
	var zero_a := SlashCard.new(); var zero_b := PeachCard.new(); _set_draw_top_first([zero_a, zero_b])
	game._begin_guanxing(p1, Callable()); game.request_confirm_deck_reorder([], [1, 0])
	_expect(game.draw_pile[0] == zero_b and game.draw_pile[1] == zero_a, "观星支持0张置顶并按指定顺序置底")
	_prepare(&"zhugeliang", &"xiahoudun")
	var two_a := SlashCard.new(); var two_b := PeachCard.new(); _set_draw_top_first([two_a, two_b])
	game._begin_guanxing(p1, Callable()); game.request_confirm_deck_reorder([1, 0], [])
	_expect(game._draw_one_from_pile() == two_b and game._draw_one_from_pile() == two_a, "观星支持2张置顶并调整先后顺序")
	_prepare(&"xiahoudun", &"zhugeliang")
	_set_hand(p2, []); _set_hand(p1, [SlashCard.new(), DuelCard.new(), BarbarianInvasionCard.new()])
	_expect(not game.can_slash_target(p1, p2), "空城拒绝实体与虚拟杀的统一目标入口")
	_expect(not game._is_valid_trick_target(p1.hand[1], p1, p2), "空城拒绝决斗目标")
	_expect(p1.hand[2].card_type == Card.CardType.BARBARIAN_INVASION, "空城不限制AOE")
	p2.add_card(DodgeCard.new())
	_expect(game.can_slash_target(p1, p2), "空城仅在目标建立时检查当前空手牌状态")


func _test_keji_effective_use_record() -> void:
	_prepare(&"lvmeng", &"xiahoudun")
	var keji: Skill = p1.get_skill(&"keji")
	_expect(keji.can_trigger(RefCounted.new(), game, p1), "未使用杀时克己可触发")
	game._record_effective_card_action(p1, Card.CardType.SLASH)
	_expect(not keji.can_trigger(RefCounted.new(), game, p1), "实体或虚拟有效杀记账后克己不可触发")
	p1.reset_turn_flags()
	game.request_end_play_phase()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "结束出牌阶段串行询问克己")
	game.request_confirm_skill()
	_expect(game.phase == GameManager.Phase.END and game.current_player_index == 1, "克己跳过弃牌且只进入一次结束阶段")
	_prepare(&"lvmeng", &"liubei")
	p1.weapon = SerpentSpear.new(); _set_hand(p1, [PeachCard.new(), WineCard.new()])
	game._duel_responder = p1; game._duel_other = p2; game._duel_use_context = SkillUseContext.new(p2, [], Card.CardType.DUEL, null, p1, true, "决斗记账")
	game._response_card_type = Card.CardType.SLASH; game.flow_state = GameManager.FlowState.DUEL_RESPONSE
	game._use_serpent_spear(p1)
	_expect(p1.used_effective_card(Card.CardType.SLASH), "丈八蛇矛在自己出牌阶段内打出的有效杀纳入克己记账")


func _test_kurou() -> void:
	_prepare(&"huanggai", &"xiahoudun")
	p1.hp = 2; _set_hand(p1, []); _set_draw_top_first([SlashCard.new(), DodgeCard.new()])
	game.request_begin_skill(&"kurou")
	_expect(p1.hp == 1 and p1.hand.size() == 2 and game._last_damage_context == null, "苦肉失去体力不创建DamageContext并摸两张")
	_prepare(&"huanggai", &"xiahoudun")
	p1.hp = 1; var rescue := PeachCard.new(); _set_hand(p1, [rescue]); _set_draw_top_first([SlashCard.new(), DodgeCard.new()])
	game.request_begin_skill(&"kurou")
	_expect(game.flow_state == GameManager.FlowState.DYING_RESCUE, "苦肉先完整进入濒死流程")
	game.request_rescue(Card.CardType.PEACH)
	_expect(p1.hp == 1 and p1.hand.size() == 2, "苦肉脱离濒死后才摸两张")
	_prepare(&"huanggai", &"xiahoudun")
	p1.hp = 1; _set_hand(p1, []); var remaining_before: int = 2; _set_draw_top_first([SlashCard.new(), DodgeCard.new()])
	game.request_begin_skill(&"kurou"); game.request_give_up_rescue()
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER and game.draw_pile.size() == remaining_before, "苦肉死亡或游戏结束时不摸牌")


func _test_yingzi_and_fanjian() -> void:
	_prepare(&"zhouyu", &"xiahoudun")
	_set_hand(p1, []); _set_draw_top_first([SlashCard.new(), DodgeCard.new(), PeachCard.new()])
	game._finish_judgement_phase()
	game.request_confirm_skill()
	_expect(p1.hand.size() == 3 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "英姿通过DrawContext令正常摸牌数+1")
	_prepare(&"zhouyu", &"xiahoudun")
	p2.is_ai = false
	var spade := SlashCard.new(); spade.suit = Card.Suit.SPADE
	_set_hand(p1, [spade]); _set_hand(p2, [])
	game.request_begin_skill(&"fanjian")
	game.request_skill_target(1)
	_expect(game.flow_state == GameManager.FlowState.CHOOSING_SUIT and p1.hand.size() == 1, "反间先选花色且未提前移动或公开牌")
	game.request_choose_suit(0)
	_expect(spade in p2.hand and p2.hp == 4, "反间花色相同：目标获得牌且无伤害")
	_expect(not game.can_use_skill(p1, p1.get_skill(&"fanjian")), "反间每回合限一次")
	_prepare(&"zhouyu", &"xiahoudun")
	p2.is_ai = false
	var heart := PeachCard.new(); heart.suit = Card.Suit.HEART
	_set_hand(p1, [heart]); _set_hand(p2, [])
	game.request_begin_skill(&"fanjian"); game.request_skill_target(1); game.request_choose_suit(0)
	_expect(heart in p2.hand and p2.hp == 3, "反间花色不同：先移动牌再经过统一伤害流程")


func _test_generation_reset() -> void:
	_prepare(&"guojia", &"zhugeliang")
	game.private_cards = [SlashCard.new()]
	game.private_card_owner = p1
	game._trigger_queue.append(TriggerEntry.new(p1, p1.get_skill(&"yiji"), DamageContext.new(p2, p1, 1), &"after_damage"))
	var previous: int = game._action_generation
	game.begin_general_selection(false)
	_expect(game._action_generation > previous and game.private_cards.is_empty() and game._trigger_queue.is_empty() and game.judgement_context == null, "重新选将清空第二批上下文并使旧generation失效")


func _test_second_batch_ai() -> void:
	_prepare(&"liubei", &"zhugeliang", 1)
	var top_a := SlashCard.new(); var top_b := PeachCard.new(); _set_draw_top_first([top_a, top_b])
	game.phase = GameManager.Phase.START; game.flow_state = GameManager.FlowState.IDLE
	game._enqueue_triggers(&"start_phase", RefCounted.new(), [p2], Callable())
	game._perform_ai_skill_confirm(); game._perform_ai_confirm_deck_reorder()
	_expect(game.private_cards.is_empty() and game.private_card_owner == null, "AI观星通过相同入口完成且私有区结算后清空")
	_prepare(&"lvbu", &"zhenji")
	var black1 := PeachCard.new(); black1.suit = Card.Suit.SPADE
	var black2 := WineCard.new(); black2.suit = Card.Suit.CLUB
	_set_hand(p1, [SlashCard.new()]); _set_hand(p2, [black1, black2])
	game._play_slash(p1, p2, 0); game._perform_ai_response(); game._perform_ai_response()
	_expect(p2.hp == 3 and p2.hand.is_empty(), "AI倾国能完成无双要求的两张闪响应")
	_prepare(&"liubei", &"huanggai", 1)
	p2.hp = 2; _set_hand(p2, []); _set_draw_top_first([DodgeCard.new(), SlashCard.new()])
	game._perform_ai_play()
	_expect(p2.hp == 1 and p2.kurou_ai_uses_this_turn == 1, "AI苦肉每个行动循环有边界且不死循环")
	_prepare(&"liubei", &"simayi")
	var bad := SlashCard.new(); bad.suit = Card.Suit.SPADE
	var good := PeachCard.new(); good.suit = Card.Suit.HEART
	_set_hand(p2, [good]); _set_draw_top_first([bad])
	game._start_judgement(&"bagua", p2, Callable(self, "_capture_judgement_result"), Callable(self, "_capture_judgement_done"))
	game._perform_ai_guicai()
	_expect(good in game.discard_pile and bad in game.discard_pile, "AI鬼才只在改善自己判定时通过统一改判入口支付实体手牌")


func _capture_judgement_result(context: JudgementContext) -> void:
	captured_judgement = context


func _capture_judgement_done(context: JudgementContext) -> void:
	captured_judgement = context


func _prepare(player1_general: StringName, player2_general: StringName, active_index: int = 0) -> void:
	game._action_generation += 1
	p1.is_ai = false; p2.is_ai = true
	_expect(game.setup_generals(player1_general, player2_general), "测试武将配置合法：%s/%s" % [player1_general, player2_general])
	game.start_match(false)
	game._action_generation += 1
	game.current_player_index = active_index
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.winner = null
	game.processing_cards.clear(); game.discard_pile.clear(); game._reset_transient_contexts(); game._clear_skill_context()
	p1.reset_turn_flags(); p2.reset_turn_flags()


func _set_hand(player: BattlePlayer, cards: Array) -> void:
	player.hand.clear()
	for card: Card in cards: player.hand.append(card)
	player.hand_changed.emit()


func _set_draw_top_first(cards: Array) -> void:
	game.draw_pile.clear()
	for index: int in range(cards.size() - 1, -1, -1): game.draw_pile.append(cards[index])


func _expect(condition: bool, description: String) -> void:
	if not condition: failures.append(description)
