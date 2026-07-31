class_name SkillUseContext
extends RefCounted
## 一次实体牌或虚拟牌的使用/打出上下文。

var user: Node
var physical_cards: Array[Card] = []
var effective_card_type: Card.CardType = Card.CardType.SLASH
var source_skill: RefCounted
var target: Node
var is_virtual: bool = false
var reason: String = ""


func _init(
	p_user: Node = null,
	p_physical_cards: Array[Card] = [],
	p_effective_card_type: Card.CardType = Card.CardType.SLASH,
	p_source_skill: RefCounted = null,
	p_target: Node = null,
	p_is_virtual: bool = false,
	p_reason: String = ""
) -> void:
	user = p_user
	physical_cards = p_physical_cards
	effective_card_type = p_effective_card_type
	source_skill = p_source_skill
	target = p_target
	is_virtual = p_is_virtual
	reason = p_reason


func primary_physical_card() -> Card:
	return physical_cards[0] if not physical_cards.is_empty() else null
