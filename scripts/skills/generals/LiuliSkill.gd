class_name LiuliSkill
extends Skill
## 流离：当你成为【杀】的目标时，你可以弃置一张手牌或装备牌，将此【杀】转移给攻击范围内另一名合法目标。
## 当前严格双人局中来源不能成为自己【杀】的目标，因此通常没有合法转移目标。

const SlashTargetContextScript = preload("res://scripts/skills/SlashTargetContext.gd")

func _init() -> void:
	super(
		&"liuli",
		"流离",
		"当你成为【杀】的目标时，你可以弃置一张手牌或装备牌，将此【杀】转移给你攻击范围内、且为该【杀】来源合法目标的另一名角色。双人局通常没有合法转移目标，因此不可发动。",
		ActivationMode.TRIGGERED
	)

func trigger_timing() -> StringName: return &"slash_targeted"

func can_trigger(context: RefCounted, game: Node, owner: Node) -> bool:
	var ctx := context as SlashTargetContextScript
	if ctx == null or ctx.current_target != owner or ctx.source == null or owner.hp <= 0:
		return false
	if owner.total_cards_in_hand_and_equipment() <= 0:
		return false
	return not game.liuli_transfer_candidates(owner, ctx).is_empty()

func should_ai_activate(_context: RefCounted, _game: Node, _owner: Node) -> bool:
	## 双人局无合法转移目标，AI 不尝试发动。
	return false

func build_resolution_request(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {"action": "liuli"}
