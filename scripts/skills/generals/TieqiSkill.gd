class_name TieqiSkill
extends Skill
## 铁骑：你使用【杀】指定目标后，可以判定；红色则目标不能使用或打出【闪】响应此【杀】。

const SlashTargetContextScript = preload("res://scripts/skills/SlashTargetContext.gd")

func _init() -> void:
	super(&"tieqi", "铁骑", "当你使用【杀】指定一名角色为目标后，你可以进行判定，若结果为红色，该角色不能使用或打出【闪】响应此【杀】。", ActivationMode.TRIGGERED)

func trigger_timing() -> StringName: return &"slash_targeted"

func can_trigger(context: RefCounted, _game: Node, owner: Node) -> bool:
	var ctx := context as SlashTargetContextScript
	return (
		ctx != null
		and ctx.source == owner
		and ctx.effective_card_type == Card.CardType.SLASH
		and ctx.current_target != null
		and owner.hp > 0
	)

func should_ai_activate(context: RefCounted, _game: Node, owner: Node) -> bool:
	var ctx := context as SlashTargetContextScript
	if ctx == null or ctx.current_target == null or owner.hp <= 0:
		return false
	var target: BattlePlayer = ctx.current_target
	if target.find_card(Card.CardType.DODGE) >= 0:
		return true
	if target.armor != null and target.armor.card_type == Card.CardType.EIGHT_TRIGRAMS:
		return true
	for skill: Skill in target.skills:
		if skill.id == &"qingguo":
			for card: Card in target.hand:
				if card.is_black():
					return true
	return false

func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {"action": "tieqi"}
