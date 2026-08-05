extends Node
## 全项目战斗定义的唯一注册目录。
## 新章节、事件战、BOSS 战和开发测试战斗都通过 register_battle() 接入。

const REQUIRED_FIELDS: PackedStringArray = ["id", "display_name", "enemy_count"]

const BUILTIN_DEFINITIONS := [
	{
		"id": &"prologue_1",
		"display_name": "序章第一战",
		"chapter_id": &"prologue",
		"chapter_battle_index": 1,
		"legacy_index": 1,
		"enemy_count": 1,
		"enemy_slots": [{"label": "反贼武将 1", "default_general_id": &"lvbu"}],
		"combat_modifiers": [],
		"kill_reward": &"",
		"developer_enabled": true,
	},
	{
		"id": &"prologue_2",
		"display_name": "序章第二战",
		"chapter_id": &"prologue",
		"chapter_battle_index": 2,
		"legacy_index": 2,
		"enemy_count": 2,
		"enemy_slots": [
			{"label": "反贼武将 1", "default_general_id": &"lvbu"},
			{"label": "反贼武将 2", "default_general_id": &"zhangliao"},
		],
		"combat_modifiers": [
			{
				"id": &"lone_army",
				"target": &"PLAYER",
				"source": &"BATTLE",
				"draw_bonus_per_extra_enemy": 1,
			},
		],
		"kill_reward": &"heal_one_or_draw_two",
		"developer_enabled": true,
	},
]

var _definitions: Dictionary = {}
var _display_order: Array[StringName] = []


func _init() -> void:
	for definition: Dictionary in BUILTIN_DEFINITIONS:
		register_battle(definition)


func register_battle(definition: Dictionary, replace_existing: bool = false) -> bool:
	var normalized := _normalized_definition(definition)
	if normalized.is_empty():
		return false
	var battle_id: StringName = normalized["id"]
	if _definitions.has(battle_id) and not replace_existing:
		return false
	if not _definitions.has(battle_id):
		_display_order.append(battle_id)
	_definitions[battle_id] = normalized
	return true


func unregister_battle(battle_id: StringName) -> bool:
	if not _definitions.has(battle_id):
		return false
	_definitions.erase(battle_id)
	_display_order.erase(battle_id)
	return true


func has_battle(battle_id: StringName) -> bool:
	return _definitions.has(battle_id)


func definition(battle_id: StringName) -> Dictionary:
	return _definitions.get(battle_id, {}).duplicate(true)


func all_definitions(developer_only: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for battle_id: StringName in _display_order:
		var battle: Dictionary = _definitions[battle_id]
		if developer_only and not bool(battle.get("developer_enabled", true)):
			continue
		result.append(battle.duplicate(true))
	return result


func resolve_battle_id(selector: Variant) -> StringName:
	if selector is StringName or selector is String:
		var text := str(selector).strip_edges()
		var direct_id := StringName(text)
		if has_battle(direct_id):
			return direct_id
		if text.is_valid_int():
			return id_for_legacy_index(text.to_int())
	elif selector is int or selector is float:
		return id_for_legacy_index(int(selector))
	return &""


func id_for_legacy_index(index: int) -> StringName:
	for battle_id: StringName in _display_order:
		if int(_definitions[battle_id].get("legacy_index", 0)) == index:
			return battle_id
	return &""


func legacy_index_for_id(battle_id: StringName) -> int:
	return int(_definitions.get(battle_id, {}).get("legacy_index", 0))


func enemy_slots_for(battle_id: StringName) -> Array[Dictionary]:
	var battle := definition(battle_id)
	var enemy_count := int(battle.get("enemy_count", 1))
	var configured_slots: Array = battle.get("enemy_slots", [])
	var result: Array[Dictionary] = []
	for index: int in enemy_count:
		var slot: Dictionary = {}
		if index < configured_slots.size() and configured_slots[index] is Dictionary:
			slot = configured_slots[index].duplicate(true)
		slot["index"] = index
		slot["label"] = str(slot.get("label", "敌方武将 %d" % (index + 1)))
		result.append(slot)
	return result


func _normalized_definition(source: Dictionary) -> Dictionary:
	for field: String in REQUIRED_FIELDS:
		if not source.has(field):
			push_error("战斗定义缺少字段：%s" % field)
			return {}
	var battle_id := StringName(source.get("id", &""))
	var enemy_count := int(source.get("enemy_count", 0))
	if battle_id == &"" or str(source.get("display_name", "")).is_empty() or enemy_count < 1:
		push_error("战斗定义的 id、display_name 或 enemy_count 无效。")
		return {}
	var normalized := source.duplicate(true)
	normalized["id"] = battle_id
	normalized["enemy_count"] = enemy_count
	normalized["combat_modifiers"] = normalized.get("combat_modifiers", [])
	normalized["kill_reward"] = StringName(normalized.get("kill_reward", &""))
	normalized["developer_enabled"] = bool(normalized.get("developer_enabled", true))
	normalized["allow_duplicate_generals"] = bool(normalized.get("allow_duplicate_generals", false))
	normalized["return_scene"] = str(normalized.get("return_scene", "res://scenes/MapScene.tscn"))
	normalized["failure_scene"] = str(normalized.get("failure_scene", normalized["return_scene"]))
	normalized["retry_on_loss"] = bool(normalized.get("retry_on_loss", true))
	normalized["enemy_slots"] = normalized.get("enemy_slots", [])
	return normalized
