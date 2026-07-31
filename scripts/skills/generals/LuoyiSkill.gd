class_name LuoyiSkill
extends Skill


func _init() -> void:
	super(
		&"luoyi",
		"裸衣",
		"摸牌阶段，你可以少摸一张牌；若如此做，本回合使用【杀】或【决斗】造成的伤害+1。",
		ActivationMode.TRIGGERED
	)


func trigger_timing() -> StringName:
	return &"before_draw"


func can_trigger(event_context: RefCounted, _game: Node, owner: Node) -> bool:
	var draw := event_context as DrawContext
	return draw != null and draw.player == owner and draw.final_count > 0


func should_ai_activate(_event_context: RefCounted, game: Node, owner: Node) -> bool:
	return game.can_owner_deal_attack_damage(owner)


func build_resolution_request(
	event_context: RefCounted,
	_game: Node,
	_owner: Node
) -> Dictionary:
	return {
		"action": &"activate_luoyi",
		"draw_context": event_context,
	}


func modify_damage_amount(
	context: RefCounted,
	current_amount: int,
	_game: Node,
	owner: Node
) -> int:
	var damage := context as DamageContext
	if (
		owner.luoyi_active
		and damage != null
		and damage.source == owner
		and damage.card_user == owner
		and not damage.is_chain_transfer
		and damage.effective_card_type in [Card.CardType.SLASH, Card.CardType.DUEL]
	):
		return current_amount + 1
	return current_amount
