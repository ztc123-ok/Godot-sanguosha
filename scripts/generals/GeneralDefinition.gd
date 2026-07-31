class_name GeneralDefinition
extends RefCounted
## 不可变武将定义。运行时状态保存在 BattlePlayer，定义本身不参与流程结算。

var id: StringName
var display_name: String
var kingdom: String
var max_hp: int
var skill_ids: PackedStringArray


func _init(
	p_id: StringName,
	p_display_name: String,
	p_kingdom: String,
	p_max_hp: int,
	p_skill_ids: PackedStringArray
) -> void:
	id = p_id
	display_name = p_display_name
	kingdom = p_kingdom
	max_hp = p_max_hp
	skill_ids = p_skill_ids

