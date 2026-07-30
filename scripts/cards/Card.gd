class_name Card
extends RefCounted
## 所有卡牌的领域基类。牌只保存不可变规则数据；结算仍由 GameManager 统一驱动。

enum CardType {
	SLASH,
	DODGE,
	PEACH,
	WINE,
	DISMANTLE,
	STEAL,
	DRAW_TWO,
	DUEL,
	BORROW_SWORD,
	AMAZING_GRACE,
	PEACH_GARDEN,
	NULLIFICATION,
	BARBARIAN_INVASION,
	ARROW_BARRAGE,
	IRON_CHAIN,
	FIRE_ATTACK,
	INDULGENCE,
	SUPPLY_SHORTAGE,
	LIGHTNING,
	CROSSBOW,
	QINGGANG_SWORD,
	ICE_SWORD,
	GREEN_DRAGON_BLADE,
	SERPENT_SPEAR,
	ROCK_CLEAVING_AXE,
	HALBERD,
	VERMILION_FAN,
	QILIN_BOW,
	EIGHT_TRIGRAMS,
	VINE_ARMOR,
	SILVER_LION,
	HORSE_PLUS,
	HORSE_MINUS,
}

enum CardCategory {
	BASIC,
	TRICK,
	DELAYED_TRICK,
	EQUIPMENT,
}

enum Suit {
	NONE,
	SPADE,
	HEART,
	CLUB,
	DIAMOND,
}

enum TargetMode {
	NONE,
	SELF,
	OTHER,
	ALL,
	ONE_OR_TWO,
}

var card_type: CardType
var display_name: String
var description: String
var accent_color: Color
var category: CardCategory
var suit: Suit
var rank: int
var is_delayed_trick: bool
var target_mode: TargetMode


func _init(
	p_type: CardType,
	p_name: String,
	p_description: String,
	p_color: Color,
	p_category: CardCategory = CardCategory.BASIC,
	p_suit: Suit = Suit.NONE,
	p_rank: int = 0,
	p_is_delayed: bool = false,
	p_target_mode: TargetMode = TargetMode.NONE
) -> void:
	card_type = p_type
	display_name = p_name
	description = p_description
	accent_color = p_color
	category = p_category
	suit = p_suit
	rank = p_rank
	is_delayed_trick = p_is_delayed
	target_mode = p_target_mode


func can_use_in_play(_game: Node, _user: Node) -> bool:
	return false


func can_use_as_response(_game: Node, _user: Node) -> bool:
	return false


func can_use_while_dying(_game: Node, _user: Node) -> bool:
	return false


func is_trick() -> bool:
	return category in [CardCategory.TRICK, CardCategory.DELAYED_TRICK]


func is_red() -> bool:
	return suit in [Suit.HEART, Suit.DIAMOND]


func suit_text() -> String:
	match suit:
		Suit.SPADE:
			return "黑桃"
		Suit.HEART:
			return "红桃"
		Suit.CLUB:
			return "梅花"
		Suit.DIAMOND:
			return "方块"
	return "无花色"


func rank_text() -> String:
	match rank:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
	return str(rank) if rank > 0 else ""


func identity_text() -> String:
	if suit == Suit.NONE:
		return display_name
	return "%s【%s%s】" % [display_name, suit_text(), rank_text()]
