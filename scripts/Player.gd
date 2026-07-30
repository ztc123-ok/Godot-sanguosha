class_name BattlePlayer
extends Node
## 玩家领域对象：只负责体力、手牌和回合内标记，不直接控制流程。

signal hp_changed(current_hp: int, maximum_hp: int)
signal hand_changed

@export var player_name: String = "Player"
@export var role_name: String = "身份"
@export var is_ai: bool = false
@export_range(1, 20, 1) var max_hp: int = 4

var hp: int = 4
var hand: Array[Card] = []
var slash_used_this_turn: bool = false
var wine_active: bool = false


func reset_for_match() -> void:
	hp = max_hp
	hand.clear()
	reset_turn_flags()
	hp_changed.emit(hp, max_hp)
	hand_changed.emit()


func reset_turn_flags() -> void:
	slash_used_this_turn = false
	wine_active = false


func add_card(card: Card) -> void:
	hand.append(card)
	hand_changed.emit()


func remove_card_at(index: int) -> Card:
	if index < 0 or index >= hand.size():
		return null
	var card: Card = hand.pop_at(index)
	hand_changed.emit()
	return card


func find_card(card_type: Card.CardType) -> int:
	for index: int in hand.size():
		if hand[index].card_type == card_type:
			return index
	return -1


func count_card(card_type: Card.CardType) -> int:
	var total: int = 0
	for card: Card in hand:
		if card.card_type == card_type:
			total += 1
	return total


func take_damage(amount: int) -> void:
	hp -= maxi(amount, 0)
	hp_changed.emit(hp, max_hp)


func recover(amount: int) -> void:
	hp = mini(hp + maxi(amount, 0), max_hp)
	hp_changed.emit(hp, max_hp)


func hand_limit() -> int:
	return maxi(hp, 0)


func is_dying() -> bool:
	return hp <= 0

