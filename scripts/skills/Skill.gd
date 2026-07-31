class_name Skill
extends RefCounted
## 技能领域基类。技能只声明规则、修正参数或产生结构化请求，不直接改领域状态。

enum ActivationMode {
	ACTIVE,
	TRIGGERED,
	VIEW_AS,
	MODIFIER,
}

enum SkillTag {
	LOCKED,
}

enum UsageScope {
	UNLIMITED,
	PER_TURN,
}

var id: StringName
var display_name: String
var description: String
var activation_mode: ActivationMode
var skill_tags: Array[int] = []
var usage_scope: UsageScope = UsageScope.UNLIMITED
var max_uses: int = 0


func _init(
	p_id: StringName,
	p_display_name: String,
	p_description: String,
	p_activation_mode: ActivationMode,
	p_skill_tags: Array[int] = [],
	p_usage_scope: UsageScope = UsageScope.UNLIMITED,
	p_max_uses: int = 0
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	activation_mode = p_activation_mode
	skill_tags = p_skill_tags
	usage_scope = p_usage_scope
	max_uses = p_max_uses


func has_tag(tag: SkillTag) -> bool:
	return int(tag) in skill_tags


func activation_text() -> String:
	match activation_mode:
		ActivationMode.ACTIVE:
			return "主动技"
		ActivationMode.TRIGGERED:
			return "触发技"
		ActivationMode.VIEW_AS:
			return "视为技"
		ActivationMode.MODIFIER:
			return "规则修正"
	return "技能"


func usage_text() -> String:
	if has_tag(SkillTag.LOCKED):
		return "锁定技"
	if usage_scope == UsageScope.PER_TURN:
		return "每回合限%d次" % max_uses
	return "不限次数"


func trigger_timing() -> StringName:
	return &""


func on_general_reset(_game: Node, _owner: Node) -> void:
	pass


func on_turn_start(_game: Node, _owner: Node) -> void:
	pass


func before_phase(_phase: int, _game: Node, _owner: Node) -> Dictionary:
	return {}


func after_phase(_phase: int, _game: Node, _owner: Node) -> Dictionary:
	return {}


func before_card_use(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {}


func after_targets_selected(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {}


func on_response_needed(_context: RefCounted, _game: Node, _owner: Node) -> Dictionary:
	return {}


func after_card_resolved(_context: RefCounted, _game: Node, _owner: Node) -> void:
	pass


func on_turn_reset(_game: Node, _owner: Node) -> void:
	pass


func can_trigger(_event_context: RefCounted, _game: Node, _owner: Node) -> bool:
	return false


func should_ai_activate(_event_context: RefCounted, _game: Node, _owner: Node) -> bool:
	return false


func build_resolution_request(
	_event_context: RefCounted,
	_game: Node,
	_owner: Node
) -> Dictionary:
	return {}


func can_activate(_game: Node, _owner: Node) -> bool:
	return false


func validate_cost(_cards: Array[Card], _game: Node, _owner: Node) -> bool:
	return false


func can_view_as(
	_card: Card,
	_effective_type: Card.CardType,
	_game: Node,
	_owner: Node
) -> bool:
	return false


func modify_slash_limit(current_limit: int, _game: Node, _owner: Node) -> int:
	return current_limit


func modify_response_required_count(
	_context: RefCounted,
	_responder: Node,
	current_count: int,
	_game: Node,
	_owner: Node
) -> int:
	return current_count


func modify_damage_amount(
	_context: RefCounted,
	current_amount: int,
	_game: Node,
	_owner: Node
) -> int:
	return current_amount


func modify_attack_range(current_range: int, _game: Node, _owner: Node) -> int:
	return current_range


func modify_distance(
	_current_distance: int,
	_source: Node,
	_target: Node,
	_game: Node,
	_owner: Node
) -> int:
	return _current_distance


func modify_hand_limit(current_limit: int, _game: Node, _owner: Node) -> int:
	return current_limit
