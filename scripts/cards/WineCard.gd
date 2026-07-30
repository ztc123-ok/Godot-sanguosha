class_name WineCard
extends Card
## 酒：强化本回合下一张【杀】，或在自己濒死时当【桃】使用。


func _init() -> void:
	super(
		CardType.WINE,
		"酒",
		"出牌阶段使用：本回合下一张【杀】伤害 +1；自己濒死时可自救。",
		Color("a5763f")
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.is_play_phase_for(user) and not user.wine_active


func can_use_while_dying(game: Node, user: Node) -> bool:
	return game.is_waiting_for_rescue_from(user)

