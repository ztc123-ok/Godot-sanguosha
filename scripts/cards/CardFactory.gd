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
		Card.CardType.DISMANTLE:
			return DismantleCard.new()
		Card.CardType.STEAL:
			return StealCard.new()
		Card.CardType.DRAW_TWO:
			return DrawTwoCard.new()
		Card.CardType.DUEL:
			return DuelCard.new()
		Card.CardType.BORROW_SWORD:
			return BorrowSwordCard.new()
		Card.CardType.AMAZING_GRACE:
			return AmazingGraceCard.new()
		Card.CardType.PEACH_GARDEN:
			return PeachGardenCard.new()
		Card.CardType.NULLIFICATION:
			return NullificationCard.new()
		Card.CardType.BARBARIAN_INVASION:
			return BarbarianInvasionCard.new()
		Card.CardType.ARROW_BARRAGE:
			return ArrowBarrageCard.new()
		Card.CardType.IRON_CHAIN:
			return IronChainCard.new()
		Card.CardType.FIRE_ATTACK:
			return FireAttackCard.new()
		Card.CardType.INDULGENCE:
			return IndulgenceCard.new()
		Card.CardType.SUPPLY_SHORTAGE:
			return SupplyShortageCard.new()
		Card.CardType.LIGHTNING:
			return LightningCard.new()
		Card.CardType.WEAPON:
			return WeaponCard.new()
	return SlashCard.new()


static func create_basic_deck() -> Array[Card]:
	var deck: Array[Card] = []
	_append_cards(deck, Card.CardType.SLASH, 14)
	_append_cards(deck, Card.CardType.DODGE, 8)
	_append_cards(deck, Card.CardType.PEACH, 6)
	_append_cards(deck, Card.CardType.WINE, 4)
	_append_cards(deck, Card.CardType.DISMANTLE, 6)
	_append_cards(deck, Card.CardType.STEAL, 5)
	_append_cards(deck, Card.CardType.DRAW_TWO, 4)
	_append_cards(deck, Card.CardType.DUEL, 3)
	_append_cards(deck, Card.CardType.BORROW_SWORD, 2)
	_append_cards(deck, Card.CardType.AMAZING_GRACE, 2)
	_append_cards(deck, Card.CardType.PEACH_GARDEN, 1)
	_append_cards(deck, Card.CardType.NULLIFICATION, 7)
	_append_cards(deck, Card.CardType.BARBARIAN_INVASION, 3)
	_append_cards(deck, Card.CardType.ARROW_BARRAGE, 1)
	_append_cards(deck, Card.CardType.IRON_CHAIN, 6)
	_append_cards(deck, Card.CardType.FIRE_ATTACK, 3)
	_append_cards(deck, Card.CardType.INDULGENCE, 3)
	_append_cards(deck, Card.CardType.SUPPLY_SHORTAGE, 2)
	_append_cards(deck, Card.CardType.LIGHTNING, 2)
	_append_cards(deck, Card.CardType.WEAPON, 3)
	_assign_suits_and_ranks(deck)
	deck.shuffle()
	return deck


static func _append_cards(deck: Array[Card], card_type: Card.CardType, count: int) -> void:
	for _index: int in count:
		deck.append(create_card(card_type))


static func _assign_suits_and_ranks(deck: Array[Card]) -> void:
	var suits: Array[Card.Suit] = [
		Card.Suit.SPADE,
		Card.Suit.HEART,
		Card.Suit.CLUB,
		Card.Suit.DIAMOND,
	]
	for index: int in deck.size():
		deck[index].suit = suits[index % suits.size()]
		deck[index].rank = index % 13 + 1
