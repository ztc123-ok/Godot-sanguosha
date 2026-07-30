class_name Horse
extends "res://scripts/cards/equipment/Equipment.gd"
## 坐骑牌基类。双人局距离修正由 GameManager.distance_between 统一计算。

var distance_modifier: int


func _init(
	p_type: CardType,
	p_name: String,
	p_description: String,
	p_slot: Slot,
	p_modifier: int,
	p_suit: Suit = Suit.NONE,
	p_rank: int = 0
) -> void:
	super(
		p_type,
		p_name,
		p_description,
		Color("7b68a7"),
		p_slot,
		p_suit,
		p_rank
	)
	distance_modifier = p_modifier
