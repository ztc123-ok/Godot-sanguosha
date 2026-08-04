extends Node

func _ready():
	var GameManager = load("res://scripts/GameManager.gd")
	var BattlePlayer = load("res://scripts/Player.gd")
	var DefensiveHorse = load("res://scripts/cards/equipment/horses/DefensiveHorse.gd")
	var OffensiveHorse = load("res://scripts/cards/equipment/horses/OffensiveHorse.gd")
	var MaShuSkill = load("res://scripts/skills/generals/MashuSkill.gd")
	
	var game = GameManager.new()
	var p0 = BattlePlayer.new()
	var p1 = BattlePlayer.new()
	var p2 = BattlePlayer.new()
	var p3 = BattlePlayer.new()
	p0.player_name = "P0"
	p1.player_name = "P1"
	p2.player_name = "P2"
	p3.player_name = "P3"
	
	game.players.append_array([p0, p1, p2, p3])
	
	var failures = []
	var assert_dist = func(src, tgt, expected, msg):
		var actual = game.distance_between(src, tgt)
		if actual != expected:
			failures.append(msg + " (Expected %d, got %d)" % [expected, actual])
			
	print("--- Running MultiPlayerDistanceTest ---")
	
	# 1. Base distance (4 players)
	assert_dist.call(p0, p1, 1, "P0 -> P1 base distance should be 1")
	assert_dist.call(p0, p2, 2, "P0 -> P2 base distance should be 2")
	assert_dist.call(p0, p3, 1, "P0 -> P3 base distance should be 1 (circular)")
	assert_dist.call(p1, p3, 2, "P1 -> P3 base distance should be 2")
	
	# 2. Horse Modifiers
	p1.horse_plus = DefensiveHorse.new()
	assert_dist.call(p0, p1, 2, "P0 -> P1 with P1 +1 horse should be 2")
	
	p0.horse_minus = OffensiveHorse.new()
	assert_dist.call(p0, p1, 1, "P0 -> P1 with P0 -1 horse and P1 +1 horse should be 1")
	assert_dist.call(p0, p2, 1, "P0 -> P2 with P0 -1 horse should be 1")
	
	p1.horse_plus = null
	p0.horse_minus = null
	
	# 3. Death skipping
	p2.hp = 0 # Mark P2 as dead/dying
	assert_dist.call(p1, p3, 1, "P1 -> P3 distance should be 1 after P2 dies")
	
	p2.hp = 3 # Revive P2
	
	# 4. Skill modifier (Mashu)
	p0.skills.append(MaShuSkill.new())
	assert_dist.call(p0, p2, 1, "P0 -> P2 with Mashu should be 1")

	## 这些节点未加入场景树，退出前必须显式释放；同时清空闭包，避免测试自身制造泄漏噪声。
	assert_dist = Callable()
	game.players.clear()
	for player in [p0, p1, p2, p3]:
		player.free()
	game.free()

	if failures.is_empty():
		print("MULTI_PLAYER_DISTANCE_TEST: PASS")
		call_deferred("_quit_after_cleanup", 0)
	else:
		for f in failures:
			push_error(f)
		call_deferred("_quit_after_cleanup", 1)


func _quit_after_cleanup(exit_code: int) -> void:
	get_tree().quit(exit_code)

