class_name Card
extends RefCounted
## 卡牌基类。卡牌仅描述自身规则；牌堆、手牌和结算由管理器负责。

enum CardType {
	SLASH,
	DODGE,
	PEACH,
	WINE,
}

var card_type: CardType
var display_name: String
var description: String
var accent_color: Color


func _init(
	p_type: CardType,
	p_name: String,
	p_description: String,
	p_color: Color
) -> void:
	card_type = p_type
	display_name = p_name
	description = p_description
	accent_color = p_color


func can_use_in_play(_game: Node, _user: Node) -> bool:
	return false


func can_use_as_response(_game: Node, _user: Node) -> bool:
	return false


func can_use_while_dying(_game: Node, _user: Node) -> bool:
	return false

