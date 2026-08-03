# AI 辅助重构提示词：重构底层架构以支持纯 AI 自动化对战

**如果你需要将任务交接给下一个 Agent（或开启一个新的对话窗口）来执行代码重构，你可以直接复制以下这块完整的提示词发送给它：**

---

**【角色设定】**
你是一位精通 Godot 4.6 和卡牌游戏底层架构设计的资深服务端/后端架构师。你需要接手一个《三国杀双人版》Godot 4.6 项目，并对其中的核心状态机进行解耦重构。

**【项目现状与痛点】**
目前游戏能够正常进行人类交互，但我们在进行高倍速 (`Engine.time_scale = 100.0`) 的“纯 AI vs AI”的无头模式 (Headless) Fuzzing 压力测试时，脚本发生了100%概率的底层死锁（卡死在 `FlowState.IDLE` 或 `GENERAL_SELECTION`）。
经排查，根本原因在于：
1. **UI 与核心逻辑强耦合**：`GameManager.gd` 的对局初始化生命周期（如发牌、进入回合）强依赖于 UI 界面的选将回调。如果在自动化脚本中直接通过 `setup_generals` 和 `start_match(false)` 初始化武将并强行把双方 `is_ai` 置为 `true`，系统会因为收不到预期的底层 UI 信号推送而彻底死锁。
2. **缺乏状态机兜底 (Watchdog)**：一旦发生时序错位或直接跨越状态，整个 GameManager 会卡在等待回调的状态，无法自愈。
3. **工厂模式设计瑕疵**：测试代码尝试通过 `GeneralFactory.create_skill()` 动态注入技能时抛出了引擎层面的 `Parse Error`（静态方法不存在或位置混乱），导致无法在运行时自由“缝合”武将技能进行边界组合测试。

**【你的任务目标】**
在**不破坏现有 Smoke Test 冒烟测试**的前提下，对项目进行解耦重构，使其完全支持“无需任何 UI 交互介入的纯 AI 自动化死循环对战”。你需要完成以下三个核心任务：

### 任务 1：核心管线与 UI 解耦 (Decoupling)
- 重构 `GameManager.gd` 中的对局初始化流程。允许以类似于 `start_automated_match()` 的形式直接启动纯 AI 对战。
- 解决 `_ready()` 函数中 `call_deferred("begin_general_selection")` 强制覆写测试脚本注入状态的问题。可以通过注入全局标识（如 `OS.has_feature("dedicated_server")` 或专门的启动参数配置）来分离交互模式和自动化测试模式。

### 2. 任务 2：状态机健壮性增强 (State Machine Robustness)
- 为 `GameManager` 引入状态超时或看门狗机制（如果适合）。或者更优雅地：将状态流转抽象为事件驱动的队列，当所有玩家均标记为 `is_ai = true` 时，系统应当自动步进（Auto-Step）到下一个合法状态，而不是挂起等待。

### 3. 任务 3：修复工厂模式 API 暴露问题
- 排查并重构技能与武将工厂（`GeneralFactory`, `SkillFactory` 等）。提供一个对外统一、安全的静态 API（例如 `SkillFactory.create_skill_by_id(id)`），确保我们在编写自动化测试脚本时，可以像组装乐高一样，把任意技能 ID 强行塞给任意 Player 对象，且不会引发 Parse Error。

**【执行要求】**
- 在开始写代码前，请先使用 `grep_search` 或 `view_file` 查阅 `scripts/GameManager.gd` 中的 `begin_general_selection`、`start_match` 等生命周期函数的现状。
- 请查阅 `scripts/Player.gd` 中 `is_ai` 的判断逻辑。
- 给出你的重构 Implementation Plan，获得批准后再开始动刀核心代码。

---
