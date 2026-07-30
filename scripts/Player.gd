class_name BattlePlayer
extends Node
## 玩家领域对象：只负责体力、手牌和回合内标记，不直接控制流程。

const EquipmentScript = preload("res://scripts/cards/equipment/Equipment.gd")

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
var chained: bool = false

## 四个互相独立的装备区；同一装备区始终至多一张牌。
var weapon: Card = null
var armor: Card = null
var horse_plus: Card = null
var horse_minus: Card = null

## 三种延时锦囊各自占用一个判定区槽位。
var indulgence_card: Card
var supply_shortage_card: Card
var lightning_card: Card


func reset_for_match() -> void:
	hp = max_hp
	hand.clear()
	chained = false
	weapon = null
	armor = null
	horse_plus = null
	horse_minus = null
	indulgence_card = null
	supply_shortage_card = null
	lightning_card = null
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


func has_any_card_in_play_area() -> bool:
	return (
		not hand.is_empty()
		or weapon != null
		or armor != null
		or horse_plus != null
		or horse_minus != null
		or indulgence_card != null
		or supply_shortage_card != null
		or lightning_card != null
	)


func has_delayed_trick(card_type: Card.CardType) -> bool:
	match card_type:
		Card.CardType.INDULGENCE:
			return indulgence_card != null
		Card.CardType.SUPPLY_SHORTAGE:
			return supply_shortage_card != null
		Card.CardType.LIGHTNING:
			return lightning_card != null
	return false


func add_delayed_trick(card: Card) -> bool:
	if has_delayed_trick(card.card_type):
		return false
	match card.card_type:
		Card.CardType.INDULGENCE:
			indulgence_card = card
		Card.CardType.SUPPLY_SHORTAGE:
			supply_shortage_card = card
		Card.CardType.LIGHTNING:
			lightning_card = card
		_:
			return false
	return true


func remove_delayed_trick(card_type: Card.CardType) -> Card:
	var removed: Card
	match card_type:
		Card.CardType.INDULGENCE:
			removed = indulgence_card
			indulgence_card = null
		Card.CardType.SUPPLY_SHORTAGE:
			removed = supply_shortage_card
			supply_shortage_card = null
		Card.CardType.LIGHTNING:
			removed = lightning_card
			lightning_card = null
	return removed


func delayed_tricks_in_judgement_order() -> Array[Card]:
	var cards: Array[Card] = []
	## 后置入判定区的牌先判定；固定槽位用闪电→兵粮→乐的逆序表示。
	if lightning_card != null:
		cards.append(lightning_card)
	if supply_shortage_card != null:
		cards.append(supply_shortage_card)
	if indulgence_card != null:
		cards.append(indulgence_card)
	return cards


func equipment_in_slot(slot: int) -> Card:
	match slot:
		EquipmentScript.Slot.WEAPON:
			return weapon
		EquipmentScript.Slot.ARMOR:
			return armor
		EquipmentScript.Slot.HORSE_PLUS:
			return horse_plus
		EquipmentScript.Slot.HORSE_MINUS:
			return horse_minus
	return null


func equip(card: Card) -> Card:
	var replaced: Card = equipment_in_slot(card.equipment_slot)
	match card.equipment_slot:
		EquipmentScript.Slot.WEAPON:
			weapon = card
		EquipmentScript.Slot.ARMOR:
			armor = card
		EquipmentScript.Slot.HORSE_PLUS:
			horse_plus = card
		EquipmentScript.Slot.HORSE_MINUS:
			horse_minus = card
	return replaced


func remove_equipment(slot: int) -> Card:
	var removed: Card = equipment_in_slot(slot)
	match slot:
		EquipmentScript.Slot.WEAPON:
			weapon = null
		EquipmentScript.Slot.ARMOR:
			armor = null
		EquipmentScript.Slot.HORSE_PLUS:
			horse_plus = null
		EquipmentScript.Slot.HORSE_MINUS:
			horse_minus = null
	return removed


func all_equipment() -> Array[Card]:
	var result: Array[Card] = []
	for card: Card in [weapon, armor, horse_plus, horse_minus]:
		if card != null:
			result.append(card)
	return result


func equipment_count() -> int:
	return all_equipment().size()


func total_cards_in_hand_and_equipment() -> int:
	return hand.size() + equipment_count()
