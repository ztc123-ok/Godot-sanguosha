class_name GeneralDefinition
extends RefCounted
## 不可变武将定义。运行时状态保存在 BattlePlayer，定义本身不参与流程结算。

enum Gender {
	MALE,
	FEMALE,
}

var id: StringName
var display_name: String
var kingdom: String
var max_hp: int
var gender: Gender = Gender.MALE
var skill_ids: PackedStringArray


func _init(
	p_id: StringName,
	p_display_name: String,
	p_kingdom: String,
	p_max_hp: int,
	p_skill_ids: PackedStringArray,
	p_gender: Gender = Gender.MALE
) -> void:
	id = p_id
	display_name = p_display_name
	kingdom = p_kingdom
	max_hp = p_max_hp
	skill_ids = p_skill_ids
	gender = p_gender


func gender_text() -> String:
	return "女性" if gender == Gender.FEMALE else "男性"
