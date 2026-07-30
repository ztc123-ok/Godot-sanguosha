class_name WeaponCard
extends Card
## 为过河拆桥、顺手牵羊和借刀杀人提供的最小武器区实现。
## 本轮不实现武器技能，只保留装备区与攻击范围 2。


func _init() -> void:
	super(
		CardType.WEAPON,
		"青釭剑",
		"装备牌·武器，攻击范围 2。本基础扩展仅实现武器槽与【借刀杀人】交互。",
		Color("66727d"),
		CardCategory.EQUIPMENT,
		Suit.NONE,
		0,
		false,
		TargetMode.SELF
	)


func can_use_in_play(game: Node, user: Node) -> bool:
	return game.can_equip_weapon(user)

