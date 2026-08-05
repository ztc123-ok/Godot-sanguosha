extends RefCounted
## 配置数据到战斗修正实例的唯一构造入口。

const BattleModifierScript = preload("res://scripts/battle/BattleModifier.gd")
const LoneArmyModifierScript = preload("res://scripts/battle/modifiers/LoneArmyModifier.gd")


static func create_modifier(spec: Dictionary, owner: Node) -> RefCounted:
	var modifier_id: StringName = StringName(spec.get("id", &""))
	var source_kind: BattleModifierScript.SourceKind = BattleModifierScript.SourceKind.BATTLE
	match StringName(spec.get("source", &"BATTLE")):
		&"CHARACTER":
			source_kind = BattleModifierScript.SourceKind.CHARACTER
		&"SCENE":
			source_kind = BattleModifierScript.SourceKind.SCENE
	match modifier_id:
		&"lone_army":
			return LoneArmyModifierScript.new(
				owner,
				source_kind,
				int(spec.get("draw_bonus_per_extra_enemy", 1))
			)
	return null
