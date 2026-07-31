class_name PaoxiaoSkill
extends Skill


func _init() -> void:
	super(
		&"paoxiao",
		"咆哮",
		"锁定技，你在出牌阶段使用【杀】无次数限制。",
		ActivationMode.MODIFIER,
		[SkillTag.LOCKED]
	)


func modify_slash_limit(_current_limit: int, _game: Node, _owner: Node) -> int:
	return 999999
