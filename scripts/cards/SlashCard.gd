class_name SlashCard
extends Card
## 杀：出牌阶段对唯一对手使用；基础版每回合限一次。


func _init() -> void:
	super(
		CardType.SLASH,
		"杀",
		"出牌阶段对对方使用。对方需打出【闪】，否则受到 1 点伤害。",
		Color("c84b42")
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.is_play_phase_for(user) and not user.slash_used_this_turn


func can_use_as_response(game: Node, user: Node) -> bool:
	return game.is_waiting_for_slash_from(user)
