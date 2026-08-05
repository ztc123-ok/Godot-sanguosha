class_name DeveloperPanel
extends Control
## 调试构建中的开发启动面板；所有配置最终交给 DeveloperLauncher。

signal launch_requested

@onready var battle_option: OptionButton = %BattleOption
@onready var player_option: OptionButton = %PlayerOption
@onready var enemy_slots: VBoxContainer = %EnemySlots
@onready var skip_selection_check: CheckButton = %SkipSelectionCheck
@onready var status_label: Label = %StatusLabel

var enemy_options: Array[OptionButton] = []


func _ready() -> void:
	_fill_battle_option()
	_fill_general_option(player_option)
	_select_general(player_option, &"caocao")
	skip_selection_check.button_pressed = true
	%LaunchButton.pressed.connect(_on_launch)
	%CancelButton.pressed.connect(queue_free)
	var restored_enemy_ids := _restore_last_configuration()
	_rebuild_enemy_options(restored_enemy_ids)
	battle_option.item_selected.connect(_on_battle_changed)


func _fill_battle_option() -> void:
	for battle: Dictionary in BattleCatalog.all_definitions(true):
		var enemy_count := int(battle.get("enemy_count", 1))
		battle_option.add_item("%s（1v%d）" % [battle.get("display_name", battle.get("id")), enemy_count])
		battle_option.set_item_metadata(battle_option.item_count - 1, battle.get("id"))
	var preferred_index := _battle_option_index(&"prologue_2")
	if preferred_index >= 0:
		battle_option.select(preferred_index)


func _fill_general_option(option: OptionButton) -> void:
	for definition: GeneralDefinition in GeneralFactory.all_generals():
		option.add_item("%s · %s · %d体力" % [
			definition.display_name,
			definition.kingdom,
			definition.max_hp,
		])
		option.set_item_metadata(option.item_count - 1, definition.id)


func _restore_last_configuration() -> Array[StringName]:
	var previous: Dictionary = DeveloperLauncher.last_configuration()
	if previous.is_empty():
		return []
	var battle_id := StringName(previous.get(
		"battle_id",
		BattleCatalog.id_for_legacy_index(int(previous.get("battle_index", 2)))
	))
	var battle_index := _battle_option_index(battle_id)
	if battle_index >= 0:
		battle_option.select(battle_index)
	_select_general(player_option, previous.get("player_general_id", &"caocao"))
	skip_selection_check.button_pressed = bool(previous.get("skip_general_selection", true))
	var result: Array[StringName] = []
	for enemy_id: Variant in previous.get("enemy_general_ids", []):
		result.append(StringName(enemy_id))
	return result


func _battle_option_index(battle_id: StringName) -> int:
	for index: int in battle_option.item_count:
		if StringName(battle_option.get_item_metadata(index)) == battle_id:
			return index
	return -1


func _select_general(option: OptionButton, general_id: StringName) -> void:
	for index: int in option.item_count:
		if StringName(option.get_item_metadata(index)) == general_id:
			option.select(index)
			return


func _on_battle_changed(_selected_index: int) -> void:
	_rebuild_enemy_options(_selected_enemy_ids())


func _rebuild_enemy_options(preferred_ids: Array[StringName] = []) -> void:
	for child: Node in enemy_slots.get_children():
		child.queue_free()
	enemy_options.clear()
	var battle_id := StringName(battle_option.get_selected_metadata())
	var slots: Array[Dictionary] = BattleCatalog.enemy_slots_for(battle_id)
	var battle := BattleCatalog.definition(battle_id)
	var allow_duplicates := bool(battle.get("allow_duplicate_generals", false))
	var used: Array[StringName] = [StringName(player_option.get_selected_metadata())]
	for index: int in slots.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.custom_minimum_size = Vector2(120, 0)
		label.text = str(slots[index].get("label", "敌方武将 %d" % (index + 1)))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var option := OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fill_general_option(option)
		row.add_child(option)
		enemy_slots.add_child(row)
		enemy_options.append(option)
		var preferred_id: StringName = &""
		if index < preferred_ids.size():
			preferred_id = preferred_ids[index]
		if not GeneralFactory.is_valid_id(preferred_id) or (not allow_duplicates and preferred_id in used):
			preferred_id = StringName(slots[index].get("default_general_id", &""))
		if not GeneralFactory.is_valid_id(preferred_id) or (not allow_duplicates and preferred_id in used):
			preferred_id = _first_unused_general(used)
		_select_general(option, preferred_id)
		if not allow_duplicates:
			used.append(preferred_id)
	status_label.text = "已生成 %d 个敌方选将槽位；开发启动不受章节进度限制。" % slots.size()
	status_label.tooltip_text = "战斗 ID：%s" % battle.get("id", battle_id)


func _first_unused_general(used: Array[StringName]) -> StringName:
	for general_id: StringName in GeneralFactory.all_general_ids():
		if general_id not in used:
			return general_id
	return &""


func _selected_enemy_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for option: OptionButton in enemy_options:
		result.append(StringName(option.get_selected_metadata()))
	return result


func _on_launch() -> void:
	var battle_id := StringName(battle_option.get_selected_metadata())
	var accepted := DeveloperLauncher.request_launch(
		battle_id,
		StringName(player_option.get_selected_metadata()),
		_selected_enemy_ids(),
		skip_selection_check.button_pressed
	)
	if not accepted:
		status_label.text = DeveloperLauncher.last_error()
		return
	launch_requested.emit()
	queue_free()
