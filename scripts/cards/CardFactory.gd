class_name CardFactory
extends RefCounted
## 基础牌堆工厂。仅生成本版本实现的四种基础牌。


static func create_card(card_type: Card.CardType) -> Card:
	match card_type:
		Card.CardType.SLASH:
			return SlashCard.new()
		Card.CardType.DODGE:
			return DodgeCard.new()
		Card.CardType.PEACH:
			return PeachCard.new()
		Card.CardType.WINE:
			return WineCard.new()
	return SlashCard.new()


static func create_basic_deck() -> Array[Card]:
	var deck: Array[Card] = []
	_append_cards(deck, Card.CardType.SLASH, 14)
	_append_cards(deck, Card.CardType.DODGE, 8)
	_append_cards(deck, Card.CardType.PEACH, 6)
	_append_cards(deck, Card.CardType.WINE, 4)
	deck.shuffle()
	return deck


static func _append_cards(deck: Array[Card], card_type: Card.CardType, count: int) -> void:
	for _index: int in count:
		deck.append(create_card(card_type))

