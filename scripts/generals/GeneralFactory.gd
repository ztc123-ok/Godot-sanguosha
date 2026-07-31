class_name GeneralFactory
extends RefCounted
## 首批九名武将的唯一定义入口。

const DEFAULT_PLAYER_GENERAL: StringName = &"caocao"
const DEFAULT_AI_GENERAL: StringName = &"lvbu"

const GENERAL_ORDER: Array[StringName] = [
	&"caocao",
	&"zhangliao",
	&"xuchu",
	&"guanyu",
	&"zhangfei",
	&"zhaoyun",
	&"ganning",
	&"sunquan",
	&"lvbu",
]


static func create_general(general_id: StringName) -> GeneralDefinition:
	match general_id:
		&"caocao":
			return GeneralDefinition.new(&"caocao", "曹操", "魏", 4, PackedStringArray(["jianxiong"]))
		&"zhangliao":
			return GeneralDefinition.new(&"zhangliao", "张辽", "魏", 4, PackedStringArray(["tuxi"]))
		&"xuchu":
			return GeneralDefinition.new(&"xuchu", "许褚", "魏", 4, PackedStringArray(["luoyi"]))
		&"guanyu":
			return GeneralDefinition.new(&"guanyu", "关羽", "蜀", 4, PackedStringArray(["wusheng"]))
		&"zhangfei":
			return GeneralDefinition.new(&"zhangfei", "张飞", "蜀", 4, PackedStringArray(["paoxiao"]))
		&"zhaoyun":
			return GeneralDefinition.new(&"zhaoyun", "赵云", "蜀", 4, PackedStringArray(["longdan"]))
		&"ganning":
			return GeneralDefinition.new(&"ganning", "甘宁", "吴", 4, PackedStringArray(["qixi"]))
		&"sunquan":
			return GeneralDefinition.new(&"sunquan", "孙权", "吴", 4, PackedStringArray(["zhiheng"]))
		&"lvbu":
			return GeneralDefinition.new(&"lvbu", "吕布", "群", 4, PackedStringArray(["wushuang"]))
	return null


static func all_general_ids() -> Array[StringName]:
	return GENERAL_ORDER.duplicate()


static func all_generals() -> Array[GeneralDefinition]:
	var result: Array[GeneralDefinition] = []
	for general_id: StringName in GENERAL_ORDER:
		result.append(create_general(general_id))
	return result


static func is_valid_id(general_id: StringName) -> bool:
	return general_id in GENERAL_ORDER

