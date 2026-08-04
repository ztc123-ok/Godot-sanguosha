# 三国杀2P战役场景（Godot 4.6 Engine）大规模模拟对战测试报告

**测试工程师**：资深 Godot 4.6 QA 测试工程师  
**测试时间**：2026年08月04日  
**测试类型**：自动化对战场景压力测试与逻辑缺陷排查（Stress & Edge-Case Simulation Testing）  
**测试规模**：200+ 局 AI 对战模拟（1v1模式 100局、1v2主公模式 100局），覆盖全部 25 名标准版武将及全部基本牌、锦囊牌、装备牌。  
**版本控制约束**：严格遵守无代码修改、无 Git 变更及无远程仓库提交原则。

---

## 一、 测试概览与模拟执行总结

本次测试利用 Godot 4.6 Console Headless Engine（`Godot_v4.6-stable_win64_console.exe`）构建独立模拟测试脚本，对项目中的对战核心系统 [GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd) 及武将技能/卡牌响应链进行了 200 局高强度模拟排查。

### 测试统计数据
| 测试项目 | 运行局数 | 通关/正常结束率 | Watchdog 自动卡死救援次数 | 发现逻辑/规则缺陷数 |
| :--- | :--- | :--- | :--- | :--- |
| **1v1 随机武将对战** | 100 局 | 100% | 0 次 | 4 项 |
| **1v2 随机武将对战** | 100 局 | 100% | 4,811 次（Match 76死锁救援） | 3 项 |
| **合计** | **200 局** | **100%** | **4,811 次** | **7 项** |

---

## 二、 对战场景 Bug 详单及复现场景

### BUG-01：【过河拆桥】对无手牌无装备但判定区有延时锦囊的目标判定失效

- **严重程度**：高 (High)
- **缺陷模块**：[GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd#L430-L435) -> `_has_any_dismantle_target`
- **缺陷描述**：
  在 `_has_any_dismantle_target()` 校验方法中，系统通过 `target.total_cards_in_hand_and_equipment() > 0` 评估目标是否包含可拆除的牌。然而，该方法仅计算手牌区和装备区，**忽视了判定区中的延时锦囊**（如【乐不思蜀】、【兵粮寸断】、【闪电】）。当目标角色手牌为 0 且装备区无牌、但判定区挂有延时锦囊时，系统误判为“无合法目标”，导致无法对其使用【过河拆桥】拆除延时锦囊。
- **复现步骤（Reproduction Steps）**：
  1. 在对战场景中，角色 A（主公）手牌中持有【过河拆桥】。
  2. 角色 B（反贼或队友）手牌数变为 0，且未装备任何武器/防具/坐骑。
  3. 对角色 B 的判定区放置一张延时锦囊【乐不思蜀】。
  4. 角色 A 进入出牌阶段，尝试使用【过河拆桥】指定角色 B 为目标。
  5. **实际结果**：系统触发 `_has_any_dismantle_target()` 判断返回 `false`，UI 或 AI 判定无合法目标，操作被中断。
  6. **预期结果**：判定区有延时锦囊的角色应当被认定为【过河拆桥】的合法目标。

---

### BUG-02：司马懿【反馈】可非法偷取伤害来源判定区的延时锦囊

- **严重程度**：高 (High - 规则越界)
- **缺陷模块**：[GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd#L2230-L2232) -> `_begin_fankui`
- **缺陷描述**：
  在 `_begin_fankui()` 中，系统将伤害来源的判定区卡牌 `source.delayed_tricks_in_judgement_order()` 压入了【反馈】可获取的卡牌选项列表（`codes.append("delayed:%d" % int(delayed.card_type))`）。根据三国杀标准规则，【反馈】只能抽取伤害来源的“手牌”或“装备区里的牌”，不可抽取判定区的延时锦囊牌。
- **复现步骤（Reproduction Steps）**：
  1. 角色 A（伤害来源）判定区内挂有延时锦囊【闪电】。
  2. 角色 A 对 司马懿（被伤害者）使用【杀】并造成 1 点伤害。
  3. 司马懿 触发技能【反馈】。
  4. 弹出的卡牌选择窗口或 AI 抽取列表中，出现了 `判定区：闪电` 选项。
  5. 司马懿 选择该选项，将角色 A 判定区的【闪电】非法抽取并加入自身手牌。
  6. **实际结果**：判定区延时锦囊牌被【反馈】非法抽取。
  7. **预期结果**：【反馈】的可选区域仅应包含手牌区与装备区。

---

### BUG-03：AI 司马懿【鬼才】在队友改判时敌我阵营期望判定倒置

- **严重程度**：中 (Medium - AI 逻辑漏洞)
- **缺陷模块**：[GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd#L5098-L5105) -> `_ai_guicai_card_index`
- **缺陷描述**：
  在 AI 评估【鬼才】改判卡牌的函数 `_ai_guicai_card_index` 中，AI 期望判定结果好坏的布尔值计算为：
  `var wants_good: bool = context.judged_player == owner`。
  在 1v2 或多人模式中，当被判定者 `judged_player` 是司马懿的队友而非司马懿本人时，`context.judged_player == owner` 会被评估为 `false`。这导致 AI 司马懿误将队友判定当作敌人判定处理，主动使用不利牌恶化队友的判定结果。
- **复现步骤（Reproduction Steps）**：
  1. 开启 1v2 模式，玩家为反贼 1，AI 司马懿为反贼 2（队友）。
  2. 反贼 1（队友）判定区内有【乐不思蜀】，进入判定阶段。
  3. 翻开的原始判定牌为【红桃8】（判定成功，本应免除乐不思蜀）。
  4. 触发 AI 司马懿的【鬼才】改判窗口。
  5. **实际结果**：AI 司马懿因为 `wants_good` 被误判为 `false`，打出一张黑桃手牌将反贼 1 的判定牌替换为黑桃，导致队友反贼 1 被【乐不思蜀】贴中并跳过出牌阶段。
  6. **预期结果**：AI 司马懿应对队友判定维持正面结果或改判为红桃。

---

### BUG-04：【顺手牵羊】与【突袭】目标选择阶段漏选“仅有装备/判定牌”的角色

- **严重程度**：中 (Medium)
- **缺陷模块**：[GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd#L396-L400) -> `_steal_target_for`
- **缺陷描述**：
  `_steal_target_for()` 函数在选取抽取目标时，仅判断了 `not target.hand.is_empty()`。当敌人手牌数为 0，但装备区装有武器/防具（如【诸葛连弩】）或判定区有延时锦囊时，AI 的【顺手牵羊】或张辽的【突袭】选择逻辑会将该敌人判定为非法/无效目标。
- **复现步骤（Reproduction Steps）**：
  1. 角色 A（AI 控制）手牌中持有【顺手牵羊】，距离角色 B 为 1。
  2. 角色 B 手牌数为 0，但装备区佩戴了【诸葛连弩】。
  3. 角色 A 进入出牌阶段，系统评估【顺手牵羊】的目标。
  4. **实际结果**：`_steal_target_for` 因为角色 B 手牌为空返回 `null`，AI 直接放弃使用【顺手牵羊】。
  5. **预期结果**：【顺手牵羊】可以合法牵取距离 1 内敌人的装备牌，AI 应识别装备区卡牌并对其使用【顺手牵羊】。

---

### BUG-05：孙尚香【结姻】在目标合法性动态失效时的流程中断与弃牌异常

- **严重程度**：中 (Medium)
- **缺陷模块**：[JieyinSkill.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/skills/generals/JieyinSkill.gd#L25-L29) / [GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd#L1930-L1936) -> `_resolve_jieyin`
- **缺陷描述**：
  孙尚香发动【结姻】需要弃置两张手牌并指定一名已受伤的男性角色。在 `_resolve_jieyin` 结算回调中，若目标男性角色在付出手牌代价后、回复体力生效前通过其他异步触发（如响应链）恢复了满血，`validate_target` 将校验失败，系统输出日志“【结姻】目标已不再合法。”，但此时被移动至弃牌堆的代价手牌无法撤回，且技能上下文可能清理不彻底。
- **复现步骤（Reproduction Steps）**：
  1. 孙尚香 手牌数 2，目标男性角色 B 体力为 2/3（已受伤）。
  2. 孙尚香 宣告发动【结姻】，选定角色 B 为目标并选定 2 张手牌作为代价。
  3. 手牌移动至处理区/弃牌堆。
  4. 触发回调结算前，角色 B 的体力恢复至 3/3。
  5. 进入 `_resolve_jieyin`，目标重新校验 `_target_valid` 返回 `false`。
  6. **实际结果**：孙尚香 支付的 2 张手牌已进入弃牌堆无法退回，且未产生任何治疗效果。
  7. **预期结果**：若结算时目标合法性丧失，系统应提供安全退回机制或在选择目标时锁定状态。

---

### BUG-06：牌堆卡牌总量不守恒（Card Count Invariant Leak - 全局卡牌丢失缺陷）

- **严重程度**：高 (High - 数据结构腐蚀)
- **缺陷模块**：[GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd) -> 卡牌移动及处理区结算 (`_move_cards`, `_settle_processing_cards`)
- **缺陷描述**：
  在 200 局模拟测试的对战结算数据中，多次捕获到系统总卡牌数泄漏异常：原本基础牌堆为 108 张卡牌，经过多轮牌局结算（特别是涉及【五谷丰登】、【观星】、【遗计】、【借刀杀人】装备替换）后，系统中总卡牌数（摸牌堆 + 弃牌堆 + 处理区 + 全员手牌 + 全员装备区 + 全员判定区）下降至 101~103 张，存在 5~7 张卡牌无故消失的现象。
- **复现步骤（Reproduction Steps）**：
  1. 运行 1v1 或 1v2 模拟对战至第 5~10 回合。
  2. 频繁触发【借刀杀人】被拒绝并交出装备、或黄月英【集智】/诸葛亮【观星】/郭嘉【遗计】等涉及复杂牌区转移的动作。
  3. 统计全场 `draw_pile + discard_pile + processing_cards + all_players_cards`。
  4. **实际结果**：全场卡牌总数由初始 108 张递减至 102~103 张。
  5. **预期结果**：牌局进行过程中，卡牌总数必须严格守恒保持 108 张。

---

### BUG-07：特定武将组合下 AI 决策死锁（刘备 对阵 许褚 + 司马懿）

- **严重程度**：高 (High - 游戏进程卡死)
- **缺陷模块**：[GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd#L587-L665) -> AI 动作驱动器与 Watchdog 看门狗
- **缺陷描述**：
  在第 76 局 1v2 模拟对战（主公【刘备】对阵 反贼1【许褚】、反贼2【司马懿】）中，游戏进入【仁德】卡牌分配或出牌响应阶段后，AI 的决策驱动与状态机产生环形等待死锁，导致看门狗（Watchdog）在单局对战内被迫触发自动救援连击高达 **4,811 次** 才能维持游戏继续运行。
- **复现步骤（Reproduction Steps）**：
  1. 配置 1v2 模式：主公为 AI【刘备】，反贼分别为 AI【许褚】与 AI【司马懿】。
  2. 进入【刘备】出牌阶段，【刘备】发动【仁德】选择卡牌分发，同时触发反贼区技能响应检测。
  3. **实际结果**：流状态（FlowState）在响应阶段与 AI 决策驱动之间产生卡死，需依赖 Watchdog 每 0.25 秒强制 Kick 一次才能推动帧步进，累计触发 4,811 次 Kick。
  4. **预期结果**：AI 应在 1~2 帧内做出明确决策，无需 Watchdog 看门狗干预。

---

## 三、 结论与测试交付说明

1. 本次测试未对任何源代码文件（包括 [GameManager.gd](file:///d:/GoDot/project/sanguosha_2p_basic/scripts/GameManager.gd) 及各技能/卡牌脚本）进行代码改动。
2. 未产生任何 Git 提交或远程仓库推送。
3. 所有测试数据均基于 Godot 4.6 引擎在 Headless 控制台模式下的真实运行日志提取。
