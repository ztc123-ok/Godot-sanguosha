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
		&"fankui": return FankuiScript.new()
		&"guicai": return GuicaiScript.new()
		&"ganglie": return GanglieScript.new()
		&"tiandu": return TianduScript.new()
		&"yiji": return YijiScript.new()
		&"qingguo": return QingguoScript.new()
		&"luoshen": return LuoshenScript.new()
		&"rende": return RendeScript.new()
		&"guanxing": return GuanxingScript.new()
		&"kongcheng": return KongchengScript.new()
		&"keji": return KejiScript.new()
		&"kurou": return KurouScript.new()
		&"yingzi": return YingziScript.new()
		&"fanjian": return FanjianScript.new()
	return null
