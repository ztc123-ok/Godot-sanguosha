extends Node

var failures: Array[String] = []

func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("FAILED: %s" % msg)
	else:
		print("PASSED: %s" % msg)

func _ready() -> void:
	var GameManager = load("res://scripts/GameManager.gd")
	var BattlePlayer = load("res://scripts/Player.gd")
	var DefensiveHorse = load("res://scripts/cards/equipment/horses/DefensiveHorse.gd")
	var OffensiveHorse = load("res://scripts/cards/equipment/horses/OffensiveHorse.gd")
	var MaShuSkill = load("res://scripts/skills/generals/MashuSkill.gd")
	var QicaiSkill = load("res://scripts/skills/generals/QicaiSkill.gd")
	var CardFactory = load("res://scripts/cards/CardFactory.gd")
	var Card = load("res://scripts/cards/Card.gd")
	var SlashTargetContextScript = load("res://scripts/skills/SlashTargetContext.gd")

	var game = GameManager.new()
	var p0 = BattlePlayer.new()
	var p1 = BattlePlayer.new()
	var p2 = BattlePlayer.new()
	var p3 = BattlePlayer.new()
	p0.player_name = "P0"
	p1.player_name = "P1"
	p2.player_name = "P2"
	p3.player_name = "P3"
	p0.role_name = "主公"
	p1.role_name = "反贼"
	p2.role_name = "反贼"
	p3.role_name = "反贼"
	game.players.append_array([p0, p1, p2, p3])

	print("===== DISTANCE SYSTEM COMPREHENSIVE TEST SUITE =====")

	# -------------------------------------------------------------
	# Test 1: Dead Player Skill Effect on Distance
	# -------------------------------------------------------------
	print("\n--- Test 1: Dead Player Skill Effect ---")
	p2.skills.append(MaShuSkill.new())
	p2.hp = 0 # P2 is DEAD
	p0.skills.append(MaShuSkill.new())
	p0.hp = 0 # P0 dead
	var dist_with_dead_p0 = game.distance_between(p0, p1)
	_expect(dist_with_dead_p0 == 1, "Dead player's MODIFIER skill does not affect distance")

	# Reset skills & hp
	p0.skills.clear()
	p2.skills.clear()
	p0.hp = 3
	p1.hp = 3
	p2.hp = 3
	p3.hp = 3

	# -------------------------------------------------------------
	# Test 2: Borrow Sword (借刀杀人) Distance & Target Rules
	# -------------------------------------------------------------
	print("\n--- Test 2: Borrow Sword (借刀杀人) Distance & Targeting ---")
	var borrow_card = CardFactory.create_card(Card.CardType.BORROW_SWORD)
	p1.weapon = CardFactory.create_card(Card.CardType.QINGGANG_SWORD)
	p1.horse_plus = DefensiveHorse.new()
	
	var borrow_valid_dist2 = game._is_valid_trick_target(borrow_card, p0, p1)
	_expect(borrow_valid_dist2, "Borrow Sword user -> Weapon owner has NO distance limit")

	p0.horse_plus = DefensiveHorse.new()
	p1.weapon = CardFactory.create_card(Card.CardType.CROSSBOW) # range 1
	var borrow_valid_can_reach_p2 = game._is_valid_trick_target(borrow_card, p0, p1)
	_expect(borrow_valid_can_reach_p2, "Borrow Sword on P1 valid when P1 can reach P2 (not locked to P0)")

	p0.horse_plus = null
	p1.horse_plus = null

	# -------------------------------------------------------------
	# Test 3: Supply Shortage (兵粮寸断) Distance Limit
	# -------------------------------------------------------------
	print("\n--- Test 3: Supply Shortage (兵粮寸断) Distance Limit ---")
	var supply_card = CardFactory.create_card(Card.CardType.SUPPLY_SHORTAGE)
	var supply_valid_dist2 = game._is_valid_trick_target(supply_card, p0, p2)
	_expect(not supply_valid_dist2, "Supply Shortage target distance > 1 is invalid")

	# -------------------------------------------------------------
	# Test 4: Steal (顺手牵羊) Target Card Area Validation
	# -------------------------------------------------------------
	print("\n--- Test 4: Steal (顺手牵羊) Target Card Area ---")
	var steal_card = CardFactory.create_card(Card.CardType.STEAL)
	p1.hand.clear()
	p1.horse_plus = DefensiveHorse.new()
	p0.horse_minus = OffensiveHorse.new()
	var steal_valid_no_hand = game._is_valid_trick_target(steal_card, p0, p1)
	_expect(steal_valid_no_hand, "Steal on target with 0 hand cards but 1 equipment is valid")

	p0.horse_minus = null
	p1.horse_plus = null

	# -------------------------------------------------------------
	# Test 5: Dismantle (过河拆桥) Judgment Zone
	# -------------------------------------------------------------
	print("\n--- Test 5: Dismantle (过河拆桥) Judgment Zone ---")
	var dismantle_card = CardFactory.create_card(Card.CardType.DISMANTLE)
	p1.hand.clear()
	p1.indulgence_card = CardFactory.create_card(Card.CardType.INDULGENCE)
	var dismantle_valid_judgment = game._is_valid_trick_target(dismantle_card, p0, p1)
	_expect(dismantle_valid_judgment, "Dismantle on target with 0 hand cards but 1 delayed trick is valid")
	_expect(game._has_any_dismantle_target(p0), "Dismantle availability includes targets with only delayed tricks")

	# -------------------------------------------------------------
	# Test 6: Liuli (流离) Target Candidate Check
	# -------------------------------------------------------------
	print("\n--- Test 6: Liuli (流离) Target Candidate Check ---")
	var slash_ctx = SlashTargetContextScript.new(p0, p1)
	var liuli_candidates = game.liuli_transfer_candidates(p1, slash_ctx)
	var p2_in_liuli = p2 in liuli_candidates
	_expect(p2_in_liuli, "Liuli candidate P2 is valid even if outside attacker P0's range")

	print("====================================================")
	## 这些 Node 未加入场景树，必须显式释放；延迟到当前 _ready 返回后再退出，
	## 让局部 Resource/RefCounted 引用先离开作用域，避免 ObjectDB/Resource 泄漏。
	game.players.clear()
	for player in [p0, p1, p2, p3]:
		player.free()
	game.free()
	if failures.is_empty():
		print("DISTANCE SYSTEM SUITE: ALL TESTS PASSED SUCCESSFULLY!")
		call_deferred("_quit_after_cleanup", 0)
	else:
		push_error("DISTANCE SYSTEM SUITE FAILED with %d errors" % failures.size())
		call_deferred("_quit_after_cleanup", 1)


func _quit_after_cleanup(exit_code: int) -> void:
	get_tree().quit(exit_code)
