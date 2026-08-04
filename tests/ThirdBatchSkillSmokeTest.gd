extends Node
## 第三批 7 名标准武将（马超、黄月英、大乔、陆逊、孙尚香、华佗、貂蝉）的确定性回归测试。
## 覆盖性别、马术/铁骑、奇才/集智、国色/流离、谦逊/连营、结姻/枭姬、急救/青囊、离间/闭月，
## 以及统一牌移动、失去最后手牌、失去装备、他人救援等通用能力。

const EquipmentScript = preload("res://scripts/cards/equipment/Equipment.gd")

@onready var game: GameManager = $GameManager
@onready var p1: BattlePlayer = $GameManager/Players/Player1
@onready var p2: BattlePlayer = $GameManager/Players/Player2

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	game._action_generation += 1
	_test_factory_and_metadata()
	_test_gender_data()
	_test_mashu_distance()
	_test_tieqi()
	_test_jizhi()
	_test_qicai()
	_test_guose()
	_test_liuli_two_player()
	_test_qianxun()
	_test_lianying()
	_test_jieyin()
	_test_xiaoji()
	_test_jijiu()
	_test_other_player_rescue()
	_test_qingnang()
	_test_lijian_two_player()
	_test_biyue()
	_test_combos()
	_test_third_batch_ai()
	_test_aoe_dying_and_prompt_regression()
	_test_ai_iron_chain_regression()
	_test_bagua_tiandu_slash_regression()
	_test_serpent_spear_lianying_regression()
	_test_generation_reset()
	game._action_generation += 1
	if failures.is_empty():
		print("THIRD_BATCH_SKILL_SMOKE_TEST: PASS (7 remaining standard generals; 25 total)")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("THIRD_BATCH_SKILL_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)


func _test_factory_and_metadata() -> void:
	var ids: Array[StringName] = GeneralFactory.all_general_ids()
	var unique: Dictionary = {}
	_expect(ids.size() == 25, "GeneralFactory 共创建25名标准武将")
	for general_id: StringName in ids:
		_expect(not unique.has(general_id), "武将id唯一：%s" % general_id)
		unique[general_id] = true
		var definition: GeneralDefinition = GeneralFactory.create_general(general_id)
		_expect(definition != null, "武将定义存在：%s" % general_id)
		for skill_id: String in definition.skill_ids:
			_expect(SkillFactory.create_skill(StringName(skill_id)) != null, "技能脚本存在：%s" % skill_id)
	var hp3: Array[StringName] = [&"huangyueying", &"daqiao", &"luxun", &"sunshangxiang", &"huatuo", &"diaochan"]
	for general_id: StringName in hp3:
		_expect(GeneralFactory.create_general(general_id).max_hp == 3, "%s体力上限为3" % general_id)
	_expect(GeneralFactory.create_general(&"machao").max_hp == 4, "马超体力上限为4")
	var expected: Dictionary = {
		&"mashu": [Skill.ActivationMode.MODIFIER, true, Skill.UsageScope.UNLIMITED],
		&"tieqi": [Skill.ActivationMode.TRIGGERED, false, Skill.UsageScope.UNLIMITED],
		&"jizhi": [Skill.ActivationMode.TRIGGERED, false, Skill.UsageScope.UNLIMITED],
		&"qicai": [Skill.ActivationMode.MODIFIER, true, Skill.UsageScope.UNLIMITED],
		&"guose": [Skill.ActivationMode.VIEW_AS, false, Skill.UsageScope.UNLIMITED],
		&"liuli": [Skill.ActivationMode.TRIGGERED, false, Skill.UsageScope.UNLIMITED],
		&"qianxun": [Skill.ActivationMode.MODIFIER, true, Skill.UsageScope.UNLIMITED],
		&"lianying": [Skill.ActivationMode.TRIGGERED, false, Skill.UsageScope.UNLIMITED],
		&"jieyin": [Skill.ActivationMode.ACTIVE, false, Skill.UsageScope.PER_TURN],
		&"xiaoji": [Skill.ActivationMode.TRIGGERED, false, Skill.UsageScope.UNLIMITED],
		&"jijiu": [Skill.ActivationMode.VIEW_AS, false, Skill.UsageScope.UNLIMITED],
		&"qingnang": [Skill.ActivationMode.ACTIVE, false, Skill.UsageScope.PER_TURN],
		&"lijian": [Skill.ActivationMode.ACTIVE, false, Skill.UsageScope.PER_TURN],
		&"biyue": [Skill.ActivationMode.TRIGGERED, false, Skill.UsageScope.UNLIMITED],
	}
	for skill_id: StringName in expected:
		var skill: Skill = SkillFactory.create_skill(skill_id)
		var spec: Array = expected[skill_id]
		_expect(
			skill != null
			and skill.activation_mode == spec[0]
			and skill.has_tag(Skill.SkillTag.LOCKED) == spec[1]
			and skill.usage_scope == spec[2],
			"第三批技能分类正确：%s" % skill_id
		)
	_expect(SkillFactory.create_skill(&"jieyin").max_uses == 1, "结姻每回合限一次")
	_expect(SkillFactory.create_skill(&"qingnang").max_uses == 1, "青囊每回合限一次")
	_expect(SkillFactory.create_skill(&"lijian").max_uses == 1, "离间每回合限一次")


func _test_gender_data() -> void:
	var female: Array[StringName] = [&"zhenji", &"huangyueying", &"daqiao", &"sunshangxiang", &"diaochan"]
	for general_id: StringName in female:
		_expect(
			GeneralFactory.create_general(general_id).gender == GeneralDefinition.Gender.FEMALE,
			"%s 性别数据为女性（规则数据，不按名字推断）" % general_id
		)
	for general_id: StringName in GeneralFactory.all_general_ids():
		if general_id in female:
			continue
		_expect(
			GeneralFactory.create_general(general_id).gender == GeneralDefinition.Gender.MALE,
			"%s 性别数据为男性" % general_id
		)
	_prepare(&"sunshangxiang", &"xiahoudun")
	_expect(p1.gender == GeneralDefinition.Gender.FEMALE and p2.gender == GeneralDefinition.Gender.MALE, "选将后 BattlePlayer 保存 gender 字段")
	var jieyin: Skill = p1.get_skill(&"jieyin")
	_expect(not jieyin.validate_target(p1, [p1.hand[0], p1.hand[1]], game, p1), "结姻不能以女性自己为目标（读取 gender 字段）")
	p2.hp = 3
	_expect(jieyin.validate_target(p2, [p1.hand[0], p1.hand[1]], game, p1), "结姻可以受伤的男性目标为目标（读取 gender 字段）")
	_prepare(&"diaochan", &"xiahoudun")
	var lijian: Skill = p1.get_skill(&"lijian")
	_expect(lijian != null and not game.can_use_skill(p1, lijian), "离间读取 gender 字段后因不足两名男性而不可发动")


func _test_mashu_distance() -> void:
	_prepare(&"machao", &"xiahoudun")
	_expect(game.distance_between(p1, p2) == 1, "马术令距离最低为1")
	p2.horse_plus = DefensiveHorse.new()
	_expect(game.distance_between(p1, p2) == 1, "马术与目标+1马叠加后仍为1")
	p1.horse_minus = OffensiveHorse.new()
	_expect(game.distance_between(p1, p2) == 1, "马术与-1马叠加，全部修正后取 max(1)")
	_expect(game.distance_between(p2, p1) == 1, "反向距离不受马术影响（无+1马时仍为1）")
	p1.horse_plus = DefensiveHorse.new()
	_expect(game.distance_between(p2, p1) == 2, "反向距离只按常规坐骑计算（目标+1马计2）")
func _test_tieqi() -> void:
	## 红判禁止实体闪与八卦阵
	_prepare(&"machao", &"xiahoudun")
	p2.is_ai = false
	var red := PeachCard.new(); red.suit = Card.Suit.HEART
	_set_hand(p1, [SlashCard.new()]); _set_hand(p2, [DodgeCard.new()])
	_set_draw_top_first([red])
	game._play_slash(p1, p2, 0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"tieqi", "铁骑在杀指定后、闪响应前询问")
	game.request_confirm_skill()
	_expect(game._slash_dodge_forbidden and game.flow_state == GameManager.FlowState.RESPONDING_SLASH, "铁骑红判后禁止闪响应")
	game.request_dodge()
	_expect(p2.hand.size() == 1 and game.flow_state == GameManager.FlowState.RESPONDING_SLASH, "铁骑红判后不能使用实体闪")
	game.request_pass_response()
	_expect(p2.hp == 3 and red in game.discard_pile, "铁骑红判后直接进入未闪避分支造成伤害")
	## 黑判正常响应
	_prepare(&"machao", &"xiahoudun")
	p2.is_ai = false
	var black := SlashCard.new(); black.suit = Card.Suit.SPADE
	_set_hand(p1, [SlashCard.new()]); _set_hand(p2, [DodgeCard.new()])
	_set_draw_top_first([black])
	game._play_slash(p1, p2, 0)
	game.request_confirm_skill()
	_expect(not game._slash_dodge_forbidden and game.flow_state == GameManager.FlowState.RESPONDING_SLASH, "铁骑黑判后正常进入闪响应")
	game.request_dodge()
	_expect(p2.hp == 4 and p2.hand.is_empty(), "铁骑黑判后实体闪可正常抵消")
	## 放弃发动正常响应
	_prepare(&"machao", &"xiahoudun")
	p2.is_ai = false
	_set_hand(p1, [SlashCard.new()]); _set_hand(p2, [DodgeCard.new()])
	_set_draw_top_first([black])
	game._play_slash(p1, p2, 0)
	game.request_decline_skill()
	_expect(game.flow_state == GameManager.FlowState.RESPONDING_SLASH and not game._slash_dodge_forbidden, "铁骑放弃后正常响应")
	game.request_dodge()
	_expect(p2.hp == 4, "铁骑放弃后闪正常抵消")
	## 八卦阵在红判时不可发动
	_prepare(&"machao", &"xiahoudun")
	p2.is_ai = false
	p2.armor = EightTrigrams.new()
	_set_hand(p1, [SlashCard.new()]); _set_hand(p2, [])
	_set_draw_top_first([red])
	game._play_slash(p1, p2, 0)
	game.request_confirm_skill()
	_expect(not game.can_use_bagua(p2), "铁骑红判后八卦阵不可发动")
	game.request_pass_response()
	_expect(p2.hp == 3, "铁骑红判后八卦阵不能提供视为闪")
	## 鬼才改判后读取最终颜色
	_prepare(&"machao", &"simayi")
	p2.is_ai = false
	var black2 := SlashCard.new(); black2.suit = Card.Suit.CLUB
	var red_hand := PeachCard.new(); red_hand.suit = Card.Suit.DIAMOND
	_set_hand(p1, [SlashCard.new()]); _set_hand(p2, [red_hand])
	_set_draw_top_first([black2])
	game._play_slash(p1, p2, 0)
	game.request_confirm_skill()
	_expect(game.flow_state == GameManager.FlowState.JUDGEMENT_REPLACE and game.judgement_context.effective_card == black2, "铁骑判定进入鬼才改判窗口")
	game.request_judgement_replace(0)
	_expect(game._slash_dodge_forbidden and red_hand in game.discard_pile and black2 in game.discard_pile, "鬼才改判后铁骑按最终判定颜色结算")
	game.request_pass_response()
	_expect(p2.hp == 2 and black2 in game.discard_pile, "铁骑+鬼才改判后原判定牌弃置并完成伤害")


func _test_jizhi() -> void:
	## 非延时锦囊使用后可摸一张
	_prepare(&"huangyueying", &"xiahoudun")
	_set_hand(p1, [DismantleCard.new()]); _set_hand(p2, [DodgeCard.new()])
	_set_draw_top_first([PeachCard.new()])
	game._use_target_trick(p1, p2, 0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"jizhi", "集智在锦囊使用事件后询问")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1 and p1.hand[0].card_type == Card.CardType.PEACH, "集智摸一张牌")
	game._pass_nullification(p2); game._pass_nullification(p1)
	_expect(p2.hand.is_empty() and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "集智后锦囊继续正常结算")
	## 被无懈抵消仍触发
	_prepare(&"huangyueying", &"xiahoudun")
	_set_hand(p1, [DismantleCard.new()]); _set_hand(p2, [DodgeCard.new(), NullificationCard.new()])
	_set_draw_top_first([PeachCard.new()])
	game._use_target_trick(p1, p2, 0)
	game.request_confirm_skill()
	game._play_nullification(p2, 1)
	game._pass_nullification(p1)
	_expect(p1.hand.size() == 1 and p2.hand.size() == 1, "集智被无懈抵消前仍触发摸牌")
	## 延时锦囊不触发
	_prepare(&"huangyueying", &"xiahoudun")
	_set_hand(p1, [IndulgenceCard.new()])
	game._use_target_trick(p1, p2, 0)
	_expect(game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE, "乐不思蜀不触发集智")
	game._pass_nullification(p2); game._pass_nullification(p1)
	_expect(p2.indulgence_card != null, "乐不思蜀正常置入判定区")
	## 群体牌只触发一次
	_prepare(&"huangyueying", &"xiahoudun")
	_set_hand(p1, [BarbarianInvasionCard.new()]); _set_hand(p2, [])
	_set_draw_top_first([PeachCard.new()])
	game._use_self_or_global_trick(p1, 0)
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1, "群体锦囊只触发一次集智摸一张")
	game._pass_nullification(p2); game._pass_nullification(p1)
	game._perform_ai_response()
	_expect(p2.hp == 3, "南蛮入侵继续正常结算")


func _test_qicai() -> void:
	_prepare(&"huangyueying", &"xiahoudun")
	p2.horse_plus = DefensiveHorse.new()
	_set_hand(p2, [DodgeCard.new()])
	var steal := StealCard.new()
	_expect(game.distance_between(p1, p2) == 2, "存在+1马时距离为2")
	_expect(game.can_play_trick(steal, p1), "奇才令顺手牵羊无视距离限制")
	_expect(game._is_valid_trick_target(steal, p1, p2), "奇才后顺手牵羊目标合法")
	p2.weapon = QinggangSword.new()
	var borrow := BorrowSwordCard.new()
	_expect(game.can_play_trick(borrow, p1), "奇才令借刀杀人无视距离限制")
	_expect(game._is_valid_trick_target(borrow, p1, p2), "奇才后借刀杀人目标合法")
	_set_hand(p2, [])
	p2.weapon = null
	p2.horse_plus = null
	_expect(not game._is_valid_trick_target(steal, p1, p2), "奇才不取消顺手牵羊需要目标任一区域有牌的限制")
	_expect(not game._is_valid_trick_target(borrow, p1, p2), "奇才不取消借刀需要目标有武器的限制")


func _test_guose() -> void:
	## 方块手牌当乐不思蜀，真实牌成为判定区实体牌
	_prepare(&"daqiao", &"xiahoudun")
	p2.is_ai = false
	var diamond := WineCard.new(); diamond.suit = Card.Suit.DIAMOND
	_set_hand(p1, [diamond]); _set_hand(p2, [])
	game.request_begin_skill(&"guose")
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_CARDS, "国色进入选牌状态")
	game.request_skill_toggle_hand_card(0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_TARGET, "国色选牌后选择目标")
	game.request_skill_target(1)
	_expect(game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE, "国色复用乐不思蜀无懈链")
	game._pass_nullification(p2); game._pass_nullification(p1)
	_expect(p2.indulgence_card == diamond and p1.hand.is_empty(), "国色的真实方块手牌成为判定区实体牌")
	## 方块装备当乐不思蜀，装备走统一失去装备入口
	_prepare(&"daqiao", &"xiahoudun")
	p2.is_ai = false
	var diamond_equip := EightTrigrams.new(); diamond_equip.suit = Card.Suit.DIAMOND
	p1.armor = diamond_equip
	_set_hand(p1, []); _set_hand(p2, [])
	game.request_begin_skill(&"guose")
	game.request_skill_select_equipment(EquipmentScript.Slot.ARMOR)
	game.request_skill_target(1)
	game._pass_nullification(p2); game._pass_nullification(p1)
	_expect(p1.armor == null and p2.indulgence_card == diamond_equip, "方块装备作为国色代价走失去装备入口并成为乐不思蜀")
	## 非方块不可
	_prepare(&"daqiao", &"xiahoudun")
	var spade := SlashCard.new(); spade.suit = Card.Suit.SPADE
	_set_hand(p1, [spade])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"guose")), "非方块牌不能发动国色")
	## 同名延时锦囊不可重复
	_prepare(&"daqiao", &"xiahoudun")
	var diamond2 := WineCard.new(); diamond2.suit = Card.Suit.DIAMOND
	p2.indulgence_card = IndulgenceCard.new()
	_set_hand(p1, [diamond2])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"guose")), "目标已有乐不思蜀时国色不可发动")

func _test_liuli_two_player() -> void:
	## 严格双人局：杀来源不能成为自己杀的目标，流离无合法转移目标
	_prepare(&"xiahoudun", &"daqiao")
	p2.is_ai = false
	var cost := PeachCard.new()
	_set_hand(p2, [cost]); _set_hand(p1, [SlashCard.new()])
	var slash_context := SlashTargetContext.new(p1, p2, [SlashCard.new()], Card.CardType.SLASH, 1)
	_expect(game.liuli_transfer_candidates(p2, slash_context).is_empty(), "双人局流离无合法转移目标")
	_expect(not p2.get_skill(&"liuli").can_trigger(slash_context, game, p2), "流离在双人局不可触发")
	var hand_before: int = p2.hand.size()
	game._play_slash(p1, p2, 0)
	_expect(game.flow_state == GameManager.FlowState.RESPONDING_SLASH, "流离不打断杀流程")
	_expect(p2.hand.size() == hand_before, "流离未弃置任何牌")
	game.request_pass_response()
	_expect(p2.hp == 2, "杀正常结算伤害")


func _test_qianxun() -> void:
	_prepare(&"xiahoudun", &"luxun")
	p2.is_ai = false
	_set_hand(p2, [DodgeCard.new()])
	var steal := StealCard.new()
	_expect(not game._is_valid_trick_target(steal, p1, p2), "谦逊拒绝顺手牵羊")
	_expect(not game.can_play_trick(steal, p1), "谦逊在规则层拒绝顺手牵羊")
	var indulgence := IndulgenceCard.new()
	_expect(not game._is_valid_trick_target(indulgence, p1, p2), "谦逊拒绝乐不思蜀")
	var dismantle := DismantleCard.new()
	_expect(game._is_valid_trick_target(dismantle, p1, p2), "谦逊不限制过河拆桥")
	## 国色形成的虚拟乐不思蜀同样被谦逊拒绝
	_prepare(&"daqiao", &"luxun")
	p2.is_ai = false
	var diamond := WineCard.new(); diamond.suit = Card.Suit.DIAMOND
	_set_hand(p1, [diamond]); _set_hand(p2, [DodgeCard.new()])
	var virtual_indulgence: Card = CardFactory.create_card(Card.CardType.INDULGENCE)
	_expect(not game._is_valid_trick_target(virtual_indulgence, p1, p2), "国色虚拟乐不思蜀不能以陆逊为目标")
	_expect(not game.can_use_skill(p1, p1.get_skill(&"guose")), "谦逊令国色整体不可发动")


func _test_lianying() -> void:
	## 使用最后一张牌触发连营
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	_set_hand(p1, [SlashCard.new()]); _set_hand(p2, [])
	_set_draw_top_first([DodgeCard.new()])
	game._play_slash(p1, p2, 0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "使用最后一张杀后询问连营")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1 and p1.hand[0].card_type == Card.CardType.DODGE, "连营摸一张牌")
	game._perform_ai_response()
	_expect(p2.hp == 3, "连营结算后杀继续结算")
	## 打出最后一张闪响应触发连营
	_prepare(&"luxun", &"xiahoudun", 1)
	p2.is_ai = false
	var dodge := DodgeCard.new()
	_set_hand(p1, [dodge]); _set_hand(p2, [SlashCard.new()])
	_set_draw_top_first([PeachCard.new()])
	game._play_slash(p2, p1, 0)
	game.request_dodge()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "打出最后一张闪响应后询问连营")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1 and p2.hp == 4, "连营后闪响应正常完成")
	## 被弃置最后一张触发
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var only := DodgeCard.new()
	_set_hand(p1, [only]); _set_hand(p2, [DismantleCard.new()])
	_set_draw_top_first([PeachCard.new()])
	game._use_target_trick(p2, p1, 0)
	game._pass_nullification(p1); game._pass_nullification(p2)
	game.request_option(0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "被过河拆桥弃置最后一张后询问连营")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1, "连营摸牌后手牌为1")
	## 被获得最后一张触发（统一牌移动入口）
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var stolen := PeachCard.new()
	_set_hand(p1, [stolen]); _set_hand(p2, [])
	_set_draw_top_first([SlashCard.new()])
	game._move_cards(p1, p2, [stolen], GameManager.CardZone.HAND, "被获得", null, null, p2, Callable())
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "被获得最后一张后询问连营")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1 and stolen in p2.hand, "连营摸牌且被获得的牌已进入对方手牌")
	## 交给他人最后一张触发（统一牌移动入口）
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var given := PeachCard.new()
	_set_hand(p1, [given]); _set_hand(p2, [])
	_set_draw_top_first([SlashCard.new()])
	game._move_cards(p1, p1, [given], GameManager.CardZone.HAND, "测试交给", null, null, p2, Callable())
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "将最后一张交给他人后询问连营")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1 and given in p2.hand, "交给后连营摸牌")
	## 同次失去多张只触发一次
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var a := SlashCard.new(); var b := DodgeCard.new()
	_set_hand(p1, [a, b]); _set_hand(p2, [])
	_set_draw_top_first([PeachCard.new()])
	game._move_cards(p1, p1, [a, b], GameManager.CardZone.DISCARD, "测试同时弃置多张", null, null, null, Callable())
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "同次失去多张只询问一次连营")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1, "连营只摸一张")
	## 摸牌后再次空手可再次触发
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var again := WineCard.new()
	_set_hand(p1, [again]); _set_hand(p2, [])
	_set_draw_top_first([SlashCard.new(), DodgeCard.new()])
	game._move_cards(p1, p1, [again], GameManager.CardZone.DISCARD, "测试第一次空手", null, null, null, Callable())
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1, "第一次连营摸一张")
	var drawn: Card = p1.hand[0]
	game._move_cards(p1, p1, [drawn], GameManager.CardZone.DISCARD, "测试再次空手", null, null, null, Callable())
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "连营摸牌后再次空手可再次触发")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1, "第二次连营再摸一张")
	## 技能代价失去最后手牌触发（统一入口）
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var cost_card := WineCard.new()
	_set_hand(p1, [cost_card]); _set_hand(p2, [])
	_set_draw_top_first([SlashCard.new()])
	var fake_skill: Skill = SkillFactory.create_skill(&"jijiu")
	game._move_cards(p1, p1, [cost_card], GameManager.CardZone.PROCESSING, "作为技能代价", null, fake_skill, null, Callable())
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "作为技能代价失去最后手牌后询问连营")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1, "技能代价后的连营摸牌")
	## 最后一张手牌替换同槽装备：旧装备须在连营等待帧仍属于处理区，牌数严格守恒。
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var old_weapon := QinggangSword.new()
	var new_weapon := Crossbow.new()
	p1.weapon = old_weapon
	_set_hand(p1, [new_weapon])
	_set_draw_top_first([DodgeCard.new()])
	var before_replace_count: int = game.tracked_card_count()
	game._play_equipment(p1, 0)
	_expect(
		game.flow_state == GameManager.FlowState.SKILL_CONFIRM
		and game.pending_skill.id == &"lianying"
		and old_weapon in game.processing_cards
		and game.tracked_card_count() == before_replace_count,
		"陆逊最后手牌替换装备进入连营确认时旧装备仍在处理区且牌数守恒"
	)
	game.request_confirm_skill()
	_expect(
		p1.weapon == new_weapon and old_weapon in game.discard_pile
		and old_weapon not in game.processing_cards,
		"连营结束后装备替换继续结算且旧装备进入弃牌堆"
	)

func _test_jieyin() -> void:
	## 男性且受伤的对手合法，两张手牌原子支付，双方回复
	_prepare(&"sunshangxiang", &"xiahoudun")
	p2.is_ai = false
	p1.hp = 2; p1.hp_changed.emit(p1.hp, p1.max_hp)
	p2.hp = 3; p2.hp_changed.emit(p2.hp, p2.max_hp)
	var c1 := SlashCard.new(); var c2 := DodgeCard.new()
	_set_hand(p1, [c1, c2]); _set_hand(p2, [])
	game.request_begin_skill(&"jieyin")
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_CARDS, "结姻进入选牌")
	game.request_skill_toggle_hand_card(0); game.request_skill_toggle_hand_card(1)
	game.request_confirm_skill_cards()
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_TARGET, "结姻选完两张手牌后选择目标")
	game.request_skill_target(1)
	_expect(p1.hand.is_empty() and p2.hp == 4 and p1.hp == 3, "结姻原子弃两张手牌并双方各回复1点")
	_expect(not game.can_use_skill(p1, p1.get_skill(&"jieyin")), "结姻每回合限一次")
	## 女性目标非法
	_prepare(&"sunshangxiang", &"zhenji")
	p2.is_ai = false
	p2.hp = 2; p2.hp_changed.emit(p2.hp, p2.max_hp)
	_set_hand(p1, [SlashCard.new(), DodgeCard.new()])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"jieyin")), "结姻不能以女性为目标")
	## 未受伤目标非法
	_prepare(&"sunshangxiang", &"xiahoudun")
	p2.is_ai = false
	_set_hand(p1, [SlashCard.new(), DodgeCard.new()])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"jieyin")), "结姻不能以满体力对手为目标")
	## 取消不弃牌
	_prepare(&"sunshangxiang", &"xiahoudun")
	p2.is_ai = false
	p2.hp = 3; p2.hp_changed.emit(p2.hp, p2.max_hp)
	var keep := WineCard.new()
	_set_hand(p1, [keep, DodgeCard.new()])
	game.request_begin_skill(&"jieyin")
	game.request_skill_toggle_hand_card(0)
	game.request_cancel_skill()
	_expect(keep in p1.hand and p1.hand.size() == 2, "取消结姻不弃牌")
	## 支付后由连营插入异步触发；即使目标期间回复满体力，已锁定的结姻仍须完整收尾。
	_prepare(&"sunshangxiang", &"xiahoudun")
	p2.is_ai = false
	p1.add_skill_id(&"lianying")
	p1.hp = 2; p1.hp_changed.emit(p1.hp, p1.max_hp)
	p2.hp = 3; p2.hp_changed.emit(p2.hp, p2.max_hp)
	var locked1 := SlashCard.new(); var locked2 := DodgeCard.new()
	_set_hand(p1, [locked1, locked2]); _set_draw_top_first([WineCard.new()])
	game.request_begin_skill(&"jieyin")
	game.request_skill_toggle_hand_card(0); game.request_skill_toggle_hand_card(1)
	game.request_confirm_skill_cards(); game.request_skill_target(1)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "结姻支付后可串行处理失去最后手牌触发")
	p2.recover(1)
	game.request_confirm_skill()
	_expect(
		p1.hp == 3 and p2.hp == p2.max_hp and p1.hand.size() == 1
		and locked1 in game.discard_pile and locked2 in game.discard_pile
		and game.flow_state == GameManager.FlowState.PLAY_ACTIVE,
		"结姻支付后锁定目标并在异步触发后完整结算、清理上下文"
	)


func _test_xiaoji() -> void:
	## 装备替换触发枭姬摸二
	_prepare(&"sunshangxiang", &"xiahoudun")
	p2.is_ai = false
	p1.weapon = QinggangSword.new()
	var new_weapon := Crossbow.new()
	_set_hand(p1, [new_weapon, SlashCard.new(), DodgeCard.new()])
	_set_draw_top_first([PeachCard.new(), WineCard.new()])
	game._play_equipment(p1, 0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"xiaoji", "装备替换后询问枭姬")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 4 and p1.weapon.card_type == Card.CardType.CROSSBOW, "枭姬摸两张且替换完成")
	## 拆除（过河拆桥）装备触发
	_prepare(&"sunshangxiang", &"xiahoudun")
	p2.is_ai = false
	var armor := EightTrigrams.new()
	p1.armor = armor
	_set_hand(p1, []); _set_hand(p2, [DismantleCard.new()])
	_set_draw_top_first([PeachCard.new(), WineCard.new()])
	game._use_target_trick(p2, p1, 0)
	game._pass_nullification(p1); game._pass_nullification(p2)
	game.request_option(0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"xiaoji", "拆除装备后询问枭姬")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 2 and p1.armor == null, "枭姬摸两张且装备已移除")
	## 被获得（借刀交出武器）触发
	_prepare(&"xiahoudun", &"sunshangxiang")
	p2.is_ai = false
	var weapon := QinggangSword.new()
	p2.weapon = weapon
	_set_hand(p2, []); _set_hand(p1, [BorrowSwordCard.new()])
	_set_draw_top_first([PeachCard.new(), WineCard.new()])
	game._use_target_trick(p1, p2, 0)
	game._pass_nullification(p2); game._pass_nullification(p1)
	_expect(game.flow_state == GameManager.FlowState.CHOOSING_OPTION and game.choice_owner == p2, "借刀进入目标响应")
	game.request_option(0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"xiaoji", "借刀交出武器后询问枭姬")
	game.request_confirm_skill()
	_expect(p2.hand.size() == 2 and weapon in p1.hand, "枭姬摸两张且武器已交出")
	## 作为代价（统一入口）触发，同一实体装备不重复触发
	_prepare(&"sunshangxiang", &"xiahoudun")
	p2.is_ai = false
	var lion := SilverLion.new()
	p1.armor = lion
	p1.hp = 2; p1.hp_changed.emit(p1.hp, p1.max_hp)
	_set_hand(p1, []); _set_hand(p2, [])
	_set_draw_top_first([PeachCard.new(), WineCard.new(), SlashCard.new()])
	var fake_cost: Skill = SkillFactory.create_skill(&"guose")
	game._move_cards(p1, p1, [lion], GameManager.CardZone.PROCESSING, "作为技能代价", null, fake_cost, null, Callable())
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "装备作为代价触发离场技能（枭姬）")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 2 and p1.hp == 3, "枭姬摸两张且白银狮子回复已结算")
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game._move_cards(p1, p1, [lion], GameManager.CardZone.PROCESSING, "重复移动同一装备", null, null, null, Callable())
	_expect(game.flow_state != GameManager.FlowState.SKILL_CONFIRM, "同一实体装备离开后不能重复触发枭姬")


func _test_jijiu() -> void:
	## 回合外红色手牌可当桃自救
	_prepare(&"huatuo", &"xiahoudun", 1)
	p1.is_ai = false
	p1.hp = -1; p1.hp_changed.emit(p1.hp, p1.max_hp)
	game.dying_player = p1
	game.rescue_actor = p1
	game.flow_state = GameManager.FlowState.DYING_RESCUE
	var red_hand := PeachCard.new(); red_hand.suit = Card.Suit.HEART
	_set_hand(p1, [red_hand])
	_expect(game.can_use_skill(p1, p1.get_skill(&"jijiu")), "回合外红色手牌可发动急救")
	game.request_begin_skill(&"jijiu")
	game.request_skill_toggle_hand_card(0)
	_expect(p1.hp == 0 and p1.hand.is_empty() and game.flow_state == GameManager.FlowState.DYING_RESCUE, "急救每次只回复一点体力")
	## 红色装备可当桃并走失去装备入口
	var red_equip := EightTrigrams.new(); red_equip.suit = Card.Suit.DIAMOND
	p1.armor = red_equip
	game.request_begin_skill(&"jijiu")
	game.request_skill_select_equipment(EquipmentScript.Slot.ARMOR)
	_expect(p1.hp == 1 and p1.armor == null and game.dying_player == null, "急救红装备回复一点并脱离濒死")
	## 黑牌不可发动
	_prepare(&"huatuo", &"xiahoudun", 1)
	p1.is_ai = false
	p1.hp = 0
	game.dying_player = p1
	game.rescue_actor = p1
	game.flow_state = GameManager.FlowState.DYING_RESCUE
	var black_hand := SlashCard.new(); black_hand.suit = Card.Suit.SPADE
	_set_hand(p1, [black_hand])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"jijiu")), "黑牌不能发动急救")
	## 自己的回合内不能发动急救
	_prepare(&"huatuo", &"xiahoudun", 0)
	p1.is_ai = false
	p1.hp = 0
	game.dying_player = p1
	game.rescue_actor = p1
	game.flow_state = GameManager.FlowState.DYING_RESCUE
	var red2 := PeachCard.new(); red2.suit = Card.Suit.HEART
	_set_hand(p1, [red2])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"jijiu")), "自己的回合内不能发动急救")

func _test_other_player_rescue() -> void:
	## 濒死者自救后仍不足1，询问另一方；另一方桃可救援
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var self_peach := PeachCard.new()
	_set_hand(p1, [self_peach]); _set_hand(p2, [PeachCard.new()])
	p1.hp = -1; p1.hp_changed.emit(p1.hp, p1.max_hp)
	game._enter_dying(p1, Callable())
	_expect(game.rescue_actor == p1, "濒死者先获得自救机会")
	game.request_rescue(Card.CardType.PEACH)
	_expect(p1.hp == 0 and game.rescue_actor == p1, "自救一次后仍未回复至1继续询问")
	game.request_give_up_rescue()
	_expect(game.rescue_actor == p2, "自救放弃后询问另一方")
	game.request_rescue(Card.CardType.PEACH)
	_expect(p1.hp == 1 and game.dying_player == null, "另一方桃成功救援并退出濒死")
	## 酒不能救别人
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	_set_hand(p1, []); _set_hand(p2, [WineCard.new(), PeachCard.new()])
	p1.hp = -1
	game._enter_dying(p1, Callable())
	_expect(game.rescue_actor == p2, "放弃自救后轮到另一方")
	game.request_rescue(Card.CardType.WINE)
	_expect(p1.hp == -1 and game.flow_state == GameManager.FlowState.DYING_RESCUE, "酒不能用于救援别人")
	game.request_give_up_rescue()
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER, "全部放弃后正确死亡")
	## 另一方急救可救援
	_prepare(&"luxun", &"huatuo")
	p2.is_ai = false
	_set_hand(p1, []); _set_hand(p2, [])
	var red := PeachCard.new(); red.suit = Card.Suit.HEART
	p2.add_card(red)
	p1.hp = 0
	game.current_player_index = 0
	game._enter_dying(p1, Callable())
	_expect(game.rescue_actor == p2 and game.can_use_skill(p2, p2.get_skill(&"jijiu")), "华佗回合外可对濒死敌方发动急救")
	game.request_begin_skill(&"jijiu")
	game.request_skill_toggle_hand_card(0)
	_expect(p1.hp == 1 and game.dying_player == null, "急救成功救援对方")


func _test_qingnang() -> void:
	## 治疗受伤的自己
	_prepare(&"huatuo", &"xiahoudun")
	p1.hp = 2; p1.hp_changed.emit(p1.hp, p1.max_hp)
	var cost := DodgeCard.new()
	_set_hand(p1, [cost])
	game.request_begin_skill(&"qingnang")
	game.request_skill_toggle_hand_card(0)
	game.request_confirm_skill_cards()
	_expect(game.flow_state == GameManager.FlowState.SKILL_SELECT_TARGET, "青囊选完手牌后选择目标")
	game.request_skill_target(0)
	_expect(p1.hp == 3 and p1.hand.is_empty(), "青囊弃一张手牌治疗自己")
	## 治疗受伤的对手
	_prepare(&"huatuo", &"xiahoudun")
	p2.hp = 2; p2.hp_changed.emit(p2.hp, p2.max_hp)
	_set_hand(p1, [DodgeCard.new()])
	game.request_begin_skill(&"qingnang")
	game.request_skill_toggle_hand_card(0)
	game.request_confirm_skill_cards()
	game.request_skill_target(1)
	_expect(p2.hp == 3, "青囊治疗受伤对手")
	_expect(not game.can_use_skill(p1, p1.get_skill(&"qingnang")), "青囊每回合限一次")
	## 满体力目标非法；装备代价非法
	_prepare(&"huatuo", &"xiahoudun")
	_set_hand(p1, [DodgeCard.new()])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"qingnang")), "双方满体力时青囊不可发动")
	_prepare(&"huatuo", &"xiahoudun")
	p1.hp = 2; p1.hp_changed.emit(p1.hp, p1.max_hp)
	var equip := Crossbow.new()
	p1.weapon = equip
	_expect(not p1.get_skill(&"qingnang").allows_equipment_cost(), "青囊不允许装备代价")
	_expect(not p1.get_skill(&"qingnang").validate_cost([equip], game, p1), "装备不能作为青囊代价")
	## 取消不支付
	_prepare(&"huatuo", &"xiahoudun")
	p1.hp = 2; p1.hp_changed.emit(p1.hp, p1.max_hp)
	var keep := WineCard.new()
	_set_hand(p1, [keep])
	game.request_begin_skill(&"qingnang")
	game.request_skill_toggle_hand_card(0)
	game.request_cancel_skill()
	_expect(keep in p1.hand and p1.hp == 2, "取消青囊不弃牌不回复")


func _test_lijian_two_player() -> void:
	_prepare(&"diaochan", &"xiahoudun")
	var cost := SlashCard.new()
	_set_hand(p1, [cost])
	var lijian: Skill = p1.get_skill(&"lijian")
	_expect(lijian != null and lijian.activation_mode == Skill.ActivationMode.ACTIVE, "离间技能元数据完整")
	_expect(lijian.usage_scope == Skill.UsageScope.PER_TURN and lijian.max_uses == 1, "离间每回合限一次")
	_expect(not game.can_use_skill(p1, lijian), "双人局不足两名男性时离间不可发动")
	game.request_begin_skill(&"lijian")
	_expect(cost in p1.hand and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "离间不支付代价不生成决斗")
	_expect(game._duel_responder == null, "离间未生成决斗流程")


func _test_biyue() -> void:
	## 结束阶段开始时可摸一张或放弃，随后只切换一次回合
	_prepare(&"diaochan", &"xiahoudun")
	p1.is_ai = false
	_set_hand(p1, []); _set_draw_top_first([PeachCard.new()])
	game.phase = GameManager.Phase.END
	game.flow_state = GameManager.FlowState.IDLE
	var index_before: int = game.current_player_index
	game._finish_turn_from_end_phase()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"biyue", "结束阶段开始时询问闭月")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1, "闭月摸一张牌")
	_expect(game.current_player_index == 1 - index_before, "闭月后只切换一次回合")
	## 放弃闭月
	_prepare(&"diaochan", &"xiahoudun")
	p1.is_ai = false
	_set_hand(p1, []); _set_draw_top_first([PeachCard.new()])
	game.phase = GameManager.Phase.END
	game.flow_state = GameManager.FlowState.IDLE
	game._finish_turn_from_end_phase()
	game.request_decline_skill()
	_expect(p1.hand.is_empty() and game.current_player_index == 1, "放弃闭月不摸牌并正常切换回合")

func _test_combos() -> void:
	## 铁骑+鬼才+天妒：铁骑判定允许鬼才改判；天妒在统一判定管线中仍可获得最终牌
	_prepare(&"machao", &"simayi")
	p2.is_ai = false
	var black := SlashCard.new(); black.suit = Card.Suit.SPADE
	var red_hand := PeachCard.new(); red_hand.suit = Card.Suit.HEART
	_set_hand(p1, [SlashCard.new()]); _set_hand(p2, [red_hand])
	_set_draw_top_first([black])
	game._play_slash(p1, p2, 0)
	game.request_confirm_skill()
	game.request_judgement_replace(0)
	_expect(game._slash_dodge_forbidden and red_hand in game.discard_pile, "铁骑+鬼才：改判后按最终颜色结算")
	game.request_pass_response()
	_expect(p2.hp == 2, "铁骑+鬼才组合后杀正常造成伤害")
	_prepare(&"guojia", &"xiahoudun")
	var judgement_card := DodgeCard.new(); judgement_card.suit = Card.Suit.HEART
	_set_hand(p1, []); _set_draw_top_first([judgement_card])
	game._start_judgement(&"bagua", p1, Callable(self, "_capture_judgement"), Callable(self, "_capture_judgement_done"))
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"tiandu", "天妒在统一判定后询问")
	game.request_confirm_skill()
	_expect(judgement_card in p1.hand, "天妒获得最终判定牌")
	## 国色+谦逊
	_prepare(&"daqiao", &"luxun")
	p2.is_ai = false
	var diamond := WineCard.new(); diamond.suit = Card.Suit.DIAMOND
	_set_hand(p1, [diamond]); _set_hand(p2, [])
	_expect(not game.can_use_skill(p1, p1.get_skill(&"guose")), "国色+谦逊组合拒绝陆逊为目标")
	## 最后手牌视为牌+连营（统一移动入口）
	_prepare(&"luxun", &"xiahoudun")
	p2.is_ai = false
	var view_card := PeachCard.new(); view_card.suit = Card.Suit.HEART
	_set_hand(p1, [view_card]); _set_draw_top_first([SlashCard.new()])
	var wusheng: Skill = SkillFactory.create_skill(&"wusheng")
	game._move_cards(p1, p1, [view_card], GameManager.CardZone.PROCESSING, "作为【武圣】代价", null, wusheng, null, Callable())
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "最后手牌作为视为牌代价后先结算连营")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 1, "连营摸牌后继续原 continuation")
	## 失去装备+枭姬/白银狮子按触发队列串行完成
	_prepare(&"sunshangxiang", &"xiahoudun")
	p2.is_ai = false
	p1.hp = 2; p1.hp_changed.emit(p1.hp, p1.max_hp)
	var lion := SilverLion.new()
	p1.armor = lion
	_set_hand(p1, []); _set_hand(p2, [])
	_set_draw_top_first([PeachCard.new(), WineCard.new()])
	game._move_cards(p1, p1, [lion], GameManager.CardZone.DISCARD, "测试离场", null, null, null, Callable())
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM, "失去装备触发离场触发队列")
	game.request_confirm_skill()
	_expect(p1.hand.size() == 2 and p1.hp == 3, "枭姬与白银狮子按触发队列完成（摸二+回复1）")
	## 急救+负体力濒死逐张回复
	_prepare(&"huatuo", &"xiahoudun", 1)
	p1.is_ai = false
	p1.hp = -1
	game.dying_player = p1
	game.rescue_actor = p1
	game.flow_state = GameManager.FlowState.DYING_RESCUE
	var r1 := PeachCard.new(); r1.suit = Card.Suit.HEART
	var r2 := WineCard.new(); r2.suit = Card.Suit.DIAMOND
	_set_hand(p1, [r1, r2])
	game.request_begin_skill(&"jijiu"); game.request_skill_toggle_hand_card(0)
	_expect(p1.hp == 0, "急救第一张回复一点")
	game.request_begin_skill(&"jijiu"); game.request_skill_toggle_hand_card(0)
	_expect(p1.hp == 1 and game.dying_player == null, "急救第二张回复一点并脱离濒死")


func _test_third_batch_ai() -> void:
	## AI 马超：目标有闪时优先发动铁骑
	_prepare(&"xiahoudun", &"machao", 1)
	p1.is_ai = false
	var red := PeachCard.new(); red.suit = Card.Suit.HEART
	_set_hand(p2, [SlashCard.new()]); _set_hand(p1, [DodgeCard.new()])
	_set_draw_top_first([red])
	game._play_slash(p2, p1, 0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"tieqi", "AI 马超进入铁骑询问")
	game._perform_ai_skill_confirm()
	_expect(game._slash_dodge_forbidden, "AI 铁骑按 should_ai_activate 判定")
	game.request_pass_response()
	_expect(p1.hp == 3, "AI 铁骑红判后目标不能闪")
	## AI 黄月英：合法锦囊使用后默认发动集智
	_prepare(&"xiahoudun", &"huangyueying", 1)
	p1.is_ai = false
	_set_hand(p2, [DismantleCard.new()]); _set_hand(p1, [DodgeCard.new()])
	_set_draw_top_first([PeachCard.new()])
	game._use_target_trick(p2, p1, 0)
	game._perform_ai_skill_confirm()
	_expect(p2.hand.size() == 1, "AI 集智默认发动摸一张")
	game._pass_nullification(p1); game._pass_nullification(p2)
	_expect(p1.hand.is_empty(), "AI 集智后锦囊继续结算")
	## AI 大乔：使用国色进入完整延时锦囊流程
	_prepare(&"xiahoudun", &"daqiao", 1)
	p1.is_ai = false
	var diamond := WineCard.new(); diamond.suit = Card.Suit.DIAMOND
	_set_hand(p2, [diamond]); _set_hand(p1, [])
	game._perform_ai_play()
	_expect(game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE, "AI 国色进入乐不思蜀无懈链")
	game._pass_nullification(p1); game._pass_nullification(p2)
	_expect(p1.indulgence_card != null, "AI 国色乐不思蜀置入目标判定区")
	## AI 陆逊：连营默认发动
	_prepare(&"xiahoudun", &"luxun", 1)
	p1.is_ai = false
	_set_hand(p2, [SlashCard.new()]); _set_hand(p1, [])
	_set_draw_top_first([DodgeCard.new()])
	game._play_slash(p2, p1, 0)
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "AI 陆逊使用最后手牌进入连营询问")
	game._perform_ai_skill_confirm()
	_expect(p2.hand.size() == 1, "AI 连营默认发动摸一张")
	## AI 孙尚香：1v1 无队友且自己满血时，不为敌方主公发动负收益结姻
	_prepare(&"xiahoudun", &"sunshangxiang", 1)
	p1.is_ai = false
	p1.hp = 2; p1.hp_changed.emit(p1.hp, p1.max_hp)
	var keep_dodge1 := DodgeCard.new(); var keep_dodge2 := DodgeCard.new()
	var keep_null1 := NullificationCard.new(); var keep_null2 := NullificationCard.new()
	_set_hand(p2, [keep_dodge1, keep_dodge2, keep_null1, keep_null2])
	_set_hand(p1, [])
	game._perform_ai_play()
	_expect(
		p1.hp == 2 and p2.hp == p2.max_hp and p2.hand.size() == 4,
		"满血 AI 孙尚香不会弃两张牌为敌方回复体力"
	)
	## AI 华佗：自己濒死回合外急救自救
	_prepare(&"xiahoudun", &"huatuo")
	p1.is_ai = false
	var red_ai := DodgeCard.new(); red_ai.suit = Card.Suit.HEART
	var red_ai3 := SlashCard.new(); red_ai3.suit = Card.Suit.DIAMOND
	_set_hand(p2, [red_ai, red_ai3])
	p2.hp = -1
	game.current_player_index = 0
	game.dying_player = p2
	game.rescue_actor = p2
	game.flow_state = GameManager.FlowState.DYING_RESCUE
	game._perform_ai_rescue()
	_expect(p2.hp == 0 and game.flow_state == GameManager.FlowState.DYING_RESCUE, "AI 华佗急救自救一次")
	game._perform_ai_rescue()
	_expect(p2.hp == 1 and game.dying_player == null, "AI 华佗第二次急救后脱离濒死")
	## AI 华佗：对敌方濒死不急救并明确放弃
	_prepare(&"xiahoudun", &"huatuo")
	p1.is_ai = false
	p1.hp = -1
	game._enter_dying(p1, Callable())
	_set_hand(p1, []); _set_hand(p2, [])
	var red_ai2 := PeachCard.new(); red_ai2.suit = Card.Suit.HEART
	p2.add_card(red_ai2)
	game.request_give_up_rescue()
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER, "AI 华佗不对敌方发动急救，全部放弃后死亡")
	## AI 貂蝉：闭月默认发动
	_prepare(&"xiahoudun", &"diaochan", 1)
	p1.is_ai = false
	_set_hand(p2, []); _set_draw_top_first([PeachCard.new()])
	game.phase = GameManager.Phase.END
	game.flow_state = GameManager.FlowState.IDLE
	game._finish_turn_from_end_phase()
	game._perform_ai_skill_confirm()
	_expect(p2.hand.size() == 1 and game.current_player_index == 0, "AI 闭月摸一张并只切换一次回合")
	## AI 大乔对流离不尝试：直接进入后续流程
	_prepare(&"xiahoudun", &"daqiao")
	p1.is_ai = false
	_set_hand(p2, []); _set_hand(p1, [SlashCard.new()])
	game._play_slash(p1, p2, 0)
	_expect(game.flow_state == GameManager.FlowState.RESPONDING_SLASH, "AI 大乔对流离不尝试，杀进入闪响应")
	game._perform_ai_response()
	_expect(p2.hp == 2, "AI 大乔不使用流离时杀正常结算")

func _test_aoe_dying_and_prompt_regression() -> void:
	## 回归：陆逊（及任何角色）打出 AOE 将对手打进濒死时，DYING_RESCUE 的
	## prompt_text 不得出现字符串格式化错误，UI 刷新不得中断；救援流程正常走通。
	_prepare(&"luxun", &"guanyu")
	p2.hp = 1; p2.hp_changed.emit(p2.hp, p2.max_hp)
	_set_hand(p1, [BarbarianInvasionCard.new(), DodgeCard.new()])
	_set_hand(p2, [PeachCard.new()])
	game.request_card_use(0)
	game._pass_nullification(p2)
	game._pass_nullification(p1)
	game._perform_ai_response()
	_expect(game.flow_state == GameManager.FlowState.DYING_RESCUE and game.dying_player == p2, "AOE 将对手打进濒死")
	var dying_prompt: String = game.prompt_text()
	_expect(
		dying_prompt.contains("濒死") and dying_prompt.contains("救援操作者"),
		"濒死提示文本正常生成（不得触发字符串格式化错误）"
	)
	game.rescue_actor = p1
	var other_prompt: String = game.prompt_text()
	_expect(other_prompt.contains("救援操作者"), "另一方救援提示文本正常生成")
	game.rescue_actor = p2
	game._perform_ai_rescue()
	_expect(p2.hp == 1 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "AOE 濒死被对手桃救回并回到出牌阶段")
	## 人类自己濒死时的提示与放弃流程
	_prepare(&"luxun", &"guanyu")
	_set_hand(p1, [PeachCard.new()])
	p1.hp = 0
	game._enter_dying(p1, Callable())
	_expect(game.flow_state == GameManager.FlowState.DYING_RESCUE and game.rescue_actor == p1, "人类濒死先获得自救机会")
	var self_prompt: String = game.prompt_text()
	_expect(self_prompt.contains("救援操作者"), "人类濒死提示正常")
	game.request_give_up_rescue()
	_expect(game.flow_state == GameManager.FlowState.GAME_OVER, "人类濒死放弃后正常死亡")


func _test_ai_iron_chain_regression() -> void:
	## 回归：AI 使用【铁索连环】（连上/重铸）以及“最后手牌装备触发连营”后，
	## 不得因 Callable 强类型数组绑定错误或 flow 停在 SKILL_RESOLVING 而卡死在“思考中”。
	## 1) AI 将人类连上并正常结束本回合
	_prepare(&"liubei", &"xiahoudun", 1)
	p1.hand = [DodgeCard.new(), PeachCard.new()]
	_set_hand(p2, [IronChainCard.new()])
	game._perform_ai_play()
	_expect(game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE, "AI 铁索连环进入无懈链")
	game._pass_nullification(p1)
	game._perform_ai_nullification()
	_expect(p1.chained, "AI 铁索连环将人类横置")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "AI 铁索连环后不卡死（回到出牌状态）")
	## 2) 人类已横置 → AI 重铸并摸一张
	_prepare(&"liubei", &"xiahoudun", 1)
	p1.chained = true
	_set_hand(p2, [IronChainCard.new()])
	_set_draw_top_first([DodgeCard.new()])
	game._perform_ai_play()
	_expect(p2.hand.size() == 1 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "AI 重铸铁索连环摸一张且不卡死")
	## 3) AI 用最后一张手牌装备（触发连营）后正常继续
	_prepare(&"liubei", &"luxun", 1)
	_set_hand(p2, [Crossbow.new()])
	_set_draw_top_first([DodgeCard.new()])
	game._perform_ai_play()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "AI 最后手牌装备触发连营")
	game._perform_ai_skill_confirm()
	_expect(p2.weapon != null and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "AI 装备+连营后回到出牌状态不卡死")


func _test_bagua_tiandu_slash_regression() -> void:
	## 回归：陆逊（人类）杀 AI 郭嘉，郭嘉八卦阵判定触发天妒后，
	## flow 不得停留在 SKILL_RESOLVING；红判抵消杀、黑判受伤害后都必须回到出牌阶段。
	## 黑判失败分支：郭嘉受 1 点伤害
	_prepare(&"luxun", &"guojia")
	_set_hand(p1, [SlashCard.new(), DodgeCard.new()])
	_set_hand(p2, [])
	p2.armor = EightTrigrams.new()
	var black := SlashCard.new(); black.suit = Card.Suit.SPADE
	_set_draw_top_first([black])
	game._play_slash(p1, p2, 0)
	game._perform_ai_response()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"tiandu", "八卦阵判定后触发天妒")
	game._perform_ai_skill_confirm()
	game._perform_ai_response()
	## 郭嘉受伤后还可能触发遗计，驱动 AI 完成分配。
	var guard: int = 0
	while guard < 20 and game.flow_state != GameManager.FlowState.PLAY_ACTIVE and game.flow_state != GameManager.FlowState.GAME_OVER:
		guard += 1
		if game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.skill_actor != null and game.skill_actor.is_ai:
			game._perform_ai_skill_confirm()
		elif game.flow_state == GameManager.FlowState.SKILL_ASSIGN_CARDS and game.private_card_owner != null and game.private_card_owner.is_ai:
			game._perform_ai_confirm_private_cards()
		else:
			break
	_expect(p2.hp == 2 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "黑判后天妒+八卦失败正常结算并回到出牌阶段")
	## 红判成功分支：八卦视为闪抵消杀
	_prepare(&"luxun", &"guojia")
	_set_hand(p1, [SlashCard.new(), DodgeCard.new()])
	_set_hand(p2, [])
	p2.armor = EightTrigrams.new()
	var red := PeachCard.new(); red.suit = Card.Suit.HEART
	_set_draw_top_first([red])
	game._play_slash(p1, p2, 0)
	game._perform_ai_response()
	game._perform_ai_skill_confirm()
	_expect(p2.hp == 3 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "红判后天妒+八卦成功抵消杀并回到出牌阶段")


func _test_serpent_spear_lianying_regression() -> void:
	## 回归：陆逊用丈八蛇矛两张牌当【杀】（出牌阶段使用 / 回合外响应），
	## 用完最后两张牌触发连营后不得卡死（必须在移动前捕获使用场景）。
	## 出牌阶段：丈八杀进入闪响应并正常结算
	_prepare(&"luxun", &"guanyu")
	p2.is_ai = false
	p1.weapon = SerpentSpear.new()
	_set_hand(p1, [PeachCard.new(), WineCard.new()])
	_set_hand(p2, [])
	_set_draw_top_first([DodgeCard.new()])
	game.request_serpent_spear()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "出牌阶段丈八蛇矛用完最后两张牌触发连营")
	game.request_confirm_skill()
	_expect(game.flow_state == GameManager.FlowState.RESPONDING_SLASH and p1.hand.size() == 1, "出牌阶段丈八杀进入闪响应且连营已摸一张")
	game.request_pass_response()
	_expect(p2.hp == 3 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "出牌阶段丈八杀正常造成伤害并回到出牌阶段")
	## 回合外响应：陆逊在决斗中用丈八蛇矛两张牌当杀
	_prepare(&"luxun", &"guanyu", 1)
	p1.weapon = SerpentSpear.new()
	_set_hand(p1, [PeachCard.new(), WineCard.new()])
	_set_hand(p2, [DuelCard.new()])
	_set_draw_top_first([SlashCard.new()])
	game._use_target_trick(p2, p1, 0)
	game._pass_nullification(p1)
	game._pass_nullification(p2)
	_expect(game.flow_state == GameManager.FlowState.DUEL_RESPONSE and game._duel_responder == p1, "决斗由陆逊先打出【杀】")
	game.request_serpent_spear()
	_expect(game.flow_state == GameManager.FlowState.SKILL_CONFIRM and game.pending_skill.id == &"lianying", "回合外丈八响应用完最后两张牌触发连营")
	game.request_confirm_skill()
	_expect(game.flow_state == GameManager.FlowState.DUEL_RESPONSE and game._duel_responder == p2, "回合外丈八杀接受后决斗正常轮换到对手")
	game._perform_ai_response()
	_expect(p2.hp == 3 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "回合外决斗丈八响应后正常结算并回到出牌阶段")


func _test_generation_reset() -> void:
	_prepare(&"sunshangxiang", &"huatuo")
	game.dying_player = p1
	game.rescue_actor = p2
	game._slash_dodge_forbidden = true
	game._liuli_slash_context = SlashTargetContext.new(p1, p2, [], Card.CardType.SLASH, 1)
	game._liuli_continue = Callable(self, "_noop")
	game._trigger_queue.append(TriggerEntry.new(p1, p1.get_skill(&"xiaoji"), CardMoveContext.new(p1, p1, [], "测试"), &"after_card_move"))
	var previous: int = game._action_generation
	game.begin_general_selection(false)
	_expect(
		game._action_generation > previous
		and game.rescue_actor == null
		and game.dying_player == null
		and not game._slash_dodge_forbidden
		and game._liuli_slash_context == null
		and game._trigger_queue.is_empty(),
		"重新选将清空第三批上下文、救援操作者并增加 generation"
	)
	## 旧 AI 回调携带旧 generation，不会在新对局中执行
	var old_generation: int = game._action_generation
	game._action_generation += 1
	game.setup_generals(&"sunshangxiang", &"xiahoudun")
	game.start_match(false)
	game._action_generation = old_generation
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.phase = GameManager.Phase.PLAY
	game._perform_ai_play()
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "旧 generation 的 AI 回调在新对局中失效")


func _noop() -> void:
	pass


func _capture_judgement(context: JudgementContext) -> void:
	pass


func _capture_judgement_done(context: JudgementContext) -> void:
	pass


func _prepare(player1_general: StringName, player2_general: StringName, active_index: int = 0) -> void:
	game._action_generation += 1
	p1.is_ai = false
	p2.is_ai = true
	_expect(game.setup_generals(player1_general, player2_general), "测试武将配置合法：%s/%s" % [player1_general, player2_general])
	game.start_match(false)
	game._action_generation += 1
	game.current_player_index = active_index
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.winner = null
	game.selected_hand_index = -1
	game.processing_cards.clear()
	game.discard_pile.clear()
	game.draw_pile = CardFactory.create_basic_deck()
	game.rescue_actor = null
	game.dying_player = null
	game._slash_dodge_forbidden = false
	game._reset_transient_contexts()
	game._clear_skill_context()
	p1.reset_turn_flags()
	p2.reset_turn_flags()


func _set_hand(player: BattlePlayer, cards: Array) -> void:
	player.hand.clear()
	for card: Card in cards:
		player.hand.append(card)
	player.hand_changed.emit()


func _set_draw_top_first(cards: Array) -> void:
	game.draw_pile.clear()
	for index: int in range(cards.size() - 1, -1, -1):
		game.draw_pile.append(cards[index])


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
