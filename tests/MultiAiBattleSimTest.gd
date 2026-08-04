extends Node

func _ready() -> void:
	Engine.time_scale = 100.0
	var GameManagerScript = load("res://scripts/GameManager.gd")
	var BattlePlayerScript = load("res://scripts/Player.gd")
	var GeneralFactory = load("res://scripts/generals/GeneralFactory.gd")
	var SkillFactory = load("res://scripts/skills/SkillFactory.gd")

	print("===== STARTING 1v2 MULTI-AI SIMULATED BATTLE STRESS TEST =====")

	var all_generals: Array[StringName] = GeneralFactory.all_general_ids()
	var all_skills: Array[StringName] = SkillFactory.all_skill_ids()

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var total_matches: int = 20
	var matches_completed: int = 0
	var watchdog_kicks: int = 0
	var anomalies: Array[String] = []

	for match_idx in range(total_matches):
		var game = GameManagerScript.new()
		var players_node := Node.new()
		players_node.name = "Players"
		
		var p1 = BattlePlayerScript.new()
		p1.name = "Player1"
		p1.player_name = "Player1"
		p1.role_name = "主公"
		p1.is_ai = true

		var p2 = BattlePlayerScript.new()
		p2.name = "Player2"
		p2.player_name = "AI1"
		p2.role_name = "反贼"
		p2.is_ai = true

		var p3 = BattlePlayerScript.new()
		p3.name = "Player3"
		p3.player_name = "AI2"
		p3.role_name = "反贼"
		p3.is_ai = true

		players_node.add_child(p1)
		players_node.add_child(p2)
		players_node.add_child(p3)
		game.add_child(players_node)
		add_child(game)
		await get_tree().process_frame

		# Random General Assignment
		var g1: StringName = all_generals[rng.randi_range(0, all_generals.size() - 1)]
		var g2: StringName = all_generals[rng.randi_range(0, all_generals.size() - 1)]
		var g3: StringName = all_generals[rng.randi_range(0, all_generals.size() - 1)]

		game.player1 = p1
		game.player2 = p2
		var enemies_arr: Array[BattlePlayer] = [p2, p3]
		var players_arr: Array[BattlePlayer] = [p1, p2, p3]
		game.enemies = enemies_arr
		game.players = players_arr
		p1.assign_general(GeneralFactory.create_general(g1))
		p2.assign_general(GeneralFactory.create_general(g2))
		p3.assign_general(GeneralFactory.create_general(g3))
		game.watchdog_interval = 0.25
		game.start_match()
		## start_match 会按正式规则替换重复武将；后续诊断必须记录实际阵容，
		## 不能继续使用随机抽样阶段的重复标签。
		g1 = p1.general_id
		g2 = p2.general_id
		g3 = p3.general_id

		var start_turn: int = game.turn_number
		var initial_kicks: int = game._watchdog_kick_count
		var guard: int = 0
		var card_drift_seen: bool = false
		var watchdog_seen: bool = false

		# Run simulation loop for up to 8 turns per match
		while (
			game.flow_state != GameManagerScript.FlowState.GAME_OVER
			and game.turn_number <= start_turn + 8
			and guard < 4000
		):
			await get_tree().process_frame
			guard += 1
			if not watchdog_seen and game._watchdog_kick_count > initial_kicks:
				watchdog_seen = true
				print("WATCHDOG_FIRST: match=%d generals=%s/%s/%s turn=%d state=%s phase=%d pending_ai=%d" % [
					match_idx + 1, g1, g2, g3, game.turn_number,
					GameManagerScript.FlowState.keys()[game.flow_state], int(game.phase),
					game._pending_ai_action_count,
				])
			if not game.card_count_invariant_holds():
				card_drift_seen = true
				print("CARD_DRIFT_FIRST: match=%d generals=%s/%s/%s turn=%d state=%s count=%d/%d processing=%d private=%d revealed=%d" % [
					match_idx + 1, g1, g2, g3, game.turn_number,
					GameManagerScript.FlowState.keys()[game.flow_state],
					game.tracked_card_count(), game.match_card_count,
					game.processing_cards.size(), game.private_cards.size(), game.revealed_cards.size(),
				])
				break

		var current_kicks: int = game._watchdog_kick_count - initial_kicks
		if current_kicks > 0:
			watchdog_kicks += current_kicks
			anomalies.append("Match %d (%s vs %s, %s): Watchdog kicked %d times" % [match_idx + 1, g1, g2, g3, current_kicks])

		if game.flow_state == GameManagerScript.FlowState.GENERAL_SELECTION or (game.flow_state == GameManagerScript.FlowState.IDLE and game.turn_number == 0):
			anomalies.append("Match %d (%s vs %s, %s): Deadlocked at boot!" % [match_idx + 1, g1, g2, g3])
		if guard >= 4000:
			anomalies.append(
				"Match %d (%s vs %s, %s): Frame guard exhausted at turn %d, state %s!" % [
					match_idx + 1, g1, g2, g3, game.turn_number,
					GameManagerScript.FlowState.keys()[game.flow_state],
				]
			)

		# Check for potential data structure corruptions
		for p in game.players:
			if p.hp > p.max_hp:
				anomalies.append("Match %d: Player %s HP (%d) exceeded Max HP (%d)!" % [match_idx + 1, p.player_name, p.hp, p.max_hp])
			if p.is_dying() and p.hp > 0:
				anomalies.append("Match %d: Player %s marked dying but HP > 0!" % [match_idx + 1, p.player_name])
		if card_drift_seen or not game.card_count_invariant_holds():
			anomalies.append(
				"Match %d (%s vs %s, %s): Card count changed from %d to %d!" % [
					match_idx + 1, g1, g2, g3,
					game.match_card_count, game.tracked_card_count(),
				]
			)

		matches_completed += 1
		game.queue_free()
		await get_tree().process_frame

	Engine.time_scale = 1.0
	print("\n===== 1v2 MULTI-AI SIMULATION COMPLETE =====")
	print("Completed Matches: %d / %d" % [matches_completed, total_matches])
	print("Total Watchdog Auto-Recovery Kicks: %d" % watchdog_kicks)
	print("Anomalies Found: %d" % anomalies.size())
	for a: String in anomalies:
		print("  - %s" % a)
	
	if anomalies.is_empty():
		print("SIMULATION_SUITE: PASS (No state deadlocks, HP corruptions, or card-count drift)")
	else:
		print("SIMULATION_SUITE: ANOMALIES DETECTED")

	get_tree().quit(0)
