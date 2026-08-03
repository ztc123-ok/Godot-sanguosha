class_name SkillFactory
extends RefCounted
## 技能对象工厂。GameManager 不按武将名硬编码技能。

const JianxiongScript = preload("res://scripts/skills/generals/JianxiongSkill.gd")
const TuxiScript = preload("res://scripts/skills/generals/TuxiSkill.gd")
const LuoyiScript = preload("res://scripts/skills/generals/LuoyiSkill.gd")
const WushengScript = preload("res://scripts/skills/generals/WushengSkill.gd")
const PaoxiaoScript = preload("res://scripts/skills/generals/PaoxiaoSkill.gd")
const LongdanScript = preload("res://scripts/skills/generals/LongdanSkill.gd")
const QixiScript = preload("res://scripts/skills/generals/QixiSkill.gd")
const ZhihengScript = preload("res://scripts/skills/generals/ZhihengSkill.gd")
const WushuangScript = preload("res://scripts/skills/generals/WushuangSkill.gd")
const FankuiScript = preload("res://scripts/skills/generals/FankuiSkill.gd")
const GuicaiScript = preload("res://scripts/skills/generals/GuicaiSkill.gd")
const GanglieScript = preload("res://scripts/skills/generals/GanglieSkill.gd")
const TianduScript = preload("res://scripts/skills/generals/TianduSkill.gd")
const YijiScript = preload("res://scripts/skills/generals/YijiSkill.gd")
const QingguoScript = preload("res://scripts/skills/generals/QingguoSkill.gd")
const LuoshenScript = preload("res://scripts/skills/generals/LuoshenSkill.gd")
const RendeScript = preload("res://scripts/skills/generals/RendeSkill.gd")
const GuanxingScript = preload("res://scripts/skills/generals/GuanxingSkill.gd")
const KongchengScript = preload("res://scripts/skills/generals/KongchengSkill.gd")
const KejiScript = preload("res://scripts/skills/generals/KejiSkill.gd")
const KurouScript = preload("res://scripts/skills/generals/KurouSkill.gd")
const YingziScript = preload("res://scripts/skills/generals/YingziSkill.gd")
const FanjianScript = preload("res://scripts/skills/generals/FanjianSkill.gd")
const MashuScript = preload("res://scripts/skills/generals/MashuSkill.gd")
const TieqiScript = preload("res://scripts/skills/generals/TieqiSkill.gd")
const JizhiScript = preload("res://scripts/skills/generals/JizhiSkill.gd")
const QicaiScript = preload("res://scripts/skills/generals/QicaiSkill.gd")
const GuoseScript = preload("res://scripts/skills/generals/GuoseSkill.gd")
const LiuliScript = preload("res://scripts/skills/generals/LiuliSkill.gd")
const QianxunScript = preload("res://scripts/skills/generals/QianxunSkill.gd")
const LianyingScript = preload("res://scripts/skills/generals/LianyingSkill.gd")
const JieyinScript = preload("res://scripts/skills/generals/JieyinSkill.gd")
const XiaojiScript = preload("res://scripts/skills/generals/XiaojiSkill.gd")
const JijiuScript = preload("res://scripts/skills/generals/JijiuSkill.gd")
const QingnangScript = preload("res://scripts/skills/generals/QingnangSkill.gd")
const LijianScript = preload("res://scripts/skills/generals/LijianSkill.gd")
const BiyueScript = preload("res://scripts/skills/generals/BiyueSkill.gd")

## 技能注册表：唯一事实来源。新增技能只需在此登记一行。
const SKILL_REGISTRY: Dictionary = {
	&"jianxiong": JianxiongScript,
	&"tuxi": TuxiScript,
	&"luoyi": LuoyiScript,
	&"wusheng": WushengScript,
	&"paoxiao": PaoxiaoScript,
	&"longdan": LongdanScript,
	&"qixi": QixiScript,
	&"zhiheng": ZhihengScript,
	&"wushuang": WushuangScript,
	&"fankui": FankuiScript,
	&"guicai": GuicaiScript,
	&"ganglie": GanglieScript,
	&"tiandu": TianduScript,
	&"yiji": YijiScript,
	&"qingguo": QingguoScript,
	&"luoshen": LuoshenScript,
	&"rende": RendeScript,
	&"guanxing": GuanxingScript,
	&"kongcheng": KongchengScript,
	&"keji": KejiScript,
	&"kurou": KurouScript,
	&"yingzi": YingziScript,
	&"fanjian": FanjianScript,
	&"mashu": MashuScript,
	&"tieqi": TieqiScript,
	&"jizhi": JizhiScript,
	&"qicai": QicaiScript,
	&"guose": GuoseScript,
	&"liuli": LiuliScript,
	&"qianxun": QianxunScript,
	&"lianying": LianyingScript,
	&"jieyin": JieyinScript,
	&"xiaoji": XiaojiScript,
	&"jijiu": JijiuScript,
	&"qingnang": QingnangScript,
	&"lijian": LijianScript,
	&"biyue": BiyueScript,
}


static func create_skill(skill_id: StringName) -> Skill:
	var script: GDScript = SKILL_REGISTRY.get(skill_id)
	if script == null:
		return null
	return script.new()


## 对外统一、安全的静态 API：未知 ID 返回 null，绝不抛 Parse Error。
static func create_skill_by_id(skill_id: StringName) -> Skill:
	return create_skill(skill_id)


static func is_valid_skill_id(skill_id: StringName) -> bool:
	return SKILL_REGISTRY.has(skill_id)


static func all_skill_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in SKILL_REGISTRY.keys():
		result.append(id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result
