# 节点与生命周期

```text
Main (Node2D, Main.gd)
├── Background (ColorRect)
├── GameManager (Node, GameManager.gd)
│   └── Players (Node)
│       ├── Player1 (Node, Player.gd)
│       └── Player2 (Node, Player.gd, is_ai=true)
└── UIManager (CanvasLayer, UIManager.gd)
    └── Root (Control)
        └── Margin/Layout
            ├── Header
            ├── PromptPanel
            ├── OpponentZone (PlayerDropZone.gd)
            ├── PlayerZone (PlayerDropZone.gd)
            ├── HandPanel/PlayerHand
            ├── ActionBar
            └── LogPanel
```

## 管理器约束

- `Main._ready()` 只绑定两个管理器。
- `GameManager._ready()` 延迟启动对局，避免依赖子节点尚未进入树。
- `GameManager` 独占牌堆、阶段、响应、伤害、濒死、胜负等领域状态。
- `UIManager` 订阅 `state_changed` / `log_added`，不直接修改领域状态。
- 延迟 AI 行为带 generation 标记；重新开局后旧计时回调自动失效。

## 流程状态

`PLAY_ACTIVE` → `SELECTING_TARGET` → `RESPONDING_SLASH` → `DYING_RESCUE`（可选）→ `PLAY_ACTIVE`

结束出牌后进入 `DISCARDING`，达到手牌上限后进入 `END` 并切换当前玩家。胜负确定后进入 `GAME_OVER`，所有旧 AI 计时动作失效。

