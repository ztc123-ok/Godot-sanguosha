class_name CardMoveContext
extends RefCounted
## 一次原子牌移动的完整上下文。多张牌先整体移动完成，再触发移动后事件，
## 不允许逐张修改中途状态导致重复触发【连营】【枭姬】等。

var cards: Array[Card] = []
var owner: BattlePlayer
var source: BattlePlayer
var reason: String = ""
var source_card: Card = null
var source_skill: RefCounted = null
var to_zone: StringName = &"discard"
var hand_before: int = 0
var hand_after: int = 0
var equipment_before: Array[Card] = []
var equipment_after: Array[Card] = []
## 因装备替换等由调用方另行结算的牌，不计入本次“失去装备”事件。
var excluded_lost: Array[Card] = []


func _init(
	p_owner: BattlePlayer = null,
	p_source: BattlePlayer = null,
	p_cards: Array[Card] = [],
	p_reason: String = ""
) -> void:
	owner = p_owner
	source = p_source
	cards = p_cards
	reason = p_reason


## 一次移动是否令 owner 从有手牌变为空手。
func lost_all_hand_cards() -> bool:
	return hand_before > 0 and hand_after == 0


## 本次移动实际失去的装备牌（按实体牌去重，每张只计一次）。
func lost_equipment_cards() -> Array[Card]:
	var lost: Array[Card] = []
	for card: Card in equipment_before:
		if card != null and card not in equipment_after and card not in lost and card not in excluded_lost:
			lost.append(card)
	return lost
