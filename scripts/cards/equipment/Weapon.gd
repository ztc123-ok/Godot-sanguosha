class_name Weapon
extends "res://scripts/cards/equipment/Equipment.gd"
## 武器牌基类。攻击范围至少为 1；具体技能由 GameManager 按 card_type 触发。

var attack_range: int


func _init(
	p_type: CardType,
	p_name: String,
	p_description: String,
	p_range: int,
	p_suit: Suit = Suit.NONE,
	p_rank: int = 0
) -> void:
	super(
		p_type,
		p_name,
		p_description,
		Color("c58a45"),
		Slot.WEAPON,
		p_suit,
		p_rank
	)
	attack_range = maxi(p_range, 1)
