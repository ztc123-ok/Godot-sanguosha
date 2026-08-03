class_name GeneralFactory
extends RefCounted
## 标准版 25 名武将的唯一定义入口。

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
	&"simayi",
	&"xiahoudun",
	&"guojia",
	&"zhenji",
	&"liubei",
	&"zhugeliang",
	&"lvmeng",
	&"huanggai",
	&"zhouyu",
	&"machao",
	&"huangyueying",
	&"daqiao",
	&"luxun",
	&"sunshangxiang",
	&"huatuo",
	&"diaochan",
]

const FEMALE_GENERALS: Array[StringName] = [
	&"zhenji",
	&"huangyueying",
	&"daqiao",
	&"sunshangxiang",
	&"diaochan",
]


static func gender_of(general_id: StringName) -> GeneralDefinition.Gender:
	return GeneralDefinition.Gender.FEMALE if general_id in FEMALE_GENERALS else GeneralDefinition.Gender.MALE


static func create_general(general_id: StringName) -> GeneralDefinition:
	var gender: GeneralDefinition.Gender = gender_of(general_id)
	match general_id:
		&"caocao":
			return GeneralDefinition.new(&"caocao", "曹操", "魏", 4, PackedStringArray(["jianxiong"]), gender)
		&"zhangliao":
			return GeneralDefinition.new(&"zhangliao", "张辽", "魏", 4, PackedStringArray(["tuxi"]), gender)
		&"xuchu":
			return GeneralDefinition.new(&"xuchu", "许褚", "魏", 4, PackedStringArray(["luoyi"]), gender)
		&"guanyu":
			return GeneralDefinition.new(&"guanyu", "关羽", "蜀", 4, PackedStringArray(["wusheng"]), gender)
		&"zhangfei":
			return GeneralDefinition.new(&"zhangfei", "张飞", "蜀", 4, PackedStringArray(["paoxiao"]), gender)
		&"zhaoyun":
			return GeneralDefinition.new(&"zhaoyun", "赵云", "蜀", 4, PackedStringArray(["longdan"]), gender)
		&"ganning":
			return GeneralDefinition.new(&"ganning", "甘宁", "吴", 4, PackedStringArray(["qixi"]), gender)
		&"sunquan":
			return GeneralDefinition.new(&"sunquan", "孙权", "吴", 4, PackedStringArray(["zhiheng"]), gender)
		&"lvbu":
			return GeneralDefinition.new(&"lvbu", "吕布", "群", 4, PackedStringArray(["wushuang"]), gender)
		&"simayi":
			return GeneralDefinition.new(&"simayi", "司马懿", "魏", 3, PackedStringArray(["fankui", "guicai"]), gender)
		&"xiahoudun":
			return GeneralDefinition.new(&"xiahoudun", "夏侯惇", "魏", 4, PackedStringArray(["ganglie"]), gender)
		&"guojia":
			return GeneralDefinition.new(&"guojia", "郭嘉", "魏", 3, PackedStringArray(["tiandu", "yiji"]), gender)
		&"zhenji":
			return GeneralDefinition.new(&"zhenji", "甄姬", "魏", 3, PackedStringArray(["qingguo", "luoshen"]), gender)
		&"liubei":
			return GeneralDefinition.new(&"liubei", "刘备", "蜀", 4, PackedStringArray(["rende"]), gender)
		&"zhugeliang":
			return GeneralDefinition.new(&"zhugeliang", "诸葛亮", "蜀", 3, PackedStringArray(["guanxing", "kongcheng"]), gender)
		&"lvmeng":
			return GeneralDefinition.new(&"lvmeng", "吕蒙", "吴", 4, PackedStringArray(["keji"]), gender)
		&"huanggai":
			return GeneralDefinition.new(&"huanggai", "黄盖", "吴", 4, PackedStringArray(["kurou"]), gender)
		&"zhouyu":
			return GeneralDefinition.new(&"zhouyu", "周瑜", "吴", 3, PackedStringArray(["yingzi", "fanjian"]), gender)
		&"machao":
			return GeneralDefinition.new(&"machao", "马超", "蜀", 4, PackedStringArray(["mashu", "tieqi"]), gender)
		&"huangyueying":
			return GeneralDefinition.new(&"huangyueying", "黄月英", "蜀", 3, PackedStringArray(["jizhi", "qicai"]), gender)
		&"daqiao":
			return GeneralDefinition.new(&"daqiao", "大乔", "吴", 3, PackedStringArray(["guose", "liuli"]), gender)
		&"luxun":
			return GeneralDefinition.new(&"luxun", "陆逊", "吴", 3, PackedStringArray(["qianxun", "lianying"]), gender)
		&"sunshangxiang":
			return GeneralDefinition.new(&"sunshangxiang", "孙尚香", "吴", 3, PackedStringArray(["jieyin", "xiaoji"]), gender)
		&"huatuo":
			return GeneralDefinition.new(&"huatuo", "华佗", "群", 3, PackedStringArray(["jijiu", "qingnang"]), gender)
		&"diaochan":
			return GeneralDefinition.new(&"diaochan", "貂蝉", "群", 3, PackedStringArray(["lijian", "biyue"]), gender)
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
