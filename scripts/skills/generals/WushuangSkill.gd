class_name WushuangSkill
extends Skill


func _init() -> void:
	super(
		&"wushuang",
		"无双",
		"锁定技，你的【杀】需要两张【闪】抵消；与你决斗的角色每轮需要连续打出两张【杀】。",
		ActivationMode.MODIFIER,
		[SkillTag.LOCKED]
	)


func modify_response_required_count(
	context: RefCounted,
	responder: Node,
	current_count: int,
	_game: Node,
	owner: Node
) -> int:
	var use_context := context as SkillUseContext
	if use_context == null or use_context.user != owner or responder == owner:
		return current_count
	if use_context.effective_card_type in [Card.CardType.SLASH, Card.CardType.DUEL]:
		return maxi(current_count, 2)
	return current_count
