extends "res://scripts/battle/BattleModifier.gd"
## 【孤军】：按当前存活敌人数动态修正摸牌阶段的基础摸牌数。

var draw_bonus_per_extra_enemy: int = 1


func _init(
	p_owner: Node,
	p_source_kind: SourceKind = SourceKind.BATTLE,
	p_draw_bonus_per_extra_enemy: int = 1
) -> void:
	super(
		&"lone_army",
		"孤军",
		"摸牌阶段额外摸取等同于额外存活敌人数的牌。",
		p_owner,
		p_source_kind
	)
	draw_bonus_per_extra_enemy = maxi(p_draw_bonus_per_extra_enemy, 0)


func bonus_for(game: Node, player: Node) -> int:
	if not applies_to(player) or game == null or not game.has_method("enemies_of"):
		return 0
	var living_enemy_count: int = game.enemies_of(player).size()
	return maxi(living_enemy_count - 1, 0) * draw_bonus_per_extra_enemy


func modify_draw_count(game: Node, player: Node, current_count: int) -> int:
	return current_count + bonus_for(game, player)


func status_text(game: Node, player: Node) -> String:
	var bonus: int = bonus_for(game, player)
	return "孤军（摸牌+%d）" % bonus if bonus > 0 else "孤军（未触发）"


func ui_summary(game: Node, player: Node) -> String:
	var enemy_count: int = game.enemies_of(player).size()
	var final_count: int = 2 + bonus_for(game, player)
	return "【孤军】每多1名敌人摸牌+1｜当前 2 + (%d - 1) = %d 张" % [enemy_count, final_count]


func ui_description(game: Node, player: Node) -> String:
	return "%s\n当前存活敌人：%d；每多一名敌人，摸牌数 +%d。" % [
		description,
		game.enemies_of(player).size(),
		draw_bonus_per_extra_enemy,
	]
