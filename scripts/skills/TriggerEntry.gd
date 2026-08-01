class_name TriggerEntry
extends RefCounted
## 触发队列中的单项。GameManager 串行消费，不同步递归覆盖 pending_skill。

var owner: BattlePlayer
var skill: Skill
var event_context: RefCounted
var timing: StringName


func _init(p_owner: BattlePlayer, p_skill: Skill, p_context: RefCounted, p_timing: StringName) -> void:
	owner = p_owner
	skill = p_skill
	event_context = p_context
	timing = p_timing
