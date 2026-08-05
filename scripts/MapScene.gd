extends Control
## 序章线性地图：第一战 -> 第二战 -> 村落。

const BATTLE_SCENE := "res://scenes/Main.tscn"
const DEVELOPER_PANEL_SCENE := preload("res://scenes/DeveloperPanel.tscn")

@onready var first_battle_button: Button = %FirstBattleButton
@onready var second_battle_button: Button = %SecondBattleButton
@onready var village_button: Button = %VillageButton
@onready var developer_button: Button = %DeveloperButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	first_battle_button.pressed.connect(_start_battle.bind(1))
	second_battle_button.pressed.connect(_start_battle.bind(2))
	village_button.pressed.connect(_enter_village)
	developer_button.pressed.connect(_open_developer_panel)
	developer_button.visible = DeveloperLauncher.is_available()
	PrologueState.progress_changed.connect(_refresh)
	_refresh()
	## 带开发参数从项目主场景启动时，地图只承担一次转场职责。
	if DeveloperLauncher.has_pending_launch():
		call_deferred("_launch_developer_battle")


func _refresh() -> void:
	first_battle_button.disabled = not PrologueState.can_start_battle(1)
	second_battle_button.disabled = not PrologueState.can_start_battle(2)
	village_button.disabled = not PrologueState.can_enter_village()

	first_battle_button.text = "序章第一战%s" % _completion_mark(1)
	second_battle_button.text = "序章第二战%s" % _completion_mark(2)
	status_label.text = "序章进度：%d / 2" % PrologueState.completed_battles


func _completion_mark(battle_index: int) -> String:
	return "（已通过）" if PrologueState.completed_battles >= battle_index else ""


func _start_battle(battle_index: int) -> void:
	if PrologueState.start_battle(battle_index):
		get_tree().change_scene_to_file(BATTLE_SCENE)


func _open_developer_panel() -> void:
	if not DeveloperLauncher.is_available() or get_node_or_null("DeveloperPanel") != null:
		return
	## 使用引擎基类类型，避免首次检出时依赖尚未刷新的全局 class_name 缓存。
	var panel: Control = DEVELOPER_PANEL_SCENE.instantiate()
	panel.launch_requested.connect(_launch_developer_battle)
	add_child(panel)


func _launch_developer_battle() -> void:
	if DeveloperLauncher.has_pending_launch():
		get_tree().change_scene_to_file(BATTLE_SCENE)


func _enter_village() -> void:
	if not PrologueState.can_enter_village():
		return
	print("已通关序章，进入村落！")
	status_label.text = "已通关序章，进入村落！"
