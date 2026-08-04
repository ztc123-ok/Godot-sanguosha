class_name TuxiSkill
extends Skill


func _init() -> void:
	super(
		&"tuxi",
		"突袭",
		"摸牌阶段，你可以放弃本次正常摸牌，改为随机获得对手一张手牌。",
		ActivationMode.TRIGGERED
	)


func trigger_timing() -> StringName:
	return &"before_draw"


func can_trigger(event_context: RefCounted, game: Node, owner: Node) -> bool:
	var draw := event_context as DrawContext
	if draw == null or draw.player != owner or draw.final_count <= 0:
		return false
	## 多人局：任意一名对手持有手牌即可触发，不再只看默认对手。
	for target: BattlePlayer in game._potential_targets_for(owner):
		if not target.hand.is_empty():
			return true
	return false


func should_ai_activate(event_context: RefCounted, game: Node, owner: Node) -> bool:
	return can_trigger(event_context, game, owner)


func build_resolution_request(
	event_context: RefCounted,
	_game: Node,
	_owner: Node
) -> Dictionary:
	return {
		"action": &"replace_draw_with_steal",
		"draw_context": event_context,
	}
