extends Node
## 基础牌 + 全部标准锦囊的无界面回归测试。

@onready var game: GameManager = $GameManager
@onready var p1: BattlePlayer = $GameManager/Players/Player1
@onready var p2: BattlePlayer = $GameManager/Players/Player2

var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	game._action_generation += 1

	_test_factory_contains_every_card()
	_test_basic_slash_dodge_wine_and_dying()
	_test_dismantle()
	_test_steal()
	_test_draw_two_and_nullification_chain()
	_test_duel()
	_test_borrow_sword()
	_test_amazing_grace()
	_test_peach_garden()
	_test_barbarian_invasion()
	_test_arrow_barrage()
	_test_iron_chain_and_recast()
	_test_fire_attack_and_chain_damage()
	_test_indulgence()
	_test_supply_shortage()
	_test_lightning_hit_and_pass()
	_test_hand_limit_discard()

	if failures.is_empty():
		print("RULE_SMOKE_TEST: PASS (basic + 15 trick cards)")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("RULE_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)


func _test_factory_contains_every_card() -> void:
	var deck: Array[Card] = CardFactory.create_basic_deck()
	var found: Dictionary = {}
	for card: Card in deck:
		found[card.card_type] = true
		_expect(card.suit != Card.Suit.NONE and card.rank in range(1, 14), "牌堆每张牌都有合法花色点数")
	for type: Card.CardType in Card.CardType.values():
		_expect(found.has(type), "牌堆包含 CardType=%d" % type)


func _test_basic_slash_dodge_wine_and_dying() -> void:
	_prepare_play()
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [DodgeCard.new()])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(p2.hp == 4, "【闪】抵消【杀】")

	_prepare_play()
	p1.wine_active = true
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(p2.hp == 2 and not p1.wine_active, "酒杀造成 2 点伤害并消耗酒效果")

	_prepare_play()
	p1.wine_active = true
	p2.hp = 1
	_set_hand(p1, [SlashCard.new()])
	_set_hand(p2, [PeachCard.new(), WineCard.new()])
	game.request_card_on_target(0, 1)
	game._perform_ai_response()
	_expect(p2.hp == -1 and game.flow_state == GameManager.FlowState.DYING_RESCUE, "负体力进入濒死")
	game._perform_ai_rescue()
	game._perform_ai_rescue()
	_expect(p2.hp == 1 and game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "连续自救直到体力为 1")


func _test_dismantle() -> void:
	_prepare_play()
	p2.weapon_card = WeaponCard.new()
	_set_hand(p1, [DismantleCard.new()])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	_expect(p2.weapon_card == null, "【过河拆桥】可弃置目标武器")


func _test_steal() -> void:
	_prepare_play()
	var peach := PeachCard.new()
	_set_hand(p1, [StealCard.new()])
	_set_hand(p2, [peach])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	_expect(p2.hand.is_empty() and p1.hand.has(peach), "【顺手牵羊】获得目标手牌")


func _test_draw_two_and_nullification_chain() -> void:
	_prepare_play()
	_set_hand(p1, [DrawTwoCard.new(), NullificationCard.new()])
	_set_hand(p2, [NullificationCard.new()])
	game.request_card_use(0)
	game._play_nullification(p2, 0)
	game._play_nullification(p1, 0)
	game._pass_nullification(p2)
	game._pass_nullification(p1)
	_expect(p1.hand.size() == 2, "双层【无懈可击】后【无中生有】恢复生效并摸两张")


func _test_duel() -> void:
	_prepare_play()
	_set_hand(p1, [DuelCard.new()])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	_expect(game.flow_state == GameManager.FlowState.DUEL_RESPONSE, "【决斗】由目标先出杀")
	game._pass_current_response()
	_expect(p2.hp == 3, "决斗首先不出杀者受到 1 点伤害")


func _test_borrow_sword() -> void:
	_prepare_play()
	var weapon := WeaponCard.new()
	p2.weapon_card = weapon
	_set_hand(p1, [BorrowSwordCard.new()])
	_set_hand(p2, [])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	game._borrow_give_weapon()
	_expect(p2.weapon_card == null and p1.hand.has(weapon), "【借刀杀人】不出杀则交出武器")


func _test_amazing_grace() -> void:
	_prepare_play()
	_set_hand(p1, [AmazingGraceCard.new()])
	_set_hand(p2, [])
	game.request_card_use(0)
	_pass_nullification_chain()
	_expect(game.flow_state == GameManager.FlowState.CHOOSING_REVEALED and game.revealed_cards.size() == 2, "【五谷丰登】亮出两张牌")
	game.request_revealed_card(0)
	_pass_nullification_chain()
	game._perform_ai_amazing_grace()
	_expect(p1.hand.size() == 1 and p2.hand.size() == 1 and game.revealed_cards.is_empty(), "双方各选择并获得一张五谷牌")


func _test_peach_garden() -> void:
	_prepare_play()
	p1.hp = 3
	p2.hp = 3
	_set_hand(p1, [PeachGardenCard.new()])
	game.request_card_use(0)
	_pass_nullification_chain()
	_pass_nullification_chain()
	_expect(p1.hp == 4 and p2.hp == 4, "【桃园结义】令双方各回复 1 点体力")


func _test_barbarian_invasion() -> void:
	_prepare_play()
	_set_hand(p1, [BarbarianInvasionCard.new()])
	_set_hand(p2, [])
	game.request_card_use(0)
	_pass_nullification_chain()
	game._perform_ai_response()
	_expect(p2.hp == 3, "【南蛮入侵】未出杀受到 1 点伤害")


func _test_arrow_barrage() -> void:
	_prepare_play()
	_set_hand(p1, [ArrowBarrageCard.new()])
	_set_hand(p2, [])
	game.request_card_use(0)
	_pass_nullification_chain()
	game._perform_ai_response()
	_expect(p2.hp == 3, "【万箭齐发】未出闪受到 1 点伤害")


func _test_iron_chain_and_recast() -> void:
	_prepare_play()
	_set_hand(p1, [IronChainCard.new()])
	game.request_card_use(0)
	game.request_option(2)
	_pass_nullification_chain()
	_pass_nullification_chain()
	_expect(p1.chained and p2.chained, "【铁索连环】可同时横置双方")

	_prepare_play()
	_set_hand(p1, [IronChainCard.new()])
	var before: int = game.draw_pile.size()
	game.request_card_use(0)
	game.request_option(3)
	_expect(p1.hand.size() == 1 and game.draw_pile.size() == before - 1, "【铁索连环】可重铸并摸一张")


func _test_fire_attack_and_chain_damage() -> void:
	_prepare_play()
	p1.chained = true
	p2.chained = true
	var discard_match := PeachCard.new()
	discard_match.suit = Card.Suit.HEART
	discard_match.rank = 7
	var revealed := DodgeCard.new()
	revealed.suit = Card.Suit.HEART
	revealed.rank = 2
	_set_hand(p1, [FireAttackCard.new(), discard_match])
	_set_hand(p2, [revealed])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	game.request_fire_discard(0)
	_expect(p2.hp == 3 and p1.hp == 3, "火攻造成火焰伤害并按目标优先传导")
	_expect(not p1.chained and not p2.chained, "属性伤害后所有相关连环状态重置")


func _test_indulgence() -> void:
	_prepare_play()
	_set_hand(p1, [IndulgenceCard.new()])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	_expect(p2.indulgence_card != null, "【乐不思蜀】进入目标判定区")
	var result := SlashCard.new()
	result.suit = Card.Suit.SPADE
	result.rank = 1
	_begin_forced_judgement(p2, result)
	_pass_nullification_chain()
	_expect(game._skip_play_phase and game.phase == GameManager.Phase.DISCARD, "乐判定非红桃跳过出牌阶段")


func _test_supply_shortage() -> void:
	_prepare_play()
	_set_hand(p1, [SupplyShortageCard.new()])
	game.request_card_on_target(0, 1)
	_pass_nullification_chain()
	var result := SlashCard.new()
	result.suit = Card.Suit.HEART
	result.rank = 8
	_begin_forced_judgement(p2, result)
	_pass_nullification_chain()
	_expect(game._skip_draw_phase and game.phase == GameManager.Phase.PLAY, "兵粮判定非梅花跳过摸牌阶段")
	_expect(p2.hand.is_empty(), "被兵粮跳过摸牌时未获得两张牌")


func _test_lightning_hit_and_pass() -> void:
	_prepare_play()
	_set_hand(p1, [LightningCard.new()])
	game.request_card_use(0)
	_pass_nullification_chain()
	var hit := SlashCard.new()
	hit.suit = Card.Suit.SPADE
	hit.rank = 5
	_begin_forced_judgement(p1, hit)
	_pass_nullification_chain()
	_expect(p1.hp == 1 and p1.lightning_card == null, "闪电黑桃 2~9 造成 3 点雷电伤害并弃置")

	_prepare_play()
	_set_hand(p1, [LightningCard.new()])
	game.request_card_use(0)
	_pass_nullification_chain()
	var miss := SlashCard.new()
	miss.suit = Card.Suit.HEART
	miss.rank = 5
	_begin_forced_judgement(p1, miss)
	_pass_nullification_chain()
	_expect(p2.lightning_card != null and p1.lightning_card == null, "闪电未命中则传递给下一名角色")


func _test_hand_limit_discard() -> void:
	_prepare_play()
	p1.hp = 2
	_set_hand(p1, [SlashCard.new(), DodgeCard.new(), PeachCard.new(), WineCard.new()])
	game.request_end_play_phase()
	game.request_discard(0)
	game.request_discard(0)
	_expect(p1.hand.size() == 2 and game.phase == GameManager.Phase.END, "弃牌到当前体力上限")


func _prepare_play() -> void:
	game._action_generation += 1
	p1.reset_for_match()
	p2.reset_for_match()
	game.draw_pile = CardFactory.create_basic_deck()
	game.discard_pile.clear()
	game.revealed_cards.clear()
	game.current_player_index = 0
	game.phase = GameManager.Phase.PLAY
	game.flow_state = GameManager.FlowState.PLAY_ACTIVE
	game.selected_hand_index = -1
	game.winner = null


func _begin_forced_judgement(player: BattlePlayer, result: Card) -> void:
	game._action_generation += 1
	game.current_player_index = game.player_index(player)
	game._skip_draw_phase = false
	game._skip_play_phase = false
	game.draw_pile.append(result)
	game._begin_judgement_phase()


func _pass_nullification_chain() -> void:
	var guard: int = 0
	while game.flow_state == GameManager.FlowState.NULLIFICATION_RESPONSE and guard < 4:
		var responder: BattlePlayer = game.players[game._nullification_responder_index]
		game._pass_nullification(responder)
		guard += 1


func _set_hand(player: BattlePlayer, cards: Array) -> void:
	player.hand.clear()
	for card: Card in cards:
		player.hand.append(card)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
