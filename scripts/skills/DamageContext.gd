class_name DamageContext
extends RefCounted
## 一次伤害事件的完整上下文；技能不得绕过 GameManager 直接应用伤害。

var source: Node
var target: Node
var amount: int
var nature: int
var source_card: Card
var source_cards: Array[Card] = []
var card_user: Node
var effective_card_type: int = -1
var reason: String = ""
var is_chain_transfer: bool = false
var ignore_armor: bool = false


func _init(
	p_source: Node = null,
	p_target: Node = null,
	p_amount: int = 0,
	p_nature: int = 0,
	p_source_card: Card = null,
	p_effective_card_type: int = -1,
	p_reason: String = "",
	p_is_chain_transfer: bool = false
) -> void:
	source = p_source
	target = p_target
	amount = p_amount
	nature = p_nature
	source_card = p_source_card
	if p_source_card != null:
		source_cards.append(p_source_card)
	effective_card_type = p_effective_card_type
	reason = p_reason
	is_chain_transfer = p_is_chain_transfer


func duplicate_for_target(new_target: Node, chain_transfer: bool) -> DamageContext:
	var copy := DamageContext.new(
		source,
		new_target,
		amount,
		nature,
		null if chain_transfer else source_card,
		effective_card_type,
		reason,
		chain_transfer
	)
	copy.source_cards.clear()
	if not chain_transfer:
		copy.source_cards.append_array(source_cards)
	copy.card_user = card_user
	copy.ignore_armor = ignore_armor and not chain_transfer
	return copy
