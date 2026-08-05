extends Node
## 武将选择、九名武将、虚拟牌、处理区、伤害上下文与 AI 的确定性测试。

@onready var game: GameManager = $GameManager
@onready var p1: BattlePlayer = $GameManager/Players/Player1
@onready var p2: BattlePlayer = $GameManager/Players/Player2

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	game._action_generation += 1

	_test_general_factory_and_skill_metadata()
	_test_general_selection_and_start()
	_test_jianxiong_processing_card()
	_test_tuxi_draw_replacement()
	_test_luoyi_damage_modifier()
	_test_wusheng_view_as()
	_test_wusheng_ice_sword_with_horse_cost()
	_test_paoxiao_slash_limit()
	_test_longdan_both_directions()
	_test_qixi_full_trick_pipeline()
	_test_zhiheng_multi_cost()
	_test_wushuang_slash_responses()
	_test_wushuang_duel_responses()
	_test_virtual_card_limits_and_ai()
	_test_ai_triggered_skills()

	game._action_generation += 1
	if failures.is_empty():
		print("SKILL_SMOKE_TEST: PASS (general selection + 9 generals + skill pipeline)")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("SKILL_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)


func _test_general_factory_and_skill_metadata() -> void:
	var all_ids: Array[StringName] = GeneralFactory.all_general_ids()
	var ids: Array[StringName] = []
	for general_id: StringName in all_ids.slice(0, 9):
		ids.append(general_id)
	var unique: Dictionary = {}
	_expect(ids.size() == 9 and all_ids.size() >= 9, "GeneralFactory 保留完整的首批九名武将")
	for general_id: StringName in ids:
		var definition: GeneralDefinition = GeneralFactory.create_general(general_id)
		_expect(definition != null, "可创建武将 %s" % general_id)
		_expect(not unique.has(general_id), "武将 id 唯一：%s" % general_id)
		unique[general_id] = true
		_expect(definition.max_hp == 4, "%s 的体力上限为4" % definition.display_name)
		_expect(definition.skill_ids.size() == 1, "%s 绑定一个独立技能" % definition.display_name)
		_expect(
			SkillFactory.create_skill(StringName(definition.skill_ids[0])) != null,
			"%s 的技能脚本可创建" % definition.display_name
		)

	var expected: Dictionary = {
		&"jianxiong": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"tuxi": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"luoyi": [Skill.ActivationMode.TRIGGERED, Skill.UsageScope.UNLIMITED, 0, false],
		&"wusheng": [Skill.ActivationMode.VIEW_AS, Skill.UsageScope.UNLIMITED, 0, false],
		&"paoxiao": [Skill.ActivationMode.MODIFIER, Skill.UsageScope.UNLIMITED, 0, true],
		&"longdan": [Skill.ActivationMode.VIEW_AS, Skill.UsageScope.UNLIMITED, 0, false],
		&"qixi": [Skill.ActivationMode.VIEW_AS, Skill.UsageScope.UNLIMITED, 0, false],
		&"zhiheng": [Skill.ActivationMode.ACTIVE, Skill.UsageScope.PER_TURN, 1, false],
		&"wushuang": [Skill.ActivationMode.MODIFIER, Skill.UsageScope.UNLIMITED, 0, true],
	}
	for skill_id: StringName in expected:
		var skill: Skill = SkillFactory.create_skill(skill_id)
		var spec: Array = expected[skill_id]
		_expect(skill.activation_mode == spec[0], "%s activation_mode 正确" % skill.display_name)
		_expect(skill.usage_scope == spec[1], "%s usage_scope 正确" % skill.display_name)
		_expect(skill.max_uses == spec[2], "%s max_uses 正确" % skill.display_name)
		_expect(skill.has_tag(Skill.SkillTag.LOCKED) == spec[3], "%s LOCKED 标签正确" % skill.display_name)
	_expect(Skill.ActivationMode.keys().size() == 4, "只定义首批实际需要的四种发动方式")
	_expect(Skill.SkillTag.keys() == ["LOCKED"], "技能标签只包含 LOCKED")
	_expect(Skill.UsageScope.keys().size() == 2, "次数范围只包含 UNLIMITED/PER_TURN")


func _test_general_selection_and_start() -> void:
	var old_generation: int = game._action_generation
	game.begin_general_selection(false)
	_expect(game.flow_state == GameManager.FlowState.GENERAL_SELECTION, "开局先进入选将状态")
	_expect(p1.hand.is_empty() and p2.hand.is_empty(), "选将阶段不发初始手牌")
	_expect(p1.general_id == &"" and p2.general_id == &"", "重新选将清空旧武将")
	_expect(game._action_generation > old_generation, "重新选将使旧 generation 失效")

	_expect(game.setup_generals(&"caocao", &"lvbu"), "公开 setup_generals 接受确定性配置")
	game.start_match(false)
	_expect(p1.role_name == "主公" and p2.role_name == "反贼", "身份字段不被武将覆盖")
	_expect(p1.general_name == "曹操" and p2.general_name == "吕布", "武将字段独立保存")
	_expect(p1.hp == 4 and p2.hp == 4, "体力取武将上限")
	_expect(p1.hand.size() == 4 and p2.hand.size() == 4, "指定武将后双方各摸四张起始牌")


func _test_jianxiong_processing_card() -> void:
	_prepare_play(&"caocao", &"zhangfei", 1)
	var slash := SlashCard.new()
	_set_hand(p2, [slash])
	_set_hand(p1, [])
	game._play_slash(p2, p1, 0)
	game.request_pass_response()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "受到实体【杀】伤害后询问【奸雄】")
	_expect(game.is_card_in_processing(slash), "伤害完成时来源实体牌仍在处理区")
	game.request_confirm_skill()
	_expect(slash in p1.hand, "发动【奸雄】获得来源实体牌")
	_expect(not game.is_card_in_processing(slash) and slash not in game.discard_pile, "被获得的牌不重复弃置")
	_expect(not game._claim_processing_card(p2, slash), "同一实体牌不能被重复获得")

	_prepare_play(&"caocao", &"zhangfei", 1)
	var declined_slash := SlashCard.new()
	_set_hand(p2, [declined_slash])
	_set_hand(p1, [])
	game._play_slash(p2, p1, 0)
	game.request_pass_response()
	game.request_decline_skill()
	_expect(declined_slash in game.discard_pile, "放弃【奸雄】后来源牌进入弃牌堆")

	_prepare_play(&"caocao", &"zhangfei", 1)
	var fire := FireAttackCard.new()
	game._move_card_to_processing(fire)
	var chain_context := DamageContext.new(p2, p1, 1, GameManager.DamageNature.FIRE, null, Card.CardType.FIRE_ATTACK, "连环", true)
	var jianxiong: Skill = p1.get_skill(&"jianxiong")
	_expect(not jianxiong.can_trigger(chain_context, game, p1), "连环传播无独立实体牌时不触发重复获得")

	## 回归：张飞【丈八蛇矛】两张手牌当【杀】命中曹操，奸雄应获得全部两张实体牌
	_prepare_play(&"caocao", &"zhangfei", 1)
	p2.weapon = SerpentSpear.new()
	var spear_a := PeachCard.new()
	var spear_b := WineCard.new()
	_set_hand(p2, [spear_a, spear_b])
	_set_hand(p1, [])
	game._use_serpent_spear(p2)
	game.request_pass_response()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill != null and game.pending_skill.id == &"jianxiong", "丈八蛇矛双牌杀伤害后询问奸雄")
	game.request_confirm_skill()
	_expect(spear_a in p1.hand and spear_b in p1.hand and p1.hand.size() == 2, "奸雄获得丈八蛇矛造成的全部两张实体牌")

	## 回归：曹操判定区【闪电】命中，奸雄可获得造成伤害的闪电牌而非进入弃牌堆
	_prepare_play(&"caocao", &"liubei", 0)
	var lightning := LightningCard.new()
	p1.add_delayed_trick(lightning)
	_set_hand(p1, []); _set_hand(p2, [])
	var spade_five := SlashCard.new(); spade_five.suit = Card.Suit.SPADE; spade_five.rank = 5
	game.draw_pile = [spade_five]
	game._begin_judgement_phase()
	game._pass_nullification(p2)
	game._pass_nullification(p1)
	var guard: int = 0
	while guard < 20 and game.flow_state not in [GameManager.FlowState.SKILL_CONFIRM, GameManager.FlowState.GAME_OVER, GameManager.FlowState.PLAY_ACTIVE]:
		guard += 1
		if game.flow_state == GameManager.FlowState.DYING_RESCUE and game.rescue_actor != null and game.rescue_actor.is_ai:
			game._perform_ai_rescue()
		elif game.flow_state == GameManager.FlowState.DYING_RESCUE and game.rescue_actor == p1:
			game.request_give_up_rescue()
		await get_tree().create_timer(0.2).timeout
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill != null and game.pending_skill.id == &"jianxiong", "闪电命中伤害后询问奸雄")
	game.request_confirm_skill()
	_expect(lightning in p1.hand and lightning not in game.discard_pile, "奸雄获得造成伤害的闪电牌")


func _test_tuxi_draw_replacement() -> void:
	_prepare_play(&"zhangliao", &"zhangfei")
	_set_hand(p1, [])
	_set_hand(p2, [PeachCard.new()])
	_set_draw_pile([SlashCard.new(), DodgeCard.new()])
	game._finish_judgement_phase()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "对手有手牌时摸牌阶段询问【突袭】")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1 and p2.hand.is_empty(), "【突袭】放弃正常摸牌并只获得对手一张暗牌")

	## 【突袭】获得陆逊最后一张手牌后，须先结算【连营】，再进入出牌阶段。
	_prepare_play(&"zhangliao", &"luxun")
	p2.is_ai = false
	var stolen := PeachCard.new()
	var lianying_draw := DodgeCard.new()
	_set_hand(p1, [])
	_set_hand(p2, [stolen])
	_set_draw_pile([lianying_draw])
	game._finish_judgement_phase()
	game.request_confirm_skill()
	_expect(
		stolen in p1.hand
		and p2.hand.is_empty()
		and game.flow_state == GameManager.FlowState.SKILL_CONFIRM
		and game.pending_skill != null
		and game.pending_skill.id == &"lianying",
		"张辽突袭获得陆逊最后手牌后立即询问连营"
	)
	game.request_confirm_skill()
	_expect(
		lianying_draw in p2.hand
		and game.flow_state == GameManager.FlowState.PLAY_ACTIVE,
		"陆逊连营摸牌后突袭结算继续进入张辽出牌阶段"
	)

	_prepare_play(&"zhangliao", &"zhangfei")
	_set_hand(p1, [])
	_set_hand(p2, [])
	_set_draw_pile([SlashCard.new(), DodgeCard.new()])
	game._finish_judgement_phase()
	_expect(p1.hand.size() == 2 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "对手无手牌时【突袭】不可发动并正常摸二")


func _test_luoyi_damage_modifier() -> void:
	_prepare_play(&"xuchu", &"zhangfei")
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [])
	_set_draw_pile([PeachCard.new()])
	game._finish_judgement_phase()
	game.request_confirm_skill()
	_expect(p1.hand.size() == 2 and p1.luoyi_active, "【裸衣】少摸一张并设置独立本回合标记")
	var slash_index: int = p1.find_card(Card.CardType.SLASH)
	game.request_card_on_target(slash_index, 1)
	game._perform_ai_response()
	_expect(p2.hp == 2, "【裸衣】令本回合【杀】伤害+1")
	p1.reset_turn_flags()
	_expect(not p1.luoyi_active, "【裸衣】在下回合重置")

	_prepare_play(&"xuchu", &"zhangfei")
	p1.luoyi_active = true
	_set_hand(p1, [DuelCard.new()])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	game._perform_ai_response()
	_expect(p2.hp == 2, "【裸衣】令自己使用【决斗】造成的伤害+1")


func _test_wusheng_view_as() -> void:
	_prepare_play(&"guanyu", &"zhangfei")
	var red_cost := PeachCard.new()
	red_cost.suit = Card.Suit.HEART
	_set_hand(p1, [red_cost])
	_set_hand(p2, [])
	game.request_begin_skill(&"wusheng")
	game.request_skill_toggle_hand_card(0)
	game.request_skill_target(1)
	game._perform_ai_response()
	_expect(p2.hp == 3 and red_cost in game.discard_pile, "红色手牌经【武圣】当【杀】主动使用")

	_prepare_play(&"guanyu", &"zhangfei")
	var red_lion := SilverLion.new()
	red_lion.suit = Card.Suit.HEART
	p1.armor = red_lion
	p1.hp = 3
	_set_hand(p1, [])
	_set_hand(p2, [])
	game.request_begin_skill(&"wusheng")
	game.request_skill_select_equipment(Equipment.Slot.ARMOR)
	game.request_skill_target(1)
	game._perform_ai_response()
	_expect(p1.armor == null and p1.hp == 4, "红色装备作【武圣】代价时走统一失去装备入口")

	_prepare_play(&"guanyu", &"zhangfei")
	var black_cost := PeachCard.new()
	black_cost.suit = Card.Suit.SPADE
	_set_hand(p1, [black_cost])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"wusheng")), "黑牌不能通过【武圣】转化")

	_prepare_play(&"guanyu", &"zhangfei", 1)
	var response_cost := PeachCard.new()
	response_cost.suit = Card.Suit.DIAMOND
	_set_hand(p1, [response_cost])
	game._duel_responder = p1
	game._duel_other = p2
	game._duel_use_context = SkillUseContext.new(p2, [], Card.CardType.DUEL, null, p1, true, "测试决斗")
	game._response_card_type = Card.CardType.SLASH
	game.response_required_count = 1
	game.response_received_count = 0
	game.flow_state = GameManager.FlowState.DUEL_RESPONSE
	game.request_begin_skill(&"wusheng")
	game.request_skill_toggle_hand_card(0)
	_expect(game._duel_responder == p2, "【武圣】支持【决斗】中的【杀】响应")

	_prepare_play(&"guanyu", &"zhangfei", 1)
	var aoe_cost := PeachCard.new()
	aoe_cost.suit = Card.Suit.HEART
	_set_hand(p1, [aoe_cost])
	game.pending_target = p1
	game._response_card_type = Card.CardType.SLASH
	game.flow_state = GameManager.FlowState.AOE_RESPONSE
	game.request_begin_skill(&"wusheng")
	game.request_skill_toggle_hand_card(0)
	_expect(p1.hand.is_empty(), "【武圣】支持【南蛮入侵】所需的【杀】响应")


func _test_wusheng_ice_sword_with_horse_cost() -> void:
	_prepare_play(&"guanyu", &"zhangfei")
	var ice_sword := IceSword.new()
	var red_horse := DefensiveHorse.new()
	red_horse.suit = Card.Suit.HEART
	var only_target_card := PeachCard.new()
	p1.weapon = ice_sword
	p1.horse_plus = red_horse
	_set_hand(p1, [])
	_set_hand(p2, [only_target_card])

	game.request_begin_skill(&"wusheng")
	game.request_skill_select_equipment(Equipment.Slot.HORSE_PLUS)
	game.request_skill_target(1)
	game._perform_ai_response()
	_expect(
		game.flow_state == GameManager.FlowState.CHOOSING_OPTION
		and game.choice_owner == p1,
		"红色+1马经【武圣】当【杀】造成伤害前仍可发动【寒冰剑】"
	)
	game.request_option(0)
	_expect(
		p2.hp == 4
		and p2.hand.is_empty()
		and p1.weapon == ice_sword
		and p1.horse_plus == null
		and red_horse in game.discard_pile,
		"【寒冰剑】防止武圣虚拟杀伤害，目标仅一张牌时仍依次弃置并完成结算"
	)


func _test_paoxiao_slash_limit() -> void:
	_prepare_play(&"zhangfei", &"zhangliao")
	_set_hand(p1, [SlashCard.new(), SlashCard.new()])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(p2.hp == 2 and p1.hand.is_empty(), "【咆哮】允许同一出牌阶段使用两张【杀】")

	_prepare_play(&"zhangfei", &"zhangliao")
	p2.horse_plus = DefensiveHorse.new()
	_set_hand(p1, [SlashCard.new()])
	_expect(not game.can_use_slash_in_play(p1), "【咆哮】不绕过距离限制")


func _test_longdan_both_directions() -> void:
	_prepare_play(&"zhaoyun", &"zhangfei")
	_set_hand(p1, [DodgeCard.new()])
	_set_hand(p2, [])
	game.request_begin_skill(&"longdan")
	game.request_skill_toggle_hand_card(0)
	game.request_skill_target(1)
	game._perform_ai_response()
	_expect(p2.hp == 3, "【龙胆】将【闪】当【杀】主动使用")

	_prepare_play(&"zhaoyun", &"zhangfei", 1)
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [SlashCard.new()])
	game._play_slash(p2, p1, 0)
	game.request_begin_skill(&"longdan")
	game.request_skill_toggle_hand_card(0)
	_expect(p1.hp == 4 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "AI 回合中由真实响应者用【龙胆】将【杀】当【闪】")

	_prepare_play(&"zhaoyun", &"zhangfei", 1)
	_set_hand(p1, [DodgeCard.new()])
	game._duel_responder = p1
	game._duel_other = p2
	game._duel_use_context = SkillUseContext.new(p2, [], Card.CardType.DUEL, null, p1, true, "测试决斗")
	game._response_card_type = Card.CardType.SLASH
	game.response_required_count = 1
	game.flow_state = GameManager.FlowState.DUEL_RESPONSE
	game.request_begin_skill(&"longdan")
	game.request_skill_toggle_hand_card(0)
	_expect(game._duel_responder == p2, "【龙胆】将【闪】当【杀】用于决斗响应")


func _test_qixi_full_trick_pipeline() -> void:
	_prepare_play(&"ganning", &"zhangfei")
	var black_cost := PeachCard.new()
	black_cost.suit = Card.Suit.CLUB
	_set_hand(p1, [black_cost])
	_set_hand(p2, [DodgeCard.new()])
	game.request_begin_skill(&"qixi")
	game.request_skill_toggle_hand_card(0)
	game.request_skill_target(1)
	_expect(game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE, "【奇袭】进入原【过河拆桥】无懈链")
	_pass_nullification_chain()
	_expect(p2.hand.is_empty() and black_cost in game.discard_pile, "【奇袭】复用过河拆桥完整弃置结算")

	_prepare_play(&"ganning", &"zhangfei")
	var red_cost := PeachCard.new()
	red_cost.suit = Card.Suit.HEART
	_set_hand(p1, [red_cost])
	_set_hand(p2, [DodgeCard.new()])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"qixi")), "红牌不能用于【奇袭】")

	_prepare_play(&"ganning", &"zhangfei")
	var black_lion := SilverLion.new()
	black_lion.suit = Card.Suit.SPADE
	p1.armor = black_lion
	p1.hp = 3
	_set_hand(p1, [])
	_set_hand(p2, [DodgeCard.new()])
	game.request_begin_skill(&"qixi")
	game.request_skill_select_equipment(Equipment.Slot.ARMOR)
	game.request_skill_target(1)
	_pass_nullification_chain()
	_expect(p1.armor == null and p1.hp == 4, "【奇袭】装备代价正确触发白银狮子离场")


func _test_zhiheng_multi_cost() -> void:
	_prepare_play(&"sunquan", &"zhangfei")
	var first := WineCard.new()
	var second := SlashCard.new()
	var weapon := Crossbow.new()
	_set_hand(p1, [first, second])
	p1.weapon = weapon
	_set_draw_pile([PeachCard.new(), DodgeCard.new()])
	game.request_begin_skill(&"zhiheng")
	game.request_skill_toggle_hand_card(0)
	game.request_skill_select_equipment(Equipment.Slot.WEAPON)
	_expect(p1.hand.size() == 2 and p1.weapon == weapon, "【制衡】确认前不支付代价")
	game.request_confirm_skill_cards()
	var zhiheng: Skill = p1.get_skill(&"zhiheng")
	_expect(p1.hand.size() == 3 and p1.weapon == null, "【制衡】弃二摸二且支持手牌与装备多选")
	_expect(p1.skill_use_count(zhiheng) == 1, "【制衡】记录每回合一次")
	_expect(not game.can_use_skill(p1, zhiheng), "【制衡】同一回合不能再次发动")
	p1.reset_turn_flags()
	_expect(p1.can_pay_skill_usage(zhiheng), "新回合重置【制衡】次数")

	_prepare_play(&"sunquan", &"zhangfei")
	var retained := PeachCard.new()
	_set_hand(p1, [retained])
	game.request_begin_skill(&"zhiheng")
	game.request_skill_toggle_hand_card(0)
	game.request_cancel_skill()
	_expect(retained in p1.hand and p1.skill_use_count(p1.get_skill(&"zhiheng")) == 0, "取消【制衡】不支付代价也不计次数")


func _test_wushuang_slash_responses() -> void:
	_prepare_play(&"lvbu", &"zhangfei")
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	_expect(game.flow_state == GameManager.FlowState.MULTI_RESPONSE and game.response_required_count == 2, "【无双】【杀】要求两张【闪】")
	game._perform_ai_response()
	_expect(p2.hp == 3, "【无双】【杀】零张闪时造成一次伤害")

	_prepare_play(&"lvbu", &"zhangfei")
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [DodgeCard.new()])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(game.response_received_count == 1 and p2.hp == 4, "一张【闪】只记录 1/2，不提前结算")
	game._perform_ai_response()
	_expect(p2.hp == 3, "第二张【闪】不足时【无双】【杀】仍命中且只伤害一次")

	_prepare_play(&"lvbu", &"zhangfei")
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [DodgeCard.new(), DodgeCard.new()])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	game._perform_ai_response()
	_expect(p2.hp == 4 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "两张【闪】才抵消【无双】【杀】")

	_prepare_play(&"lvbu", &"zhangfei")
	p2.armor = EightTrigrams.new()
	var red_judgement := PeachCard.new()
	red_judgement.suit = Card.Suit.HEART
	_set_draw_pile([red_judgement])
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(game.response_received_count == 1 and game.flow_state == GameManager.FlowState.MULTI_RESPONSE, "八卦阵一次成功判定只计一张【闪】")


func _test_wushuang_duel_responses() -> void:
	_prepare_play(&"lvbu", &"zhangfei")
	_set_hand(p1, [DuelCard.new(), SlashCard.new()])
	_set_hand(p2, [SlashCard.new(), SlashCard.new()])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	_expect(game.response_required_count == 2 and game._duel_responder == p2, "吕布发起决斗时对手每轮需两张【杀】")
	game._perform_ai_response()
	_expect(game.response_received_count == 1, "无双决斗第一张【杀】只累计数量")
	game._perform_ai_response()
	_expect(game._duel_responder == p1 and game.response_required_count == 1, "吕布自己每轮只需要一张【杀】")
	game.request_response_card()
	_expect(game._duel_responder == p2 and game.response_required_count == 2, "轮回对手后重新要求两张【杀】")
	game._perform_ai_response()
	_expect(p2.hp == 3, "对手后续不足两张【杀】时只受到一次决斗伤害")

	_prepare_play(&"lvbu", &"zhangfei")
	p2.weapon = SerpentSpear.new()
	_set_hand(p1, [DuelCard.new()])
	_set_hand(p2, [PeachCard.new(), WineCard.new(), DodgeCard.new()])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	game._use_serpent_spear(p2)
	_expect(game.response_received_count == 1 and game.flow_state == GameManager.FlowState.MULTI_RESPONSE, "丈八蛇矛每次发动在无双决斗中只计一张【杀】")

	_prepare_play(&"lvbu", &"zhangfei", 1)
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [DuelCard.new()])
	game._use_target_trick(p2, p1, 0)
	_pass_nullification_chain()
	_expect(game._duel_responder == p1 and game.response_required_count == 1, "别人对吕布使用决斗时吕布仍只需一张【杀】")
	game.request_response_card()
	_expect(game._duel_responder == p2 and game.response_required_count == 2, "决斗轮到吕布的对手时需要两张【杀】")


func _test_virtual_card_limits_and_ai() -> void:
	_prepare_play(&"guanyu", &"zhangfei")
	var red_cost := PeachCard.new()
	red_cost.suit = Card.Suit.HEART
	_set_hand(p1, [red_cost])
	p2.horse_plus = DefensiveHorse.new()
	_expect(not game.can_use_skill(p1, p1.get_skill(&"wusheng")), "武圣形成的【杀】仍受距离限制")
	_expect(red_cost in p1.hand, "距离不合法时不支付虚拟牌代价")

	_prepare_play(&"zhangfei", &"guanyu", 1)
	var ai_red := PeachCard.new()
	ai_red.suit = Card.Suit.HEART
	_set_hand(p2, [ai_red])
	_set_hand(p1, [])
	game._perform_ai_play()
	_expect(game.flow_state in [GameManager.FlowState.RESPONDING_SLASH, GameManager.FlowState.MULTI_RESPONSE], "AI 使用【武圣】形成虚拟【杀】")
	game.request_pass_response()
	_expect(p1.hp == 3, "AI 虚拟【杀】复用原伤害流程")

	_prepare_play(&"zhangfei", &"sunquan", 1)
	var low_value := IronChainCard.new()
	_set_hand(p2, [low_value])
	_set_draw_pile([PeachCard.new()])
	game._perform_ai_play()
	_expect(p2.skill_use_count(p2.get_skill(&"zhiheng")) == 1, "AI 对低价值牌发动一次【制衡】且不空选")


func _test_ai_triggered_skills() -> void:
	_prepare_play(&"zhangfei", &"zhangliao", 1)
	_set_hand(p1, [PeachCard.new()])
	_set_hand(p2, [])
	_set_draw_pile([SlashCard.new(), DodgeCard.new()])
	game._finish_judgement_phase()
	game._perform_ai_skill_confirm()
	_expect(p1.hand.is_empty() and p2.hand.size() == 1, "AI 对手有手牌时按策略发动【突袭】")

	_prepare_play(&"zhangfei", &"xuchu", 1)
	_set_hand(p1, [])
	_set_hand(p2, [SlashCard.new()])
	_set_draw_pile([PeachCard.new()])
	game._finish_judgement_phase()
	game._perform_ai_skill_confirm()
	_expect(p2.luoyi_active, "AI 有合法伤害牌与目标时发动【裸衣】")

	_prepare_play(&"zhangfei", &"caocao")
	var source_slash := SlashCard.new()
	_set_hand(p1, [source_slash])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	game._perform_ai_skill_confirm()
	_expect(source_slash in p2.hand, "AI 只要可获得来源实体牌就发动【奸雄】")


func _prepare_play(
	player1_general: StringName,
	player2_general: StringName,
	active_index: int = 0
) -> void:
	game._action_generation += 1
	p2.is_ai = true
	_expect(game.setup_generals(player1_general, player2_general), "测试选将配置合法")
	game.start_match(false)
	game._action_generation += 1
	game.current_player_index = active_index
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.selected_hand_index = -1
	game.winner = null
	game.processing_cards.clear()
	game.discard_pile.clear()
	game.draw_pile = CardFactory.create_basic_deck()
	p1.reset_turn_flags()
	p2.reset_turn_flags()


func _set_hand(player: BattlePlayer, cards: Array) -> void:
	player.hand.clear()
	for card: Card in cards:
		player.hand.append(card)
	player.hand_changed.emit()


func _set_draw_pile(cards: Array) -> void:
	game.draw_pile.clear()
	for card: Card in cards:
		game.draw_pile.append(card)


func _pass_nullification_chain() -> void:
	var guard: int = 0
	while game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE and guard < 6:
		var responder: BattlePlayer = game.players[game._nullification_responder_index]
		game._pass_nullification(responder)
		guard += 1


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
