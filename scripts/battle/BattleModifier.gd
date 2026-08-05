extends RefCounted
## 战斗修正的统一扩展点。
## 角色 Buff、场景 Buff 与关卡补偿都通过同一接口参与规则查询，
## GameManager 仍负责决定调用时机与最终结算顺序。

enum SourceKind {
	CHARACTER,
	SCENE,
	BATTLE,
}

var id: StringName
var display_name: String
var description: String
var owner: Node
var source_kind: SourceKind


func _init(
	p_id: StringName,
	p_display_name: String,
	p_description: String,
	p_owner: Node,
	p_source_kind: SourceKind = SourceKind.BATTLE
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	owner = p_owner
	source_kind = p_source_kind


func applies_to(player: Node) -> bool:
	return player != null and player == owner


func modify_draw_count(_game: Node, _player: Node, current_count: int) -> int:
	return current_count


func status_text(_game: Node, _player: Node) -> String:
	return display_name


func ui_summary(game: Node, player: Node) -> String:
	return "【%s】%s" % [display_name, status_text(game, player)]


func ui_description(_game: Node, _player: Node) -> String:
	return description


func source_label() -> String:
	match source_kind:
		SourceKind.CHARACTER:
			return "角色 Buff"
		SourceKind.SCENE:
			return "场景 Buff"
	return "关卡 Buff"


func ui_data(game: Node, player: Node) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"summary": ui_summary(game, player),
		"description": ui_description(game, player),
		"source_label": source_label(),
		"source_kind": int(source_kind),
	}
