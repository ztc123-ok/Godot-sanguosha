class_name SilverLionLeaveSkill
extends Skill
## 系统内置的装备离场效果：白银狮子离开装备区后回复1点体力。
## 由 GameManager 在统一失去装备入口直接构造触发项，按触发队列串行结算。

const CardMoveContextScript = preload("res://scripts/skills/CardMoveContext.gd")

func _init() -> void:
	super(
		&"silver_lion_leave",
		"白银狮子",
		"锁定技，装备区里的【白银狮子】离开装备区后，你回复1点体力。",
		ActivationMode.MODIFIER,
		[SkillTag.LOCKED]
	)

func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	var move := context as CardMoveContextScript
	if move == null or move.owner != owner:
		return false
	for card: Card in move.lost_equipment_cards():
		if card.card_type == Card.CardType.SILVER_LION:
			return true
	return false

func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {"action": "silver_lion_recover"}
