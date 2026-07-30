class_name Armor
extends "res://scripts/cards/equipment/Equipment.gd"
## 防具牌基类。


func _init(
	p_type: CardType,
	p_name: String,
	p_description: String,
	p_suit: Suit = Suit.NONE,
	p_rank: int = 0
) -> void:
	super(
		p_type,
		p_name,
		p_description,
		Color("4e8d79"),
		Slot.ARMOR,
		p_suit,
		p_rank
	)
