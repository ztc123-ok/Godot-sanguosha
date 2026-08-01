extends Node
## 序章地图的线性解锁与村落入口回归测试。

var failures: Array[String] = []


func _ready() -> void:
	PrologueState.completed_battles = 0
	PrologueState.active_battle = 0

	var map: Control = load("res://scenes/MapScene.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame

	var first_button: Button = map.get_node("%FirstBattleButton")
	var second_button: Button = map.get_node("%SecondBattleButton")
	var village_button: Button = map.get_node("%VillageButton")
	var status_label: Label = map.get_node("%StatusLabel")

	_expect(not first_button.disabled, "第一战初始可进入")
	_expect(second_button.disabled, "第二战初始锁定")
	_expect(village_button.disabled, "村落初始锁定")
	_expect(not PrologueState.start_battle(2), "不能跳过第一战")

	_expect(PrologueState.start_battle(1), "可以开始第一战")
	PrologueState.complete_active_battle()
	_expect(not second_button.disabled, "第一战胜利后解锁第二战")
	_expect(village_button.disabled, "第一战后村落仍锁定")

	_expect(PrologueState.start_battle(2), "可以开始第二战")
	PrologueState.complete_active_battle()
	_expect(not village_button.disabled, "第二战胜利后解锁村落")
	village_button.pressed.emit()
	_expect(status_label.text == "已通关序章，进入村落！", "进入村落时显示通关提示")

	if failures.is_empty():
		print("PROLOGUE_SMOKE_TEST: PASS (linear unlock + village entry)")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("PROLOGUE_SMOKE_TEST: %s" % failure)
		get_tree().quit(1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
