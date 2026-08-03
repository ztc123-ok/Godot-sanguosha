extends Node
## 纯 AI 自动化对战冒烟测试。
## 覆盖：
##  1) start_automated_match 无需任何 UI 交互直接开局（不卡 GENERAL_SELECTION / IDLE）；
##  2) 看门狗在 IDLE 死锁时自动补开首回合；
##  3) SkillFactory.create_skill_by_id 与 BattlePlayer 技能缝合 API；
##  4) Engine.time_scale = 100 下 AI vs AI 回合持续推进。
## 传入 --fuzz 时改为 30 秒墙钟预算的随机武将/随机技能死循环压测。

@onready var game: GameManager = $GameManager
@onready var p1: BattlePlayer = $GameManager/Players/Player1
@onready var p2: BattlePlayer = $GameManager/Players/Player2

var failures: Array[String] = []
var _fuzz_mode: bool = false
var _fuzz_matches_completed: int = 0


func _ready() -> void:
	Engine.time_scale = 100.0
	_fuzz_mode = "--fuzz" in (OS.get_cmdline_args() + OS.get_cmdline_user_args())
	await get_tree().process_frame
	await get_tree().process_frame

	if _fuzz_mode:
		await _run_fuzz()
	else:
		await _run_smoke()

	Engine.time_scale = 1.0
	if failures.is_empty():
		var label: String = "FUZZ" if _fuzz_mode else "SMOKE"
		print("AUTO_MATCH_%s_TEST: PASS (pure AI auto-play + watchdog + factory API)" % label)
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("AUTO_MATCH_TEST: %s" % failure)
		get_tree().quit(1)


func _run_smoke() -> void:
	_test_skill_factory_api()
	_test_automated_match_boot()
	await _test_idle_deadlock_recovery()
	await _test_skill_injection_and_turn_progress()
	await _test_random_combos_advance()


func _test_skill_factory_api() -> void:
	_expect(SkillFactory.create_skill_by_id(&"jizhi") != null, "create_skill_by_id 可创建技能")
	_expect(SkillFactory.create_skill_by_id(&"not_a_skill") == null, "未知技能 ID 安全返回 null")
	_expect(SkillFactory.is_valid_skill_id(&"jianxiong"), "is_valid_skill_id 识别合法技能")
	_expect(not SkillFactory.is_valid_skill_id(&"zzz"), "is_valid_skill_id 拒绝非法技能")
	_expect(SkillFactory.all_skill_ids().size() >= 37, "all_skill_ids 覆盖全部技能")
	_expect(GeneralFactory.skill_ids_of(&"simayi").size() == 2, "GeneralFactory.skill_ids_of 返回技能清单")
	_expect(GeneralFactory.skill_ids_of(&"zzz").is_empty(), "未知武将 skill_ids_of 安全返回空")
	_expect(p1.add_skill_id(&"jizhi"), "add_skill_id 注入成功")
	_expect(p1.has_skill(&"jizhi"), "注入后 has_skill 可见")
	_expect(not p1.add_skill_id(&"jizhi"), "重复注入被去重")
	_expect(p1.remove_skill(&"jizhi"), "remove_skill 移除成功")
	_expect(not p1.has_skill(&"jizhi"), "移除后技能不可见")


func _test_automated_match_boot() -> void:
	_expect(game.start_automated_match(&"caocao", &"lvbu"), "start_automated_match 接受确定性配置")
	_expect(game.is_automated_mode(), "自动化模式已启用")
	_expect(p1.is_ai and p2.is_ai, "双方均被标记为 AI")
	_expect(p1.general_id == &"caocao" and p2.general_id == &"lvbu", "武将按配置装配")
	_expect(game.flow_state == GameManager.FlowState.PLAY_ACTIVE, "开局直达出牌阶段（不卡选将/IDLE）")
	_expect(game.turn_number == 1, "首回合已开始")


func _test_idle_deadlock_recovery() -> void:
	## 模拟旧 fuzz 脚本：setup_generals + start_match(false) 后强行双 AI，
	## 无人驱动的 IDLE 死锁必须被看门狗自动补开首回合。
	game.start_automated_match(&"guanyu", &"lvbu")
	game._action_generation += 1
	game.phase = GameManager.Phase.START
	game.flow_state = GameManager.FlowState.IDLE
	game.turn_number = 0
	game.current_player_index = 0
	game.watchdog_interval = 0.15
	var guard: int = 0
	while game.turn_number == 0 and guard < 400:
		await get_tree().process_frame
		guard += 1
	_expect(game.turn_number >= 1, "IDLE 开局死锁被看门狗自愈（补开首回合）")
	_expect(game._watchdog_kick_count >= 1, "看门狗确实发生过自动步进")


func _test_skill_injection_and_turn_progress() -> void:
	game.watchdog_interval = 0.15
	_expect(
		game.start_automated_match(&"sunshangxiang", &"xiahoudun", [&"jizhi", &"lianying"], [&"ganglie"]),
		"注入额外技能开新局"
	)
	_expect(p1.has_skill(&"jizhi") and p1.has_skill(&"lianying"), "Player1 技能缝合成功")
	_expect(p2.has_skill(&"ganglie"), "Player2 技能缝合成功")
	var start_turn: int = game.turn_number
	var guard: int = 0
	while game.turn_number <= start_turn and guard < 800:
		await get_tree().process_frame
		guard += 1
	_expect(game.turn_number > start_turn, "AI vs AI（缝合技能）自动推进到下一回合")


func _test_random_combos_advance() -> void:
	var combos: Array = [
		[&"zhangfei", &"diaochan"],
		[&"simayi", &"huanggai"],
		[&"zhenji", &"zhugeliang"],
	]
	for combo: Array in combos:
		game.start_automated_match(combo[0], combo[1], [&"jizhi", &"qicai"], [&"guicai", &"kongcheng"])
		var start_turn: int = game.turn_number
		var guard: int = 0
		while game.turn_number <= start_turn + 1 and guard < 900:
			await get_tree().process_frame
			guard += 1
		_expect(
			game.turn_number > start_turn + 1,
			"组合 %s vs %s 自动推进至少 2 个回合" % [combo[0], combo[1]]
		)
		_expect(
			game.flow_state != GameManager.FlowState.GENERAL_SELECTION,
			"组合 %s vs %s 未卡在选将" % [combo[0], combo[1]]
		)


func _run_fuzz() -> void:
	## 30 秒墙钟预算：随机武将 + 随机技能缝合，验证死循环不卡死并统计看门狗自愈。
	var budget_ms: int = 30000
	var start_ms: int = Time.get_ticks_msec()
	var max_turn_seen: int = 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var all_generals: Array[StringName] = GeneralFactory.all_general_ids()
	var all_skills: Array[StringName] = SkillFactory.all_skill_ids()
	game.watchdog_interval = 0.25
	game.match_finished.connect(_on_fuzz_match_finished)

	while Time.get_ticks_msec() - start_ms < budget_ms:
		if game.flow_state == GameManager.FlowState.GAME_OVER:
			## 等待 GameManager 的自动重开定时器。
			await get_tree().process_frame
			continue
		var g1: StringName = all_generals[rng.randi_range(0, all_generals.size() - 1)]
		var g2: StringName = all_generals[rng.randi_range(0, all_generals.size() - 1)]
		if g1 == g2:
			g2 = all_generals[(all_generals.find(g1) + 1) % all_generals.size()]
		var s1: Array[StringName] = _random_skills(rng, all_skills)
		var s2: Array[StringName] = _random_skills(rng, all_skills)
		game.start_automated_match(g1, g2, s1, s2)
		var start_turn: int = game.turn_number
		var guard: int = 0
		while (
			game.turn_number <= start_turn
			and game.flow_state != GameManager.FlowState.GAME_OVER
			and guard < 1200
			and Time.get_ticks_msec() - start_ms < budget_ms
		):
			await get_tree().process_frame
			guard += 1
		_expect(
			game.flow_state != GameManager.FlowState.GENERAL_SELECTION
			and not (game.flow_state == GameManager.FlowState.IDLE and game.turn_number == 0),
			"fuzz 第 %d 局未卡死在选将/IDLE" % (_fuzz_matches_completed + 1)
		)
		max_turn_seen = maxi(max_turn_seen, game.turn_number)
		var settle: int = 0
		while (
			game.flow_state != GameManager.FlowState.GAME_OVER
			and settle < 600
			and Time.get_ticks_msec() - start_ms < budget_ms
		):
			await get_tree().process_frame
			settle += 1

	print("AUTO_MATCH_FUZZ: 完成 %d 局，看门狗自愈 %d 次，观察最高回合 %d" % [
		_fuzz_matches_completed,
		game._watchdog_kick_count,
		max_turn_seen,
	])


func _on_fuzz_match_finished(_winner: BattlePlayer, _loser: BattlePlayer) -> void:
	_fuzz_matches_completed += 1


func _random_skills(rng: RandomNumberGenerator, all_skills: Array[StringName]) -> Array[StringName]:
	var count: int = rng.randi_range(0, 3)
	var picked: Array[StringName] = []
	for _index: int in count:
		picked.append(all_skills[rng.randi_range(0, all_skills.size() - 1)])
	return picked


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
