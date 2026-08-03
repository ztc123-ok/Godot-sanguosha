class_name SlashTargetContext
extends RefCounted
## 【杀】指定目标后的完整上下文，供铁骑、流离等“杀指定后、闪响应前”的技能使用。

var source: BattlePlayer
var current_target: BattlePlayer
var original_target: BattlePlayer
var damage_amount: int
var nature: int = 0
var physical_cards: Array[Card] = []
var effective_card_type: int = Card.CardType.SLASH
var source_card: Card = null
var ignore_armor: bool = false
var use_context: RefCounted = null
var continuation: Callable = Callable()


func _init(
	p_source: BattlePlayer = null,
	p_target: BattlePlayer = null,
	p_physical_cards: Array[Card] = [],
	p_effective_card_type: int = Card.CardType.SLASH,
	p_damage_amount: int = 1,
	p_nature: int = 0,
	p_ignore_armor: bool = false,
	p_use_context: RefCounted = null
) -> void:
	source = p_source
	current_target = p_target
	original_target = p_target
	physical_cards = p_physical_cards
	effective_card_type = p_effective_card_type
	damage_amount = p_damage_amount
	nature = p_nature
	ignore_armor = p_ignore_armor
	use_context = p_use_context
	if not p_physical_cards.is_empty():
		source_card = p_physical_cards[0]


## 流离转移目标后更新上下文：新目标必须已通过合法性验证。
func retarget(new_target: BattlePlayer) -> void:
	current_target = new_target
