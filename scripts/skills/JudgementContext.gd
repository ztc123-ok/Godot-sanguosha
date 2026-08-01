class_name JudgementContext
extends RefCounted
## 一次判定从翻牌、改判、最终生效到唯一去向的完整上下文。

var reason: StringName
var judged_player: BattlePlayer
var original_card: Card
var effective_card: Card
var replacer: BattlePlayer
var replaced_cards: Array[Card] = []
var offered_guicai_owners: Array[StringName] = []
var final_owner: BattlePlayer
var final_destination: StringName = &"discard"
var result_data: Dictionary = {}


func _init(p_reason: StringName, p_player: BattlePlayer, p_card: Card) -> void:
	reason = p_reason
	judged_player = p_player
	original_card = p_card
	effective_card = p_card


func replace_with(owner: BattlePlayer, card: Card) -> Card:
	var old: Card = effective_card
	replacer = owner
	replaced_cards.append(old)
	effective_card = card
	return old


func claim(owner: BattlePlayer, destination: StringName = &"hand") -> void:
	final_owner = owner
	final_destination = destination


func is_claimed() -> bool:
	return final_owner != null
