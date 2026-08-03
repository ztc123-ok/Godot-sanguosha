class_name BattlePlayer
extends Node
## 玩家领域对象：只负责武将资料、体力、手牌和回合内标记，不直接控制流程。

const EquipmentScript = preload("res://scripts/cards/equipment/Equipment.gd")

signal hp_changed(current_hp: int, maximum_hp: int)
signal hand_changed
signal general_changed

@export var player_name: String = "Player"
@export var role_name: String = "身份"
@export var is_ai: bool = false
@export_range(1, 20, 1) var max_hp: int = 4

## 身份（role_name）与武将资料严格分离。
var general_id: StringName = &""
var general_name: String = "未选将"
var kingdom: String = ""
var gender: int = GeneralDefinition.Gender.MALE
var skills: Array[Skill] = []
var turn_skill_usage: Dictionary = {}
var match_skill_usage: Dictionary = {}

var hp: int = 4
var hand: Array[Card] = []
var slash_used_this_turn: bool = false
var wine_active: bool = false
var chained: bool = false
var luoyi_active: bool = false
var play_phase_effective_card_types: Array[int] = []
var skip_discard_this_turn: bool = false
var rende_given_this_phase: int = 0
var rende_recovery_consumed: bool = false
var luoshen_cards_gained: int = 0
var kurou_ai_uses_this_turn: int = 0

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
	match_skill_usage.clear()
	reset_turn_flags()
	hp_changed.emit(hp, max_hp)
	hand_changed.emit()


func reset_turn_flags() -> void:
	slash_used_this_turn = false
	wine_active = false
	luoyi_active = false
	play_phase_effective_card_types.clear()
	skip_discard_this_turn = false
	rende_given_this_phase = 0
	rende_recovery_consumed = false
	luoshen_cards_gained = 0
	kurou_ai_uses_this_turn = 0
	turn_skill_usage.clear()


func assign_general(definition: GeneralDefinition) -> void:
	if definition == null:
		return
	general_id = definition.id
	general_name = definition.display_name
	kingdom = definition.kingdom
	gender = definition.gender
	max_hp = definition.max_hp
	hp = max_hp
	skills.clear()
	for skill_id: String in definition.skill_ids:
		var skill: Skill = SkillFactory.create_skill(StringName(skill_id))
		if skill != null:
			skills.append(skill)
	turn_skill_usage.clear()
	match_skill_usage.clear()
	luoyi_active = false
	general_changed.emit()
	hp_changed.emit(hp, max_hp)


func clear_general() -> void:
	general_id = &""
	general_name = "未选将"
	kingdom = ""
	gender = GeneralDefinition.Gender.MALE
	skills.clear()
	turn_skill_usage.clear()
	match_skill_usage.clear()
	general_changed.emit()


func has_skill(skill_id: StringName) -> bool:
	return get_skill(skill_id) != null


func get_skill(skill_id: StringName) -> Skill:
	for skill: Skill in skills:
		if skill.id == skill_id:
			return skill
	return null


func skill_use_count(skill: Skill) -> int:
	if skill == null:
		return 0
	if skill.usage_scope == Skill.UsageScope.PER_TURN:
		return int(turn_skill_usage.get(skill.id, 0))
	return int(match_skill_usage.get(skill.id, 0))


func can_pay_skill_usage(skill: Skill) -> bool:
	if skill == null:
		return false
	if skill.usage_scope == Skill.UsageScope.UNLIMITED:
		return true
	return skill_use_count(skill) < skill.max_uses


func record_skill_use(skill: Skill) -> void:
	if skill == null:
		return
	if skill.usage_scope == Skill.UsageScope.PER_TURN:
		turn_skill_usage[skill.id] = skill_use_count(skill) + 1
	else:
		match_skill_usage[skill.id] = skill_use_count(skill) + 1


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


func lose_hp(amount: int) -> void:
	hp -= maxi(amount, 0)
	hp_changed.emit(hp, max_hp)


func record_effective_card(card_type: Card.CardType) -> void:
	play_phase_effective_card_types.append(int(card_type))


func used_effective_card(card_type: Card.CardType) -> bool:
	return int(card_type) in play_phase_effective_card_types


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
	var slot_type: Card.CardType = card.rule_card_type()
	if has_delayed_trick(slot_type):
		return false
	match slot_type:
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
