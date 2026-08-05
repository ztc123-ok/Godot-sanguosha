extends Node
## 开发启动配置的唯一入口。
## 仅负责收集、校验和传递启动意图，不直接操作战斗领域状态。

signal configuration_changed

const DEFAULT_PLAYER_GENERAL: StringName = &"caocao"

var _pending_configuration: Dictionary = {}
var _last_configuration: Dictionary = {}
var _session_active: bool = false
var _last_error: String = ""


func _ready() -> void:
	parse_command_line(PackedStringArray(OS.get_cmdline_args() + OS.get_cmdline_user_args()))


func is_available() -> bool:
	return OS.is_debug_build()


func request_launch(
	battle_selector: Variant,
	player_general_id: StringName = DEFAULT_PLAYER_GENERAL,
	enemy_general_ids: Array[StringName] = [],
	skip_general_selection: bool = true
) -> bool:
	if not is_available():
		_last_error = "开发者入口仅允许在调试构建中使用。"
		return false
	var battle_id := BattleCatalog.resolve_battle_id(battle_selector)
	_last_error = _validate_configuration(battle_id, player_general_id, enemy_general_ids)
	if not _last_error.is_empty():
		return false
	var legacy_index := BattleCatalog.legacy_index_for_id(battle_id)
	_pending_configuration = {
		"battle_id": battle_id,
		## 保留字段供旧工具读取；非序章战斗为 0。
		"battle_index": legacy_index,
		"player_general_id": player_general_id,
		"enemy_general_ids": enemy_general_ids.duplicate(),
		"skip_general_selection": skip_general_selection,
	}
	_last_configuration = _pending_configuration.duplicate(true)
	_session_active = false
	## 开发入口有意绕过章节进度；正常地图按钮仍使用对应章节状态对象。
	BattleSession.activate_battle(battle_id)
	configuration_changed.emit()
	return true


func has_pending_launch() -> bool:
	return not _pending_configuration.is_empty()


func pending_configuration() -> Dictionary:
	return _pending_configuration.duplicate(true)


func last_configuration() -> Dictionary:
	return _last_configuration.duplicate(true)


func consume_launch_configuration() -> Dictionary:
	var result: Dictionary = _pending_configuration.duplicate(true)
	_pending_configuration.clear()
	_session_active = not result.is_empty()
	configuration_changed.emit()
	return result


func is_session_active() -> bool:
	return _session_active


func end_session() -> void:
	_session_active = false
	configuration_changed.emit()


func cancel_pending_launch() -> void:
	_pending_configuration.clear()
	_session_active = false
	configuration_changed.emit()


func last_error() -> String:
	return _last_error


## 支持：
## --dev-battle=prologue_2 --dev-player=caocao --dev-enemies=lvbu,zhangliao --dev-skip-selection
func parse_command_line(arguments: PackedStringArray) -> bool:
	var battle_selector: String = ""
	var player_general_id: StringName = DEFAULT_PLAYER_GENERAL
	var enemy_general_ids: Array[StringName] = []
	var skip_general_selection: bool = false
	for argument: String in arguments:
		if argument.begins_with("--dev-battle="):
			battle_selector = argument.trim_prefix("--dev-battle=").strip_edges()
		elif argument.begins_with("--dev-player="):
			player_general_id = StringName(argument.trim_prefix("--dev-player="))
		elif argument.begins_with("--dev-enemies="):
			enemy_general_ids.clear()
			for general_text: String in argument.trim_prefix("--dev-enemies=").split(",", false):
				enemy_general_ids.append(StringName(general_text.strip_edges()))
		elif argument == "--dev-skip-selection":
			skip_general_selection = true
		elif argument == "--dev-show-selection":
			skip_general_selection = false
	if battle_selector.is_empty():
		return false
	var accepted := request_launch(
		battle_selector,
		player_general_id,
		enemy_general_ids,
		skip_general_selection
	)
	if not accepted:
		push_warning("开发启动参数无效：%s" % _last_error)
	return accepted


func _validate_configuration(
	battle_id: StringName,
	player_general_id: StringName,
	enemy_general_ids: Array[StringName]
) -> String:
	if battle_id == &"" or not BattleCatalog.has_battle(battle_id):
		return "战斗 ID 无效或尚未注册。"
	if not GeneralFactory.is_valid_id(player_general_id):
		return "玩家武将 ID 无效：%s" % player_general_id
	var battle := BattleCatalog.definition(battle_id)
	var enemy_count := int(battle.get("enemy_count", 1))
	if enemy_general_ids.size() > enemy_count:
		return "战斗【%s】最多配置 %d 名敌方武将。" % [battle.get("display_name", battle_id), enemy_count]
	var allow_duplicates := bool(battle.get("allow_duplicate_generals", false))
	var used: Array[StringName] = [player_general_id]
	for general_id: StringName in enemy_general_ids:
		if not GeneralFactory.is_valid_id(general_id):
			return "敌方武将 ID 无效：%s" % general_id
		if not allow_duplicates and general_id in used:
			return "阵容中的武将不能重复：%s" % general_id
		used.append(general_id)
	return ""
