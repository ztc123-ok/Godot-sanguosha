extends Node2D
## 组合根节点。只负责在 Godot 生命周期中绑定领域管理器和 UI 管理器。

@onready var game_manager: GameManager = $GameManager
@onready var ui_manager: UIManager = $UIManager


func _ready() -> void:
	ui_manager.bind_game_manager(game_manager)

