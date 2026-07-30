class_name Equipment
extends Card
## 装备牌基类。装备只保存所属槽位，实际替换与失去装备结算由 GameManager 统一处理。

enum Slot {
	WEAPON,
	ARMOR,
	HORSE_PLUS,
	HORSE_MINUS,
}

var equipment_slot: Slot


func _init(
	p_type: CardType,
	p_name: String,
	p_description: String,
	p_color: Color,
	p_slot: Slot,
	p_suit: Suit = Suit.NONE,
	p_rank: int = 0
) -> void:
	super(
		p_type,
		p_name,
		p_description,
		p_color,
		CardCategory.EQUIPMENT,
		p_suit,
		p_rank,
		false,
		TargetMode.SELF
	)
	equipment_slot = p_slot


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_equip(user)
