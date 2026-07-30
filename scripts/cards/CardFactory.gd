class_name CardFactory
extends RefCounted
## 基础牌堆工厂。仅生成本版本实现的四种基础牌。

const CROSSBOW_SCRIPT = preload("res://scripts/cards/equipment/weapons/Crossbow.gd")
const QINGGANG_SWORD_SCRIPT = preload("res://scripts/cards/equipment/weapons/QinggangSword.gd")
const ICE_SWORD_SCRIPT = preload("res://scripts/cards/equipment/weapons/IceSword.gd")
const GREEN_DRAGON_BLADE_SCRIPT = preload("res://scripts/cards/equipment/weapons/GreenDragonBlade.gd")
const SERPENT_SPEAR_SCRIPT = preload("res://scripts/cards/equipment/weapons/SerpentSpear.gd")
const ROCK_CLEAVING_AXE_SCRIPT = preload("res://scripts/cards/equipment/weapons/RockCleavingAxe.gd")
const HALBERD_SCRIPT = preload("res://scripts/cards/equipment/weapons/Halberd.gd")
const VERMILION_FAN_SCRIPT = preload("res://scripts/cards/equipment/weapons/VermilionFan.gd")
const QILIN_BOW_SCRIPT = preload("res://scripts/cards/equipment/weapons/QilinBow.gd")
const EIGHT_TRIGRAMS_SCRIPT = preload("res://scripts/cards/equipment/armors/EightTrigrams.gd")
const VINE_ARMOR_SCRIPT = preload("res://scripts/cards/equipment/armors/VineArmor.gd")
const SILVER_LION_SCRIPT = preload("res://scripts/cards/equipment/armors/SilverLion.gd")
const DEFENSIVE_HORSE_SCRIPT = preload("res://scripts/cards/equipment/horses/DefensiveHorse.gd")
const OFFENSIVE_HORSE_SCRIPT = preload("res://scripts/cards/equipment/horses/OffensiveHorse.gd")


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
		Card.CardType.CROSSBOW:
			return CROSSBOW_SCRIPT.new()
		Card.CardType.QINGGANG_SWORD:
			return QINGGANG_SWORD_SCRIPT.new()
		Card.CardType.ICE_SWORD:
			return ICE_SWORD_SCRIPT.new()
		Card.CardType.GREEN_DRAGON_BLADE:
			return GREEN_DRAGON_BLADE_SCRIPT.new()
		Card.CardType.SERPENT_SPEAR:
			return SERPENT_SPEAR_SCRIPT.new()
		Card.CardType.ROCK_CLEAVING_AXE:
			return ROCK_CLEAVING_AXE_SCRIPT.new()
		Card.CardType.HALBERD:
			return HALBERD_SCRIPT.new()
		Card.CardType.VERMILION_FAN:
			return VERMILION_FAN_SCRIPT.new()
		Card.CardType.QILIN_BOW:
			return QILIN_BOW_SCRIPT.new()
		Card.CardType.EIGHT_TRIGRAMS:
			return EIGHT_TRIGRAMS_SCRIPT.new()
		Card.CardType.VINE_ARMOR:
			return VINE_ARMOR_SCRIPT.new()
		Card.CardType.SILVER_LION:
			return SILVER_LION_SCRIPT.new()
		Card.CardType.HORSE_PLUS:
			return DEFENSIVE_HORSE_SCRIPT.new()
		Card.CardType.HORSE_MINUS:
			return OFFENSIVE_HORSE_SCRIPT.new()
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
	_append_cards(deck, Card.CardType.CROSSBOW, 2)
	_append_cards(deck, Card.CardType.QINGGANG_SWORD, 1)
	_append_cards(deck, Card.CardType.ICE_SWORD, 1)
	_append_cards(deck, Card.CardType.GREEN_DRAGON_BLADE, 1)
	_append_cards(deck, Card.CardType.SERPENT_SPEAR, 1)
	_append_cards(deck, Card.CardType.ROCK_CLEAVING_AXE, 1)
	_append_cards(deck, Card.CardType.HALBERD, 1)
	_append_cards(deck, Card.CardType.VERMILION_FAN, 1)
	_append_cards(deck, Card.CardType.QILIN_BOW, 1)
	_append_cards(deck, Card.CardType.EIGHT_TRIGRAMS, 2)
	_append_cards(deck, Card.CardType.VINE_ARMOR, 2)
	_append_cards(deck, Card.CardType.SILVER_LION, 1)
	_append_cards(deck, Card.CardType.HORSE_PLUS, 3)
	_append_cards(deck, Card.CardType.HORSE_MINUS, 3)
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
