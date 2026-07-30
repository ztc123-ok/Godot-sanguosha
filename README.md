# 三国杀·二人标准锦囊版

Godot 4.6 正式版、纯 GDScript 4.x。玩家控制主公 Player1，基础 AI 控制反贼 Player2。

## 运行

1. 使用 Godot 4.6 打开本目录的 `project.godot`。
2. 按 F6/F5 运行主场景。
3. 无需第三方插件、字体或图片素材。

## 操作

- 主动牌：点击手牌后点击角色目标，或直接把牌拖到角色区。
- 【无懈可击】：锦囊即将生效时，按提示选择使用或放弃；允许继续反无懈。
- 【决斗】/AOE/借刀：按提示打出【杀】、【闪】或放弃响应。
- 【铁索连环】：点击后可选择自己、对手、双方或重铸。
- 【五谷丰登】：亮出的牌会暂时显示在手牌区，点击选择。
- 【火攻】：目标点击一张手牌展示；来源点击同花色牌弃置，也可放弃。
- 延时锦囊、武器和连环状态会显示在双方角色状态栏。
- 弃牌阶段按提示点击手牌，弃到当前体力上限。

## 卡牌与规则

基础牌：

- 【杀】【闪】【桃】【酒】

普通及群体锦囊：

- 【过河拆桥】【顺手牵羊】【无中生有】【决斗】【借刀杀人】
- 【五谷丰登】【桃园结义】【无懈可击】
- 【南蛮入侵】【万箭齐发】【铁索连环】【火攻】

延时锦囊：

- 【乐不思蜀】：判定不为红桃，跳过出牌阶段。
- 【兵粮寸断】：判定不为梅花，跳过摸牌阶段。
- 【闪电】：黑桃 2~9 造成 3 点雷电伤害，否则传递。

规则系统还包括：

- 每个目标效果独立进入无懈响应链；奇数层抵消、偶数层恢复生效。
- 决斗双方轮流打出【杀】。
- 火焰/雷电伤害触发铁索连环传播，传播时相关角色重置。
- 延时锦囊进入判定区，并可在判定效果生效前被【无懈可击】。
- 双人局距离恒为 1。
- 最小武器槽及【青釭剑】用于完整支持过拆、顺手和借刀；本轮不实现额外武器技能。
- 所有规则步骤同时输出到 Godot 控制台和界面对局日志。

## 结构

```text
scenes/Main.tscn
scripts/
├── Main.gd
├── GameManager.gd
├── Player.gd
├── UIManager.gd
├── cards/
│   ├── Card.gd
│   ├── CardFactory.gd
│   ├── SlashCard.gd / DodgeCard.gd / PeachCard.gd / WineCard.gd
│   ├── equipment/WeaponCard.gd
│   └── tricks/
│       ├── DismantleCard.gd / StealCard.gd / DrawTwoCard.gd
│       ├── DuelCard.gd / BorrowSwordCard.gd
│       ├── AmazingGraceCard.gd / PeachGardenCard.gd
│       ├── NullificationCard.gd
│       ├── BarbarianInvasionCard.gd / ArrowBarrageCard.gd
│       ├── IronChainCard.gd / FireAttackCard.gd
│       └── IndulgenceCard.gd / SupplyShortageCard.gd / LightningCard.gd
└── ui/
    ├── CardView.gd
    └── PlayerDropZone.gd
```

`GameManager` 是唯一规则入口。UI 和 AI 只发送请求，不能直接修改领域状态；伤害、濒死和胜负继续复用同一结算链，因此新增锦囊不会绕过原有【桃】/【酒】自救规则。

## 测试

```powershell
Godot_v4.6-stable_win64_console.exe --headless --path . --scene res://tests/RuleSmokeTest.tscn
```

测试覆盖基础牌、15 类锦囊、无懈链、群体响应、连环属性伤害、判定和闪电传递。
