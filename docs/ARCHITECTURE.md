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
            ├── GeneralSelectionPanel（选将阶段动态覆盖层）
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

## 武将领域模型

- `GeneralDefinition` 是不可变定义，保存 `id/display_name/kingdom/max_hp/skill_ids`。
- `GeneralFactory` 是九名首批武将的定义入口，并提供默认的曹操、吕布测试配置。
- `BattlePlayer.role_name` 只保存主公/反贼；`general_id/general_name/kingdom` 独立保存武将资料。
- `BattlePlayer.skills` 保存由 `SkillFactory` 创建的技能对象。
- `turn_skill_usage` 在当前角色回合开始时重置；`match_skill_usage` 在新对局时重置。
- 【裸衣】使用独立的 `luoyi_active` 回合标记，不复用酒、连环或其他含义不同的状态。

## 技能分类与钩子

`Skill.activation_mode` 决定规则入口：

- `ACTIVE`：主动请求，例如【制衡】。
- `TRIGGERED`：进入触发队列并生成确认 continuation，例如【奸雄】【突袭】【裸衣】。
- `VIEW_AS`：选择实体牌并形成 `SkillUseContext.effective_card_type`，例如【武圣】【龙胆】【奇袭】。
- `MODIFIER`：自动修正次数或响应需求，例如【咆哮】【无双】。

`SkillTag.LOCKED` 与发动方式互相独立。锁定技不进入确认界面；`UsageScope` 和 `max_uses` 由 `BattlePlayer` 与 `GameManager.can_use_skill` 共同检查。技能脚本不直接修改手牌、体力、装备或 `FlowState`，只返回结构化请求或参数修正。

基础钩子覆盖武将/回合重置、阶段前后、摸牌替代、主动技能代价、视为牌、牌使用与响应、伤害修正、伤后触发、攻击范围、距离、出杀次数和手牌上限。

## 卡牌生命周期与上下文

- `processing_cards` 是实体牌处理区。
- 主动牌、响应牌和虚拟牌实体代价从手牌/装备区支付后进入处理区。
- 整条效果、响应、伤害与濒死链结束后，仍在处理区的实体牌统一进入弃牌堆。
- 【奸雄】从处理区取得来源实体牌后，该牌不再参与自动弃置。
- 装备作为技能代价时仍调用统一失去装备入口，因此【白银狮子】离场回复正常触发。
- 虚拟牌不创建可进入牌堆的实体，也不改写真实 `Card.card_type`。

三个上下文：

- `SkillUseContext`：操作者、实体牌代价、有效牌类型、来源技能、目标和虚拟牌标记。
- `DamageContext`：伤害来源、目标、数值、属性、来源实体牌、有效牌类型、原因与连环传播标记。
- `DrawContext`：原始摸牌数、最终摸牌数和替代摸牌技能。

普通、火焰、雷电、连环传播、杀、决斗与锦囊伤害都进入 `DamageContext` 队列。连环传播上下文不重复携带来源实体牌，避免同一张牌被【奸雄】重复获得。

## 流程状态

主动牌主链：

`PLAY_ACTIVE` → `SELECTING_TARGET` → `NULLIFICATION_RESPONSE` → 具体牌效果 → `PLAY_ACTIVE`

选将与技能状态：

- `GENERAL_SELECTION`
- `SKILL_CONFIRM`
- `SKILL_SELECT_CARDS`
- `SKILL_SELECT_TARGET`
- `SKILL_RESOLVING`
- `MULTI_RESPONSE`

技能上下文明确保存 `skill_owner/skill_actor/pending_skill/pending_skill_cards/pending_skill_targets`，并为确认、取消和完成分支保存 continuation。授权依据是当前 `FlowState` 与真实 `skill_actor`，不是“当前回合是否属于 AI”。

响应子状态包括：

- `RESPONDING_SLASH`
- `AOE_RESPONSE`
- `DUEL_RESPONSE`
- `FIRE_REVEAL` / `FIRE_DISCARD`
- `BORROW_RESPONSE`
- `CHOOSING_OPTION` / `CHOOSING_REVEALED`
- `DYING_RESCUE`

判定阶段从玩家的延时锦囊槽生成判定队列，每个效果先进入无懈链，再翻开具有花色与点数的判定牌。属性伤害由统一伤害队列处理，目标先结算，之后才依次传播给其他横置角色。

结束出牌后进入 `DISCARDING`，达到手牌上限后进入 `END` 并切换当前玩家。胜负确定后进入 `GAME_OVER`，所有旧 AI 计时动作失效。

## 选将、重开与 AI

- 初次进入场景时停留在 `GENERAL_SELECTION`，不创建牌堆也不发起始牌。
- 玩家选择后，AI 从剩余武将中随机选择；默认配置固定为曹操对吕布。
- `setup_generals` 与 `start_match` 提供确定性测试入口。
- “重新开始”沿用当前武将；“重新选将”清空武将并增加 action generation。
- AI 和玩家共用 `can_use_skill/request_*` 语义及同一结算函数。延迟 AI 技能确认同时检查 generation、状态和 `skill_actor`。
