# 序章第二战：1v2 多 AI 战斗开发提示词

## 任务目标

在现有 Godot 4“双人三国杀”项目基础上，将序章第二战改造成：

- 1 名玩家
- 2 名 AI 反贼

并对核心战斗结构做最小必要调整，使敌人数量之后可以继续扩展，而不是把逻辑写死为两个 AI。

不需要复杂 UI 美术，优先跑通多人敌方战斗、回合顺序、目标选择和胜负结算。

## 现有前提

项目目前已经具备：

- 序章地图 `MapScene.tscn`
- 序章第一战、第二战和村落的线性解锁流程
- 第一战胜利后解锁第二战
- 第二战胜利后解锁“进入村落”
- 现有 1v1 战斗场景 `Main.tscn`
- 玩家与单个 AI 的基本回合状态机
- 手牌、扣血、濒死、死亡和基础 AI
- `GameManager.match_finished(winner, loser)` 战斗结算信号
- `PrologueState.active_battle` 当前序章关卡状态

当前代码中可能存在以下 1v1 假设，需要检查并进行必要重构：

- 固定的 `player1`、`player2`
- `other_player(player)`
- `current_player_index = 1 - current_player_index`
- UI 只有一个敌方角色区域
- AI 默认只攻击唯一对手
- 胜利条件默认任意一方死亡即结束

## 核心开发需求

### 1. 不同关卡使用不同敌人数量

根据 `PrologueState.active_battle` 创建战斗阵容。

#### 序章第一战

- 保持现有 1v1：
  - 玩家 1 名
  - AI 反贼 1 名

#### 序章第二战

- 改为 1v2：
  - 玩家 1 名
  - AI 反贼 2 名

建议不要分别复制两套战斗场景。

优先继续复用 `Main.tscn` 和 `GameManager`，通过关卡配置或敌人列表决定本场敌人数量。

结构应允许以后配置为：

```gdscript
enemy_count = 3
```

或通过敌人配置数组继续添加 AI，而不需要再次重写回合状态机。

### 2. 玩家与敌人数据结构

将战斗参与者组织为可扩展的集合，例如：

```gdscript
var players: Array[BattlePlayer] = []
var enemies: Array[BattlePlayer] = []
```

要求：

- 玩家角色可以被明确识别。
- AI 敌人可以通过数组遍历。
- 每个 AI 拥有独立的体力、手牌、武将、装备、回合状态和死亡状态。
- 不要用 `enemy1`、`enemy2` 到处写分支。
- 可以保留 `player1` 等兼容字段，但核心流程不能继续依赖“场上永远只有两个人”。

### 3. 回合顺序

序章第二战使用线性轮转：

```text
玩家 → AI 反贼 1 → AI 反贼 2 → 玩家
```

要求：

- 当前角色回合结束后，寻找下一名存活角色。
- 已死亡角色必须跳过。
- 如果 AI 反贼 1 已死亡，顺序应变为：

```text
玩家 → AI 反贼 2 → 玩家
```

- 如果角色列表中只剩玩家，立即判定胜利。
- 不允许继续使用：

```gdscript
current_player_index = 1 - current_player_index
```

建议增加类似方法：

```gdscript
func living_players() -> Array[BattlePlayer]
func living_enemies() -> Array[BattlePlayer]
func next_living_player_index() -> int
```

### 4. 玩家选择攻击目标

第二战中，玩家使用需要指定敌方目标的牌时，必须能够选择两个 AI 中的任意存活目标。

最低要求：

- UI 显示两个独立的敌方角色区域。
- 每个区域至少显示敌人名称、当前体力、手牌数量和是否死亡。
- 玩家点击或拖拽单体牌时，可以明确选择目标。
- 已死亡敌人不能再被选中，UI 可以隐藏、禁用或显示“已阵亡”。
- 目标选择逻辑应基于 `BattlePlayer` 或角色索引，不要把目标写死为 `player2`。

可以采用动态生成敌人 UI 的方式，例如：

```text
EnemyContainer
├── EnemyZone
├── EnemyZone
└── 后续可继续增加
```

UI尽可能简洁美观。

### 5. AI 行为

两个 AI 各自执行独立回合。

MVP 阶段 AI 行为可以保持简单：

- AI 的主要攻击目标始终为玩家。
- AI 不会攻击其他 AI。
- AI 可以继续使用现有基础出牌逻辑。
- 如果现有 AI 逻辑依赖 `other_player(ai)`，需要替换为明确的目标选择方法，例如：

```gdscript
func choose_ai_target(ai: BattlePlayer) -> BattlePlayer:
	return human_player if human_player != null and not human_player.is_dead() else null
```

AI 行动前必须检查：

- AI 自己是否存活。
- 玩家是否存活。
- 当前战斗是否已经结束。

### 6. 卡牌目标规则的 MVP 范围

优先保证以下核心流程在 1v2 中正确：

- 【杀】选择一个存活敌人。
- 单体伤害只作用于选中的目标。
- AI 的【杀】默认选择玩家。
- 【桃】等自身使用牌作用于使用者。
- 单体锦囊可以选择一个存活敌人。
- 死亡角色不能继续出牌或响应。

对于群体牌，建议按以下规则处理：

- “所有其他角色”类牌作用于除使用者外的全部存活角色。
- 对每个目标依次进行响应和结算。
- 一个目标的死亡不能阻止后续目标继续结算。
- 如果完整兼容现有复杂锦囊会明显扩大工作量，至少保证不会因为第三名角色出现而报错、死循环或访问空对象，并在交付说明中列出暂未完整支持的牌。

不要为了 1v2 复制整套卡牌逻辑。

### 7. 死亡与胜负判定

#### 玩家失败

当玩家死亡时：

- 立即判定本场失败。
- 停止所有剩余 AI 行动、延迟回调和回合切换。
- 保持现有序章失败逻辑：自动重新开始当前战斗。
- 第二战重新开始后仍然是 1v2。
- 不得解锁村落。

#### 玩家胜利

敌人死亡时，不要立即结束战斗。

只有满足以下条件时才判定胜利：

```gdscript
living_enemies().is_empty()
```

也就是两个 AI 反贼全部死亡后：

- 判定序章第二战胜利。
- 更新 `PrologueState`。
- 返回 `MapScene.tscn`。
- 解锁“进入村落”。

如果只击败一个 AI：

- 战斗继续。
- 剩余 AI 正常行动。
- 不返回地图。
- 不更新序章完成进度。

战斗结束信号可以重构为更适合多人战斗的形式，例如：

```gdscript
signal battle_finished(player_won: bool)
```

也可以保留现有信号并增加统一结算方法，但必须避免用“某个敌人死亡”直接代表玩家胜利。

所有胜负出口应尽量汇总到一个方法，例如：

```gdscript
func check_battle_result() -> void
```

### 8. 战斗场景初始化

进入战斗场景时，根据当前序章关卡生成阵容。

建议提供类似配置：

```gdscript
func enemy_count_for_current_battle() -> int:
	match PrologueState.active_battle:
		1:
			return 1
		2:
			return 2
		_:
			return 1
```

更推荐使用可扩展配置：

```gdscript
const BATTLE_CONFIGS := {
	1: {
		"enemy_count": 1,
	},
	2: {
		"enemy_count": 2,
	},
}
```

如果需要给两个 AI 分配武将：

- 可以从已有武将池中随机选择。
- AI 武将不能与玩家重复。
- 两个 AI 最好也不要选择相同武将。
- 不要因为可选武将不足导致数组越界。

### 9. UI 要求

不需要复杂美术，只需保证操作清晰。

建议布局：

```text
敌人区域
┌─────────────────┐  ┌─────────────────┐
│ AI 反贼 1       │  │ AI 反贼 2       │
│ 体力 / 手牌     │  │ 体力 / 手牌     │
└─────────────────┘  └─────────────────┘

战斗提示和牌区

┌─────────────────────────────────────┐
│ 玩家                                │
│ 体力 / 手牌 / 装备                  │
└─────────────────────────────────────┘
```

要求：

- 第一战只有一个敌人区域。
- 第二战显示两个敌人区域。
- 当前回合角色有基本文字提示。
- 需要选择目标时，存活且合法的敌人区域可以点击。
- 不需要制作头像、动画或复杂主题。

## 兼容性要求

- 序章第一战仍然能够正常完成 1v1。
- 第一战胜利后仍然正确解锁第二战。
- 第二战失败后正确重开 1v2。
- 第二战击败一个敌人后战斗继续。
- 第二战击败全部敌人后才返回地图。
- 返回地图后“进入村落”解锁。
- 点击村落仍然只需执行：

```gdscript
print("已通关序章，进入村落！")
```

- 不破坏现有选将、基础 AI、伤害、濒死和卡牌结算流程。
- 尽量保留现有 `GameManager` 作为唯一规则入口。

## 测试要求

在现有测试基础上增加多人敌方回归测试，例如：

```text
tests/PrologueMultiEnemySmokeTest.tscn
tests/PrologueMultiEnemySmokeTest.gd
```

至少验证：

1. 第一战只创建一个 AI。
2. 第二战创建两个 AI。
3. 初始回合顺序为玩家、AI1、AI2。
4. 已死亡 AI 会被跳过。
5. 玩家可以分别选择两个 AI 作为【杀】的目标。
6. 击败第一个 AI 时战斗不会结束。
7. 击败第二个 AI 后才判定胜利。
8. 玩家死亡时第二战自动重开。
9. 失败不会增加序章完成进度。
10. 第二战胜利后解锁村落。
11. 第一战原有 1v1 流程不回归。
12. 现有 `RuleSmokeTest`、`SkillSmokeTest` 和 `PrologueSmokeTest` 继续通过。

使用 Godot 4 的无界面模式进行校验：

```powershell
Godot_v4.6-stable_win64_console.exe --headless --editor --path . --quit
Godot_v4.6-stable_win64_console.exe --headless --path . res://tests/RuleSmokeTest.tscn
Godot_v4.6-stable_win64_console.exe --headless --path . res://tests/SkillSmokeTest.tscn
Godot_v4.6-stable_win64_console.exe --headless --path . res://tests/PrologueSmokeTest.tscn
Godot_v4.6-stable_win64_console.exe --headless --path . res://tests/PrologueMultiEnemySmokeTest.tscn
```

## 实现原则

- 先检查现有代码，不要直接重写整个战斗系统。
- 只进行支持多人敌方所必需的结构调整。
- 优先将“固定对手”替换成“存活角色集合”和“显式目标”。
- 不要用大量 `if active_battle == 2` 分散在卡牌规则中。
- 关卡差异应集中在战斗配置或初始化阶段。
- 不要复制两份 `GameManager` 或两份战斗场景。
- 不要把敌人数量写死在 UI 和回合状态机中。
- 代码保持简洁，关键流程添加必要中文注释。
- 发现现有复杂卡牌无法在本次 MVP 中完整多人化时，应保证基础流程稳定，并在最终说明中明确限制。

## 输出要求

完成后请说明：

- 修改或新增了哪些文件。
- 如何根据关卡创建一个或两个 AI。
- 回合状态机如何跳过死亡角色。
- 玩家如何选择不同敌人。
- AI 如何选择玩家作为目标。
- 多敌人胜负判定如何实现。
- 哪些复杂卡牌已支持多人目标，哪些仍属于 MVP 限制。
- 执行了哪些测试以及测试结果。

最终交付必须是可以直接运行的序章流程，不只提供设计方案或伪代码。
