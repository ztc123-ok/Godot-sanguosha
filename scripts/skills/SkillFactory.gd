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


static func create_skill(skill_id: StringName) -> Skill:
	match skill_id:
		&"jianxiong":
			return JianxiongScript.new()
		&"tuxi":
			return TuxiScript.new()
		&"luoyi":
			return LuoyiScript.new()
		&"wusheng":
			return WushengScript.new()
		&"paoxiao":
			return PaoxiaoScript.new()
		&"longdan":
			return LongdanScript.new()
		&"qixi":
			return QixiScript.new()
		&"zhiheng":
			return ZhihengScript.new()
		&"wushuang":
			return WushuangScript.new()
	return null

