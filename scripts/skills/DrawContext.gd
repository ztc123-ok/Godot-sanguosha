class_name DrawContext
extends RefCounted
## 摸牌阶段上下文。替代摸牌与数量修正先记录，再由 GameManager 执行。

var player: Node
var original_count: int
var final_count: int
var replacement_skill: Skill
var draw_replaced: bool = false


func _init(p_player: Node = null, p_original_count: int = 2) -> void:
	player = p_player
	original_count = maxi(p_original_count, 0)
	final_count = original_count
