class_name MashuSkill
extends Skill
## 马术：锁定技，计算你到其他角色的距离时 -1；全部距离修正完成后统一下限为 1。

func _init() -> void:
	super(
		&"mashu",
		"马术",
		"锁定技，当你计算与其他角色的距离时，始终 -1。可与-1马叠加；最终距离最低为1。",
		ActivationMode.MODIFIER,
		[SkillTag.LOCKED]
	)


func modify_distance(current_distance: int, source: Node, _target: Node, _game: Node, owner: Node) -> int:
	if source == owner:
		return current_distance - 1
	return current_distance
