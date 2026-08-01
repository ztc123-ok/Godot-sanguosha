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

## 第二批通用规则扩展

### JudgementContext 与统一判定管线

`JudgementContext` 保存判定原因、判定角色、原始牌、当前唯一生效牌、改判者、被替换牌和最终去向。延时锦囊、八卦阵、刚烈和洛神均调用同一个 GameManager 判定入口：翻出实体牌 → 串行提供【鬼才】改判 → 只按 `effective_card` 计算结果 → 进入 `after_judgement` 触发队列（如【天妒】）→ 把最终实体牌移至唯一获得者或弃牌堆。

【鬼才】支付的手牌直接成为新判定牌，被替换牌立即弃置；改判不会重新生成同一名司马懿的机会。花色、点数、颜色、天妒和洛神均不会读取旧牌或复制实体牌。

### TriggerEntry 串行触发队列

GameManager 在同一时机先构造 `TriggerEntry` 队列，再逐项重验拥有者存活、技能归属、次数和 `can_trigger`。当前项完成后才恢复下一项或最终 continuation。嵌套伤害造成的新触发使用队列栈保存外层进度，避免刚烈反伤覆盖原伤害链的 `pending_skill`。

反馈、刚烈按一次 `DamageContext` 各入队一次；遗计通过 `trigger_repeat_count()` 按实际伤害点数生成 N 项。角色先完成濒死/死亡检查，死亡角色不会继续收到可选技能窗口。

### 私有临时牌区

`private_cards`、`private_card_owner` 和分配/排序数据只由 GameManager 修改。人类操作者为拥有者时 UI 才显示牌面；AI 操作只公开技能开始、数量和最终移动结果，不公开临时牌身份。

- 【遗计】先把两张牌放入私有分配区，全部归属确认后一次移动；取消调整采用“全部归技能拥有者”的确定性安全分支。
- 【观星】支持 0/1/2 张置顶，置顶和置底分别保留指定顺序；确认后才重新写回牌堆。

### 失去体力与有效牌记账

`GameManager.lose_hp()` 与伤害完全分离：不创建 `DamageContext`，不触发伤后技能、藤甲或铁索，但仍进入统一濒死/死亡流程。【苦肉】把“成功脱离濒死后摸两张”保存在 continuation 中，死亡时不执行。

`BattlePlayer.play_phase_effective_card_types` 记录当前角色出牌阶段内真正提交的有效牌类型。实体牌、视为牌、丈八蛇矛和决斗响应共用 `_record_effective_card_action()`；非法请求、取消和未提交动作不记账。【克己】只读取该记录。

### 状态、授权与双人裁定

新增 `JUDGEMENT_REPLACE`、`DECK_REORDER`、`SKILL_ASSIGN_CARDS`、`CHOOSING_SUIT`。每个状态显式保存真实 `skill_actor`、`choice_owner` 或 `private_card_owner`、合法数据和 continuation。重新开始/重新选将会清空判定、触发队列、私有牌与临时状态，并增加 `_action_generation` 使旧 AI 回调失效。

双人版中【仁德】只能交给唯一对手且不实现【激将】；【反馈】暗手牌随机获得、明置区域可选具体牌；【遗计】可分配给任意一方且 AI 默认保留；【观星】固定观看两张；【空城】只在【杀】/【决斗】建立目标时检查；【反间】唯一对手先选花色再随机获得暗牌。本批没有增加限定技、觉醒技、主公技、使命技或转换技类型。

## 第二批测试

`tests/SecondBatchSkillSmokeTest.tscn` 确定性覆盖第二批 9 名武将、18 将工厂、统一判定、串行触发、私有牌、失去体力、AI、无双/八卦/丈八组合与 generation 清理。成功标志为：

`SECOND_BATCH_SKILL_SMOKE_TEST: PASS (9 additional standard generals; 18 total)`
