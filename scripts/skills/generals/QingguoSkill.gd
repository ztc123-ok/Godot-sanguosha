class_name QingguoSkill
extends Skill

func _init() -> void:
	super(&"qingguo", "倾国", "你可以将一张黑色手牌当【闪】使用或打出。", ActivationMode.VIEW_AS)

func allows_view_as_equipment() -> bool: return false
func can_view_as(card: Card, effective_type: Card.CardType, _game: Node, _owner: Node) -> bool:
	return effective_type == Card.CardType.DODGE and card != null and card.is_black()
