class_name GameManager
extends Node
## 双人局唯一规则入口。
## 所有主动牌、响应牌、锦囊、判定、伤害和濒死均经过本状态机结算。

## 各序章关卡的敌人数量配置；关卡差异集中在此，避免散落到卡牌规则中。
const BATTLE_CONFIGS := {
	1: {
		"enemy_count": 1,
	},
	2: {
		"enemy_count": 2,
	},
}

const EquipmentScript = preload("res://scripts/cards/equipment/Equipment.gd")
const JudgementContextScript = preload("res://scripts/skills/JudgementContext.gd")
const TriggerEntryScript = preload("res://scripts/skills/TriggerEntry.gd")
const CardMoveContextScript = preload("res://scripts/skills/CardMoveContext.gd")
const SlashTargetContextScript = preload("res://scripts/skills/SlashTargetContext.gd")
const SilverLionLeaveScript = preload("res://scripts/skills/generals/SilverLionLeaveSkill.gd")

signal state_changed
signal log_added(message: String)
signal match_finished(winner: BattlePlayer, loser: BattlePlayer)
## 多人敌方战斗的统一胜负信号：true 表示玩家获胜，false 表示玩家失败。
signal battle_finished(player_won: bool)

enum Phase {
	START,
	JUDGEMENT,
	DRAW,
	PLAY,
	DISCARD,
	END,
}

enum FlowState {
	IDLE,
	GENERAL_SELECTION,
	PLAY_ACTIVE,
	SELECTING_TARGET,
	RESPONDING_SLASH,
	MULTI_RESPONSE,
	NULLIFICATION_RESPONSE,
	CHOOSING_OPTION,
	CHOOSING_REVEALED,
	AOE_RESPONSE,
	DUEL_RESPONSE,
	FIRE_REVEAL,
	FIRE_DISCARD,
	BORROW_RESPONSE,
	DYING_RESCUE,
	DISCARDING,
	SKILL_CONFIRM,
	SKILL_SELECT_CARDS,
	SKILL_SELECT_TARGET,
	SKILL_RESOLVING,
	JUDGEMENT_REPLACE,
	DECK_REORDER,
	SKILL_ASSIGN_CARDS,
	CHOOSING_SUIT,
	SLASH_TRANSFER,
	GAME_OVER,
}

enum DamageNature {
	NORMAL,
	FIRE,
	THUNDER,
}

## ???????????????
enum CardZone {
	HAND,
	WEAPON,
	ARMOR,
	HORSE_PLUS,
	HORSE_MINUS,
	DELAYED_TRICK,
	PROCESSING,
	DISCARD,
	DECK,
	PRIVATE,
}

@onready var player1: BattlePlayer = $Players/Player1
@onready var player2: BattlePlayer = $Players/Player2

var players: Array[BattlePlayer] = []
## AI 反贼集合：通过数组遍历，核心流程不依赖 enemy1/enemy2 分支。
var enemies: Array[BattlePlayer] = []
var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []
## 已支付但尚未完成整条效果的实体牌。效果完成后统一进入弃牌堆，
## 或被【奸雄】等技能从此区域取得。
var processing_cards: Array[Card] = []

var current_player_index: int = 0
var turn_number: int = 0
var phase: Phase = Phase.START
var flow_state: FlowState = FlowState.IDLE
var winner: BattlePlayer

var selected_hand_index: int = -1
var pending_attacker: BattlePlayer
var pending_target: BattlePlayer
var pending_damage: int = 0
var dying_player: BattlePlayer
## ????????????????????????????????
var rescue_actor: BattlePlayer

var revealed_cards: Array[Card] = []
var choice_labels: Array[String] = []
var choice_owner: BattlePlayer

var _action_generation: int = 0
var _skip_draw_phase: bool = false
var _skip_play_phase: bool = false

## 武将与技能流程上下文。
var skill_owner: BattlePlayer
var skill_actor: BattlePlayer
var pending_skill: Skill
var pending_skill_cards: Array[Card] = []
var pending_skill_targets: Array[BattlePlayer] = []
var response_required_count: int = 1
var response_received_count: int = 0
var _skill_event_context: RefCounted
var _skill_confirm_continue: Callable = Callable()
var _skill_cancel_continue: Callable = Callable()
var _skill_return_state: FlowState = FlowState.IDLE
var _skill_effective_card_type: Card.CardType = Card.CardType.SLASH
var _skill_use_context: SkillUseContext
var _draw_context: DrawContext
var judgement_context: JudgementContextScript
var private_cards: Array[Card] = []
var private_card_owner: BattlePlayer
var private_card_assignments: Array[int] = []
var deck_reorder_top: Array[Card] = []
var deck_reorder_bottom: Array[Card] = []
var _trigger_queue: Array[TriggerEntryScript] = []
var _trigger_queue_continue: Callable = Callable()
var _trigger_stack: Array[Dictionary] = []
var _judgement_result_handler: Callable = Callable()
var _judgement_continue: Callable = Callable()
var _judgement_guicai_owners: Array[BattlePlayer] = []
var _judgement_guicai_index: int = 0
var _judged_delayed_card: Card
var _async_skill_continue: Callable = Callable()
var _fanjian_selected_suit: Card.Suit = Card.Suit.SPADE
var _fanjian_source: BattlePlayer
var _fanjian_target: BattlePlayer
## 【离间】两步选目标：先选决斗发起者，再选决斗对象。
var _lijian_first_target: BattlePlayer = null
## 【丈八蛇矛】出牌阶段视为【杀】时等待玩家选目标的缓存：[user, paid_cards]。
var _pending_serpent_spear: Array = []
var _luoshen_final_continue: Callable = Callable()
var _liuli_slash_context: RefCounted
var _liuli_continue: Callable = Callable()
## 【刚烈】惩罚弃牌：由伤害来源选择弃哪两张手牌。
var _ganglie_discard_active: bool = false
var _ganglie_discard_continue: Callable = Callable()
var _ganglie_discard_owner: BattlePlayer
var _ganglie_discard_source: BattlePlayer

## 当前主动牌与【杀】各自的使用上下文。
var _active_use_context: SkillUseContext
var _attack_use_context: SkillUseContext
var _duel_use_context: SkillUseContext

## 普通【杀】/借刀【杀】上下文。
var _attack_after: Callable = Callable()
var _attack_nature: DamageNature = DamageNature.NORMAL
var _slash_ignores_armor: bool = false
var _ice_sword_checked: bool = false
var _bagua_attempted: bool = false
var _slash_dodge_forbidden: bool = false
var _pending_weapon_skill: Card.CardType = Card.CardType.SLASH

## 通用伤害队列；普通、属性与连环传播都使用 DamageContext。
var _damage_queue: Array[DamageContext] = []
var _damage_after: Callable = Callable()
var _dying_after: Callable = Callable()
var _damage_trigger_continue: Callable = Callable()
var _last_damage_context: DamageContext

## 无懈可击链上下文。
var _effect_card: Card
var _effect_source: BattlePlayer
var _effect_target: BattlePlayer
var _effect_apply: Callable = Callable()
var _effect_cancel: Callable = Callable()
var _effect_finish: Callable = Callable()
var _effect_harmful: bool = true
var _nullification_count: int = 0
var _nullification_passes: int = 0
var _nullification_responder_index: int = 0

## 通用选项上下文。
var _choice_handler: Callable = Callable()
var _zone_choice_codes: Array[String] = []

## 群体锦囊上下文。
var _global_card: Card
var _global_source: BattlePlayer
var _global_targets: Array[BattlePlayer] = []
var _global_index: int = 0

## AOE、决斗、火攻、借刀上下文。
var _response_card_type: Card.CardType = Card.CardType.SLASH
var _multi_response_origin: FlowState = FlowState.IDLE
var _duel_responder: BattlePlayer
var _duel_other: BattlePlayer
var _fire_revealed_card: Card
var _fire_source: BattlePlayer
var _fire_target: BattlePlayer
var _borrow_source: BattlePlayer
var _borrow_target: BattlePlayer
## 【借刀杀人】指定出【杀】的目标角色（默认是使用者本人；人类使用时可选）。
var _borrow_slash_target: BattlePlayer = null
var _pending_borrow_slash_target: bool = false

## 五谷丰登选择上下文。
var _revealed_selecting_player: BattlePlayer

## 铁索连环逐目标结算。
var _chain_card: Card
var _chain_source: BattlePlayer
var _chain_targets: Array[BattlePlayer] = []
var _chain_index: int = 0
## 铁索连环的选项缓存（code + label），避免用固定索引写死敌人数。
var _iron_chain_options_cache: Array[Dictionary] = []

## 判定阶段上下文。
var _judgement_queue: Array[Card] = []
var _judgement_index: int = 0
var _judging_card: Card

## ── 自动化（纯 AI）模式 ──────────────────────────────────────────
## 当 automated_mode 为 true 或双方 is_ai 均为 true 时，状态机不再依赖
## UI 回调：开局自动配将/开始，决策状态由看门狗自动步进到合法下一步。
const DEFAULT_WATCHDOG_INTERVAL: float = 1.0
const WATCHDOG_HARD_RECOVER_SECONDS: float = 30.0
const WATCHDOG_STUCK_LOG_INTERVAL: float = 10.0

var automated_mode: bool = false
## 允许纯 AI 对战在 GAME_OVER 后按相同配置自动重开，形成无脚本死循环。
var auto_recover_stuck_matches: bool = true
## 看门狗墙钟检查间隔（秒）。Engine.time_scale 不影响该间隔。
var watchdog_interval: float = DEFAULT_WATCHDOG_INTERVAL
var _watchdog_accumulator: float = 0.0
var _watchdog_busy: bool = false
var _watchdog_kick_count: int = 0
var _last_watchdog_seen_state: int = -1
var _stuck_since_wall: float = -1.0
var _last_stuck_log_wall: float = 0.0
var _automated_match_config: Dictionary = {}
## 已排队等待执行的 AI 驱动数量：看门狗跳过这些状态，避免与定时器双驱动。
var _pending_ai_action_count: int = 0


func _ready() -> void:
	## 根据当前序章关卡生成敌人阵容，再组合出全员列表。
	_ensure_enemy_players()
	players = [player1]
	players.append_array(enemies)
	if _automated_boot_requested():
		## 无头/服务端模式下跳过 UI 选将，直接以默认配置开启纯 AI 对战。
		automated_mode = true
		call_deferred("start_automated_match")
	else:
		## 交互模式：维持原有 UI 选将生命周期。
		call_deferred("begin_general_selection")


## 根据 PrologueState.active_battle 生成敌人阵容。
## 场景固定提供 Player2，多出的敌人按需动态创建，敌人数量可继续扩展。
func _ensure_enemy_players() -> void:
	enemies.clear()
	enemies.append(player2)
	player2.player_name = "AI 反贼 1"
	var count: int = enemy_count_for_current_battle()
	for extra: int in range(2, count + 1):
		var enemy := BattlePlayer.new()
		enemy.name = "Player%d" % (extra + 1)
		enemy.player_name = "AI 反贼 %d" % extra
		enemy.role_name = "反贼"
		enemy.is_ai = true
		$Players.add_child(enemy)
		enemies.append(enemy)


func enemy_count_for_current_battle() -> int:
	var config: Dictionary = BATTLE_CONFIGS.get(PrologueState.active_battle, {})
	return int(config.get("enemy_count", 1))


## 存活角色集合（含玩家与全部 AI）。
func living_players() -> Array[BattlePlayer]:
	var result: Array[BattlePlayer] = []
	for player: BattlePlayer in players:
		if not player.is_dying():
			result.append(player)
	return result


## 存活 AI 反贼集合。
func living_enemies() -> Array[BattlePlayer]:
	var result: Array[BattlePlayer] = []
	for enemy: BattlePlayer in enemies:
		if not enemy.is_dying():
			result.append(enemy)
	return result


func first_living_enemy() -> BattlePlayer:
	for enemy: BattlePlayer in enemies:
		if not enemy.is_dying():
			return enemy
	return null


func human_player() -> BattlePlayer:
	return player1


## 从当前角色开始按线性轮转查找下一名存活角色（已死亡角色被跳过）。
func next_living_player_index(from_index: int = current_player_index) -> int:
	if players.is_empty():
		return from_index
	for offset: int in range(1, players.size() + 1):
		var candidate: int = (from_index + offset) % players.size()
		if not players[candidate].is_dying():
			return candidate
	return from_index


func _next_living_player_after(player: BattlePlayer) -> BattlePlayer:
	if player == null or players.is_empty():
		return null
	var start: int = player_index(player)
	for offset: int in range(1, players.size() + 1):
		var candidate: BattlePlayer = players[(start + offset) % players.size()]
		if not candidate.is_dying():
			return candidate
	return null


## 濒死救援顺序：濒死者本人先行动，之后按行动顺序逐名存活角色行动。
func _next_rescue_actor(dying: BattlePlayer) -> BattlePlayer:
	return _next_living_player_after(dying)


## AI 的默认攻击目标：永远只针对玩家，不攻击其他 AI。
func choose_ai_target(ai: BattlePlayer) -> BattlePlayer:
	if ai == null or ai.is_dying():
		return null
	return player1 if player1 != null and not player1.is_dying() else null


## 单人目标的 MVP 兜底：AI 打玩家，玩家打第一个存活反贼。
func _default_rival(player: BattlePlayer) -> BattlePlayer:
	if player == null:
		return null
	## 以“是否为主公”判断攻防双方，而非 is_ai：测试中敌人可能临时关闭 AI 标记。
	if player == player1:
		return first_living_enemy()
	return player1 if player1 != null and not player1.is_dying() else null


## 玩家出牌（或 AI 出牌）时的潜在目标集合。
func _potential_targets_for(user: BattlePlayer) -> Array[BattlePlayer]:
	var result: Array[BattlePlayer] = []
	if user == null:
		return result
	if user == player1:
		return living_enemies()
	if player1 != null and not player1.is_dying():
		result.append(player1)
	return result


## 突袭目标：任意一名持有手牌的对手（AI 取玩家，玩家取第一个有手牌的存活反贼）。
func _steal_target_for(owner: BattlePlayer) -> BattlePlayer:
	for target: BattlePlayer in _potential_targets_for(owner):
		if not target.hand.is_empty():
			return target
	return null


## 除使用者外的全部存活角色（“所有其他角色”类牌的结算顺序按列表顺序）。
func _other_living_players(source: BattlePlayer) -> Array[BattlePlayer]:
	var result: Array[BattlePlayer] = []
	for player: BattlePlayer in living_players():
		if player != source:
			result.append(player)
	return result


## 从指定角色开始的行动顺序（包含自身），用于鬼才改判、五谷丰登等顺序结算。
func _all_living_players_ordered_from(starting_player: BattlePlayer) -> Array[BattlePlayer]:
	var result: Array[BattlePlayer] = []
	var start: int = player_index(starting_player)
	for offset: int in range(players.size()):
		var candidate: BattlePlayer = players[(start + offset) % players.size()]
		if not candidate.is_dying() and candidate not in result:
			result.append(candidate)
	return result


func _any_legal_trick_target(card: Card, user: BattlePlayer) -> bool:
	for target: BattlePlayer in _potential_targets_for(user):
		if _is_valid_trick_target(card, user, target):
			return true
	return false


func _has_any_dismantle_target(user: BattlePlayer) -> bool:
	for target: BattlePlayer in _potential_targets_for(user):
		if target.total_cards_in_hand_and_equipment() > 0:
			return true
	return false


func _has_any_indulgence_target(user: BattlePlayer) -> bool:
	var virtual_indulgence: Card = CardFactory.create_card(Card.CardType.INDULGENCE)
	for target: BattlePlayer in _potential_targets_for(user):
		if _is_valid_trick_target(virtual_indulgence, user, target):
			return true
	return false


## 响应场景中的“对方”：优先取当前正在交互的对手，退回默认对手。
func _response_opponent(player: BattlePlayer) -> BattlePlayer:
	if player == null:
		return null
	if flow_state == FlowState.DYING_RESCUE and dying_player != null and dying_player != player:
		return dying_player
	if pending_attacker != null and pending_attacker != player:
		return pending_attacker
	if _duel_other != null and _duel_other != player:
		return _duel_other
	if _global_source != null and _global_source != player:
		return _global_source
	if _borrow_slash_target != null and _borrow_slash_target != player:
		return _borrow_slash_target
	if _borrow_source != null and _borrow_source != player:
		return _borrow_source
	return _default_rival(player)


## 出牌阶段使用【杀】（含丈八蛇矛等视为杀的途径）时的默认目标：
## AI 打玩家，玩家打第一个存活反贼。
func _default_attack_target(user: BattlePlayer) -> BattlePlayer:
	if user == null:
		return null
	if user == player1:
		return first_living_enemy()
	return player1 if player1 != null and not player1.is_dying() else null


## 为未配将、武将无效或重复的角色从武将池补选，保证全员武将互不相同。
func _ensure_distinct_generals() -> void:
	var used: Array[StringName] = []
	for player: BattlePlayer in players:
		if player.general_id != &"" and GeneralFactory.is_valid_id(player.general_id):
			used.append(player.general_id)
	for player: BattlePlayer in players:
		if (
			player.general_id != &""
			and GeneralFactory.is_valid_id(player.general_id)
			and used.count(player.general_id) == 1
		):
			continue
		var pool: Array[StringName] = GeneralFactory.all_general_ids()
		pool = pool.filter(func(id: StringName) -> bool: return not used.has(id))
		pool.shuffle()
		if pool.is_empty():
			return
		var pick: StringName = pool[0]
		player.assign_general(GeneralFactory.create_general(pick))
		used.append(pick)


func _automated_boot_requested() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg in ["--auto-ai", "--fuzz", "--automated-match"]:
			return true
	return false


func set_automated_mode(enabled: bool) -> void:
	automated_mode = enabled


func is_automated_mode() -> bool:
	return automated_mode


## 纯 AI 自动化开局入口：无需任何 UI 交互即可完成配将、技能缝合与首回合开始。
## 返回 false 表示配置非法且无法回退；未知技能 ID 会被安全忽略（不抛错）。
func start_automated_match(
	player1_general_id: StringName = GeneralFactory.DEFAULT_PLAYER_GENERAL,
	player2_general_id: StringName = GeneralFactory.DEFAULT_AI_GENERAL,
	player1_extra_skills: Array[StringName] = [],
	player2_extra_skills: Array[StringName] = []
) -> bool:
	automated_mode = true
	var p1_id: StringName = player1_general_id
	var p2_id: StringName = player2_general_id
	if not GeneralFactory.is_valid_id(p1_id):
		p1_id = GeneralFactory.DEFAULT_PLAYER_GENERAL
	if not GeneralFactory.is_valid_id(p2_id) or p2_id == p1_id:
		var candidates: Array[StringName] = GeneralFactory.all_general_ids()
		candidates.erase(p1_id)
		candidates.shuffle()
		p2_id = candidates[0] if not candidates.is_empty() else GeneralFactory.DEFAULT_AI_GENERAL
	if not setup_generals(p1_id, p2_id):
		return false
	player1.is_ai = true
	player2.is_ai = true
	for skill_id: StringName in player1_extra_skills:
		player1.add_skill_id(skill_id)
	for skill_id: StringName in player2_extra_skills:
		player2.add_skill_id(skill_id)
	_automated_match_config = {
		"p1_general": p1_id,
		"p2_general": p2_id,
		"p1_skills": player1_extra_skills.duplicate(),
		"p2_skills": player2_extra_skills.duplicate(),
	}
	## 直接开始首回合；若此前 _ready 的 deferred 调用已进入选将，此处会完整复位。
	start_match(true)
	return true


func _restart_automated_match() -> void:
	if _automated_match_config.is_empty():
		start_automated_match()
		return
	start_automated_match(
		_automated_match_config.get("p1_general", GeneralFactory.DEFAULT_PLAYER_GENERAL),
		_automated_match_config.get("p2_general", GeneralFactory.DEFAULT_AI_GENERAL),
		_automated_match_config.get("p1_skills", []),
		_automated_match_config.get("p2_skills", [])
	)


## 看门狗激活条件：双方均标记为 AI（与调用方是否开启 automated_mode 无关）。
func _all_ai() -> bool:
	if players.is_empty():
		return false
	for player: BattlePlayer in players:
		if player == null or not player.is_ai:
			return false
	return true


func _process(delta: float) -> void:
	if flow_state != _last_watchdog_seen_state:
		_last_watchdog_seen_state = int(flow_state)
		_stuck_since_wall = -1.0
	if not _all_ai() or flow_state == FlowState.GAME_OVER:
		_watchdog_accumulator = 0.0
		return
	_watchdog_accumulator += delta
	if _watchdog_accumulator < watchdog_interval:
		return
	_watchdog_accumulator = 0.0
	_watchdog_step()


func _watchdog_step() -> void:
	if _watchdog_busy:
		return
	if _pending_ai_action_count > 0:
		## 已有定时器将在下帧驱动当前状态，看门狗不重复介入。
		return
	_watchdog_busy = true
	var state: FlowState = flow_state
	match state:
		FlowState.GENERAL_SELECTION:
			_watchdog_kick(state, &"_auto_start_from_selection")
			_auto_start_from_selection()
		FlowState.IDLE:
			if turn_number == 0:
				## 开局后停在 IDLE（如 start_match(false) 的遗留场景）：补开首回合。
				_watchdog_kick(state, &"_begin_turn")
				_begin_turn()
			else:
				## 回合间的瞬态 IDLE 不主动干预，避免重复开回合。
				_watchdog_note_stuck(state)
		_:
			var driver: StringName = _ai_driver_for_state(state)
			if driver != &"":
				_watchdog_kick(state, driver)
				call(driver)
			else:
				_watchdog_note_stuck(state)
	_watchdog_busy = false


## 决策状态 → AI 驱动方法映射。驱动方法本身带 flow_state/is_ai 守卫，
## 看门狗重复触发时自动幂等跳过。
func _ai_driver_for_state(state: FlowState) -> StringName:
	match state:
		FlowState.PLAY_ACTIVE:
			return &"_perform_ai_play"
		FlowState.DISCARDING:
			return &"_perform_ai_discard"
		FlowState.RESPONDING_SLASH, FlowState.AOE_RESPONSE, \
		FlowState.DUEL_RESPONSE, FlowState.BORROW_RESPONSE, FlowState.MULTI_RESPONSE:
			return &"_perform_ai_response"
		FlowState.SKILL_CONFIRM:
			return &"_perform_ai_skill_confirm"
		FlowState.CHOOSING_OPTION:
			return &"_perform_ai_choice"
		FlowState.CHOOSING_SUIT:
			return &"_perform_ai_choose_fanjian_suit"
		FlowState.SKILL_ASSIGN_CARDS:
			return &"_perform_ai_confirm_private_cards"
		FlowState.DECK_REORDER:
			return &"_perform_ai_confirm_deck_reorder"
		FlowState.NULLIFICATION_RESPONSE:
			return &"_perform_ai_nullification"
		FlowState.FIRE_DISCARD:
			return &"_perform_ai_fire_discard"
		FlowState.CHOOSING_REVEALED:
			return &"_perform_ai_amazing_grace"
		FlowState.JUDGEMENT_REPLACE:
			return &"_perform_ai_guicai"
		FlowState.DYING_RESCUE:
			return &"_perform_ai_rescue"
	return &""


func _auto_start_from_selection() -> void:
	## 保留测试已注入的合法武将；缺省、非法或重复时从武将池补选，并保证全员互不相同。
	_ensure_distinct_generals()
	start_match()


func _watchdog_kick(state: FlowState, driver: StringName) -> void:
	_watchdog_kick_count += 1
	_stuck_since_wall = -1.0
	_add_log("[WATCHDOG] 自动步进：%s -> %s" % [FlowState.keys()[int(state)], driver])


func _watchdog_note_stuck(state: FlowState) -> void:
	var now: float = _wall_time()
	if _stuck_since_wall < 0.0:
		_stuck_since_wall = now
	if (
		now - _stuck_since_wall >= WATCHDOG_STUCK_LOG_INTERVAL
		and now - _last_stuck_log_wall >= WATCHDOG_STUCK_LOG_INTERVAL
	):
		_last_stuck_log_wall = now
		push_warning(
			"[WATCHDOG] 状态 %s 无可用 AI 驱动，等待自愈。phase=%d 回合=%d 当前玩家=%s" % [
				FlowState.keys()[int(state)],
				int(phase),
				turn_number,
				current_player().player_name,
			]
		)
	if automated_mode and auto_recover_stuck_matches and now - _stuck_since_wall >= WATCHDOG_HARD_RECOVER_SECONDS:
		_add_log("[WATCHDOG] 状态 %s 卡死超过 %d 秒，自动重开对局。" % [
			FlowState.keys()[int(state)],
			int(WATCHDOG_HARD_RECOVER_SECONDS),
		])
		_restart_automated_match()


func _wall_time() -> float:
	return Time.get_ticks_msec() / 1000.0


func begin_general_selection(preserve_generals: bool = false) -> void:
	_action_generation += 1
	_reset_transient_contexts()
	_clear_skill_context()
	_settle_processing_cards()
	draw_pile.clear()
	discard_pile.clear()
	revealed_cards.clear()
	turn_number = 0
	current_player_index = 0
	winner = null
	phase = Phase.START
	flow_state = FlowState.GENERAL_SELECTION
	for player: BattlePlayer in players:
		player.hand.clear()
		player.hand_changed.emit()
	if not preserve_generals:
		for player: BattlePlayer in players:
			player.clear_general()
	_add_log("进入选将阶段：请选择主公武将，反贼将从剩余武将中选择。")
	_emit_state()


func request_select_general(general_id: StringName) -> void:
	if flow_state != FlowState.GENERAL_SELECTION or not GeneralFactory.is_valid_id(general_id):
		return
	var definition: GeneralDefinition = GeneralFactory.create_general(general_id)
	player1.assign_general(definition)
	var candidates: Array[StringName] = GeneralFactory.all_general_ids()
	candidates.erase(general_id)
	candidates.shuffle()
	var ai_names: PackedStringArray = []
	for enemy: BattlePlayer in enemies:
		if candidates.is_empty():
			break
		var ai_id: StringName = candidates.pop_back()
		enemy.assign_general(GeneralFactory.create_general(ai_id))
		ai_names.append(enemy.general_name)
	_add_log("主公选择【%s】；反贼选择%s。" % [
		player1.general_name,
		"、".join(ai_names) if not ai_names.is_empty() else "（武将池不足）",
	])
	_emit_state()


func setup_generals(player1_general_id: StringName, player2_general_id: StringName) -> bool:
	if (
		not GeneralFactory.is_valid_id(player1_general_id)
		or not GeneralFactory.is_valid_id(player2_general_id)
		or player1_general_id == player2_general_id
	):
		return false
	_action_generation += 1
	player1.assign_general(GeneralFactory.create_general(player1_general_id))
	player2.assign_general(GeneralFactory.create_general(player2_general_id))
	return true


func request_start_match() -> void:
	if flow_state != FlowState.GENERAL_SELECTION:
		return
	var generals_ready: bool = player1.general_id != &""
	for enemy: BattlePlayer in enemies:
		if enemy.general_id == &"":
			generals_ready = false
			break
	if not generals_ready:
		_reject("尚未确定全部武将。")
		return
	start_match()


func request_use_default_generals() -> void:
	if flow_state != FlowState.GENERAL_SELECTION:
		return
	setup_generals(GeneralFactory.DEFAULT_PLAYER_GENERAL, GeneralFactory.DEFAULT_AI_GENERAL)
	_ensure_distinct_generals()
	var enemy_text: PackedStringArray = []
	for enemy: BattlePlayer in enemies:
		enemy_text.append("【%s】" % enemy.general_name)
	_add_log("已载入默认选将：主公【曹操】、反贼 %s。" % "、".join(enemy_text))
	_emit_state()


func request_restart_match() -> void:
	if flow_state != FlowState.GAME_OVER:
		return
	start_match()


func request_reselect_generals() -> void:
	begin_general_selection(false)


func start_match(begin_first_turn: bool = true) -> void:
	## 公开且确定性的开局入口；初次运行由选将面板调用。
	_ensure_distinct_generals()
	_action_generation += 1
	_reset_transient_contexts()
	_clear_skill_context()
	processing_cards.clear()
	draw_pile = CardFactory.create_basic_deck()
	discard_pile.clear()
	revealed_cards.clear()
	current_player_index = 0
	turn_number = 0
	winner = null
	selected_hand_index = -1
	pending_attacker = null
	pending_target = null
	dying_player = null
	flow_state = FlowState.IDLE

	for player: BattlePlayer in players:
		player.reset_for_match()
		for skill: Skill in player.skills:
			skill.on_general_reset(self, player)
		draw_cards(player, 4)

	var enemy_summary: PackedStringArray = []
	for enemy: BattlePlayer in enemies:
		enemy_summary.append("%s【%s】" % [enemy.player_name, enemy.general_name])
	_add_log("游戏开始：主公 %s【%s】 对阵 %s。" % [
		player1.player_name,
		player1.general_name,
		"、".join(enemy_summary),
	])
	_add_log("双方各摸 4 张起始手牌，主公先手。")
	if begin_first_turn:
		_begin_turn()
	else:
		flow_state = FlowState.IDLE
		_emit_state()


func _reset_transient_contexts() -> void:
	selected_hand_index = -1
	pending_attacker = null
	pending_target = null
	pending_damage = 0
	dying_player = null
	rescue_actor = null
	revealed_cards.clear()
	choice_labels.clear()
	choice_owner = null
	_choice_handler = Callable()
	_zone_choice_codes.clear()
	_attack_after = Callable()
	_attack_nature = DamageNature.NORMAL
	_attack_use_context = null
	_active_use_context = null
	_duel_use_context = null
	_slash_ignores_armor = false
	_ice_sword_checked = false
	_bagua_attempted = false
	_slash_dodge_forbidden = false
	_effect_card = null
	_effect_source = null
	_effect_target = null
	_effect_apply = Callable()
	_effect_cancel = Callable()
	_effect_finish = Callable()
	_global_card = null
	_global_source = null
	_global_targets.clear()
	_global_index = 0
	_duel_responder = null
	_duel_other = null
	_fire_revealed_card = null
	_fire_source = null
	_fire_target = null
	_borrow_source = null
	_borrow_target = null
	_borrow_slash_target = null
	_pending_borrow_slash_target = false
	_revealed_selecting_player = null
	_chain_card = null
	_chain_source = null
	_chain_targets.clear()
	_chain_index = 0
	_lijian_first_target = null
	_pending_serpent_spear.clear()
	_judgement_queue.clear()
	_judgement_index = 0
	_judging_card = null
	judgement_context = null
	private_cards.clear()
	private_card_owner = null
	private_card_assignments.clear()
	deck_reorder_top.clear()
	deck_reorder_bottom.clear()
	_trigger_queue.clear()
	_trigger_queue_continue = Callable()
	_trigger_stack.clear()
	_judgement_result_handler = Callable()
	_judgement_continue = Callable()
	_judgement_guicai_owners.clear()
	_judgement_guicai_index = 0
	_judged_delayed_card = null
	_async_skill_continue = Callable()
	_fanjian_source = null
	_fanjian_target = null
	_luoshen_final_continue = Callable()
	_liuli_slash_context = null
	_liuli_continue = Callable()
	_ganglie_discard_active = false
	_ganglie_discard_continue = Callable()
	_ganglie_discard_owner = null
	_ganglie_discard_source = null
	_damage_queue.clear()
	_damage_after = Callable()
	_dying_after = Callable()
	_last_damage_context = null
	_draw_context = null
	response_required_count = 1
	response_received_count = 0
	_multi_response_origin = FlowState.IDLE


func current_player() -> BattlePlayer:
	return players[current_player_index]


func other_player(player: BattlePlayer) -> BattlePlayer:
	## 兼容旧技能/旧调用方的 1v1 语义；多人局中作为默认对手兜底：
	## AI 永远针对玩家，玩家针对第一个存活反贼。
	return _default_rival(player)


func two_player_action_order(starting_player: BattlePlayer) -> Array[BattlePlayer]:
	## 双人局的行动顺序固定从当前效果的起点开始，再轮到另一名角色。
	return [starting_player, other_player(starting_player)]


func player_index(player: BattlePlayer) -> int:
	return players.find(player)


func phase_text() -> String:
	match phase:
		Phase.START:
			return "开始阶段"
		Phase.JUDGEMENT:
			return "判定阶段"
		Phase.DRAW:
			return "摸牌阶段"
		Phase.PLAY:
			return "出牌阶段"
		Phase.DISCARD:
			return "弃牌阶段"
		Phase.END:
			return "结束阶段"
	return "未知阶段"


func prompt_text() -> String:
	if flow_state == FlowState.GENERAL_SELECTION:
		return "请选择主公武将；双方确定后点击“开始对局”"
	if flow_state == FlowState.GAME_OVER:
		return "%s 获胜！可以沿用武将重新开始，或返回选将。" % winner.player_name
	if flow_state == FlowState.SKILL_CONFIRM:
		return "%s：是否发动【%s】？" % [skill_actor.player_name, pending_skill.display_name]
	if flow_state == FlowState.SKILL_SELECT_CARDS:
		return "%s 发动【%s】：请选择代价牌（已选 %d）" % [
			skill_actor.player_name,
			pending_skill.display_name,
			pending_skill_cards.size(),
		]
	if flow_state == FlowState.SKILL_SELECT_TARGET:
		if pending_skill != null and pending_skill.id == &"lijian" and _lijian_first_target != null:
			return "【离间】：已选 %s 为【决斗】使用者，请选择【决斗】对象（男性角色）" % _lijian_first_target.player_name
		return "%s 发动【%s】：请选择合法目标" % [skill_actor.player_name, pending_skill.display_name]
	if flow_state == FlowState.SKILL_RESOLVING:
		return "正在结算技能……" if pending_skill == null else "正在结算【%s】……" % pending_skill.display_name
	if flow_state == FlowState.JUDGEMENT_REPLACE:
		return "%s：当前判定牌%s；点击一张手牌发动【鬼才】，或放弃改判。" % [skill_actor.player_name, judgement_context.effective_card.identity_text()]
	if flow_state == FlowState.SKILL_ASSIGN_CARDS:
		return "%s 正在分配【遗计】的私有牌；逐张指定主公或反贼后确认。" % private_card_owner.player_name
	if flow_state == FlowState.DECK_REORDER:
		return "%s 正在【观星】：按点击顺序选择置顶牌，未选牌按顺序置底。" % private_card_owner.player_name
	if flow_state == FlowState.CHOOSING_SUIT:
		return "%s 正在为【反间】选择花色；随机牌尚未公开。" % choice_owner.player_name
	if flow_state == FlowState.SELECTING_TARGET:
		if _pending_borrow_slash_target:
			return "【借刀杀人】：请选择指定出【杀】的目标角色"
		if not _pending_serpent_spear.is_empty():
			return "【丈八蛇矛】视为【杀】：点击或拖拽选择目标"
		return "已选择【%s】——点击或拖到合法角色区域" % _selected_card_name()
	if flow_state == FlowState.RESPONDING_SLASH:
		return "%s 正被【杀】指定：使用【闪】或不响应" % pending_target.player_name
	if flow_state == FlowState.MULTI_RESPONSE:
		return "%s 需连续打出%s：已响应 %d/%d" % [
			_current_response_player().player_name,
			"【闪】" if _response_card_type == Card.CardType.DODGE else "【杀】",
			response_received_count,
			response_required_count,
		]
	if flow_state == FlowState.NULLIFICATION_RESPONSE:
		return "%s：可使用【无懈可击】或放弃响应（当前链数 %d）" % [
			players[_nullification_responder_index].player_name,
			_nullification_count,
		]
	if flow_state == FlowState.CHOOSING_OPTION:
		return "%s：请选择一项" % choice_owner.player_name
	if flow_state == FlowState.CHOOSING_REVEALED:
		return "%s 从【五谷丰登】亮出的牌中选择一张" % _revealed_selecting_player.player_name
	if flow_state == FlowState.AOE_RESPONSE:
		return "%s 需打出%s，否则受到 1 点伤害" % [
			pending_target.player_name,
			"【杀】" if _response_card_type == Card.CardType.SLASH else "【闪】",
		]
	if flow_state == FlowState.DUEL_RESPONSE:
		return "【决斗】：%s 需打出【杀】，否则受到 1 点伤害" % _duel_responder.player_name
	if flow_state == FlowState.FIRE_REVEAL:
		return "%s 请选择一张手牌展示" % _fire_target.player_name
	if flow_state == FlowState.FIRE_DISCARD:
		return "%s 可弃置一张%s牌发动【火攻】，或放弃" % [
			_fire_source.player_name,
			_fire_revealed_card.suit_text(),
		]
	if flow_state == FlowState.SLASH_TRANSFER:
		return "%s 发动【流离】：请选择转移目标（必须在你攻击范围内且为该【杀】的合法目标）" % skill_actor.player_name
	if flow_state == FlowState.BORROW_RESPONSE:
		var borrow_prompt_target: BattlePlayer = _borrow_slash_target if _borrow_slash_target != null else _borrow_source
		return "%s：对 %s 使用【杀】，否则交出武器" % [
			_borrow_target.player_name,
			borrow_prompt_target.player_name,
		]
	if flow_state == FlowState.DYING_RESCUE:
		if rescue_actor == null:
			return "%s 濒死中，正在结算救援……" % dying_player.player_name
		var rescue_tips: String = "【桃】"
		if rescue_actor == dying_player:
			rescue_tips += "/【酒】"
		if rescue_actor.has_skill(&"jijiu") and rescue_actor != current_player():
			rescue_tips += "/【急救】"
		return "%s 濒死；当前救援操作者：%s（可使用%s或放弃）" % [
			dying_player.player_name,
			rescue_actor.player_name,
			rescue_tips,
		]
	if flow_state == FlowState.DISCARDING:
		var excess: int = current_player().hand.size() - hand_limit_for(current_player())
		if excess > 0:
			return "弃牌阶段：还需弃置 %d 张牌（点击手牌弃置）" % excess
	if flow_state == FlowState.PLAY_ACTIVE:
		return "反贼正在思考……" if current_player().is_ai else "你的出牌阶段：点击卡牌使用，或拖到角色区域"
	return "%s · %s" % [current_player().player_name, phase_text()]


func is_play_phase_for(user: Node) -> bool:
	return (
		user == current_player()
		and phase == Phase.PLAY
		and flow_state in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]
	)


func can_play_trick(card: Card, user: Node) -> bool:
	if not is_play_phase_for(user):
		return false
	var owner: BattlePlayer = user as BattlePlayer
	match card.card_type:
		Card.CardType.NULLIFICATION:
			return false
		Card.CardType.DISMANTLE:
			return _has_any_dismantle_target(owner)
		Card.CardType.STEAL:
			return _any_legal_trick_target(card, owner)
		Card.CardType.BORROW_SWORD:
			return _any_legal_trick_target(card, owner)
		Card.CardType.FIRE_ATTACK:
			return _any_legal_trick_target(card, owner) or not owner.hand.is_empty()
		Card.CardType.INDULGENCE, Card.CardType.SUPPLY_SHORTAGE:
			return _any_legal_trick_target(card, owner)
		Card.CardType.LIGHTNING:
			return not owner.has_delayed_trick(Card.CardType.LIGHTNING)
	return true


func can_equip(user: Node) -> bool:
	return is_play_phase_for(user)


func can_equip_weapon(user: Node) -> bool:
	## 兼容旧卡牌脚本调用；所有装备现在均走 can_equip。
	return can_equip(user)


func distance_between(source: BattlePlayer, target: BattlePlayer) -> int:
	if source == null or target == null or source == target:
		return 0
	var distance: int = 1
	if target.horse_plus != null:
		distance += 1
	if source.horse_minus != null:
		distance -= 1
	for owner: BattlePlayer in players:
		for skill: Skill in owner.skills:
			if skill.activation_mode == Skill.ActivationMode.MODIFIER:
				distance = skill.modify_distance(distance, source, target, self, owner)
	return maxi(distance, 1)


func attack_range(player: BattlePlayer) -> int:
	if player == null:
		return 1
	var result: int = int(player.weapon.attack_range) if player.weapon != null else 1
	for skill: Skill in player.skills:
		if skill.activation_mode == Skill.ActivationMode.MODIFIER:
			result = skill.modify_attack_range(result, self, player)
	return maxi(result, 1)


func slash_use_limit(player: BattlePlayer) -> int:
	var result: int = 999999 if (
		player.weapon != null and player.weapon.card_type == Card.CardType.CROSSBOW
	) else 1
	for skill: Skill in player.skills:
		if skill.activation_mode == Skill.ActivationMode.MODIFIER:
			result = skill.modify_slash_limit(result, self, player)
	return result


func can_slash_target(source: BattlePlayer, target: BattlePlayer) -> bool:
	return (
		source != null
		and target != null
		and source != target
		and distance_between(source, target) <= attack_range(source)
		and _skills_allow_target(source, target, Card.CardType.SLASH)
	)


func _skills_allow_target(source: BattlePlayer, target: BattlePlayer, effective_type: Card.CardType) -> bool:
	if target == null:
		return false
	for skill: Skill in target.skills:
		if skill.activation_mode == Skill.ActivationMode.MODIFIER and not skill.can_be_targeted_by(effective_type, source, self, target):
			return false
	return true


func _trick_distance_free(user: BattlePlayer, effective_type: Card.CardType) -> bool:
	if user == null:
		return false
	for skill: Skill in user.skills:
		if (
			skill.activation_mode == Skill.ActivationMode.MODIFIER
			and skill.ignores_trick_distance(effective_type, self, user)
		):
			return true
	return false


func can_use_slash_in_play(user: Node) -> bool:
	if not is_play_phase_for(user):
		return false
	var player: BattlePlayer = user as BattlePlayer
	if player.slash_used_this_turn and slash_use_limit(player) <= 1:
		return false
	for target: BattlePlayer in _potential_targets_for(player):
		if can_slash_target(player, target):
			return true
	return false


func hand_limit_for(player: BattlePlayer) -> int:
	var result: int = maxi(player.hp, 0)
	for skill: Skill in player.skills:
		if skill.activation_mode == Skill.ActivationMode.MODIFIER:
			result = skill.modify_hand_limit(result, self, player)
	return maxi(result, 0)


func can_use_skill(player: BattlePlayer, skill: Skill) -> bool:
	if player == null or skill == null or player.get_skill(skill.id) != skill:
		return false
	if not player.can_pay_skill_usage(skill):
		return false
	match skill.activation_mode:
		Skill.ActivationMode.ACTIVE:
			return skill.can_activate(self, player)
		Skill.ActivationMode.VIEW_AS:
			var effective: Card.CardType = _required_view_as_type(player, skill)
			if int(effective) < 0:
				return false
			if is_play_phase_for(player):
				if effective == Card.CardType.SLASH and not can_use_slash_in_play(player):
					return false
				if effective == Card.CardType.DISMANTLE and not _has_any_dismantle_target(player):
					return false
				if effective == Card.CardType.INDULGENCE and not _has_any_indulgence_target(player):
					return false
			return not _view_as_candidates(player, skill, effective).is_empty()
	return false


func can_use_serpent_spear(player: BattlePlayer) -> bool:
	if player == null or player.weapon == null or player.weapon.card_type != Card.CardType.SERPENT_SPEAR:
		return false
	if player.hand.size() < 2:
		return false
	if is_play_phase_for(player):
		return can_use_slash_in_play(player)
	return is_waiting_for_slash_from(player)


func can_use_bagua(player: BattlePlayer) -> bool:
	if player == null or player.armor == null or player.armor.card_type != Card.CardType.EIGHT_TRIGRAMS:
		return false
	if not is_waiting_for_dodge_from(player):
		return false
	if _bagua_attempted:
		return false
	if _slash_dodge_forbidden and player == pending_target:
		return false
	return not (
		flow_state in [FlowState.RESPONDING_SLASH, FlowState.MULTI_RESPONSE]
		and _slash_ignores_armor
		and player == pending_target
	)


func is_waiting_for_dodge_from(user: Node) -> bool:
	return (
		(flow_state == FlowState.RESPONDING_SLASH and user == pending_target)
		or (
			flow_state == FlowState.MULTI_RESPONSE
			and _multi_response_origin == FlowState.RESPONDING_SLASH
			and user == pending_target
			and _response_card_type == Card.CardType.DODGE
		)
		or (
			flow_state == FlowState.AOE_RESPONSE
			and user == pending_target
			and _response_card_type == Card.CardType.DODGE
		)
	)


func is_waiting_for_slash_from(user: Node) -> bool:
	return (
		(flow_state == FlowState.AOE_RESPONSE and user == pending_target and _response_card_type == Card.CardType.SLASH)
		or (flow_state == FlowState.DUEL_RESPONSE and user == _duel_responder)
		or (flow_state == FlowState.BORROW_RESPONSE and user == _borrow_target)
		or (
			flow_state == FlowState.MULTI_RESPONSE
			and _multi_response_origin == FlowState.DUEL_RESPONSE
			and user == _duel_responder
		)
	)


func is_waiting_for_nullification_from(user: Node) -> bool:
	return (
		flow_state == FlowState.NULLIFICATION_RESPONSE
		and user == players[_nullification_responder_index]
	)


func is_waiting_for_rescue_from(user: Node) -> bool:
	return flow_state == FlowState.DYING_RESCUE and user == rescue_actor


func request_card_use(hand_index: int) -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	if hand_index < 0 or hand_index >= player1.hand.size():
		return
	var card: Card = player1.hand[hand_index]

	match flow_state:
		FlowState.JUDGEMENT_REPLACE:
			request_judgement_replace(hand_index)
			return
		FlowState.SKILL_SELECT_CARDS:
			request_skill_toggle_hand_card(hand_index)
			return
		FlowState.DISCARDING:
			request_discard(hand_index)
			return
		FlowState.NULLIFICATION_RESPONSE:
			if card.card_type == Card.CardType.NULLIFICATION:
				request_nullification()
			return
		FlowState.MULTI_RESPONSE:
			if _multi_response_origin == FlowState.RESPONDING_SLASH and card.card_type == Card.CardType.DODGE:
				request_dodge()
			elif _multi_response_origin == FlowState.DUEL_RESPONSE and card.card_type == Card.CardType.SLASH:
				request_response_card()
			return
		FlowState.AOE_RESPONSE, FlowState.DUEL_RESPONSE, FlowState.BORROW_RESPONSE:
			if card.card_type == _response_card_type or (
				flow_state in [FlowState.DUEL_RESPONSE, FlowState.BORROW_RESPONSE]
				and card.card_type == Card.CardType.SLASH
			):
				request_response_card()
			return
		FlowState.RESPONDING_SLASH:
			if card.card_type == Card.CardType.DODGE:
				request_dodge()
			return
		FlowState.FIRE_REVEAL:
			request_fire_reveal(hand_index)
			return
		FlowState.FIRE_DISCARD:
			request_fire_discard(hand_index)
			return
		FlowState.DYING_RESCUE:
			if card.card_type in [Card.CardType.PEACH, Card.CardType.WINE]:
				request_rescue(card.card_type)
			return

	## 当前回合属于 AI 时，玩家仍可在上面的响应状态中点击手牌。
	## 只有主动出牌入口需要阻止玩家代替 AI 操作。
	if current_player().is_ai:
		return
	if phase != Phase.PLAY:
		_reject("当前不是出牌阶段。")
		return
	if flow_state == FlowState.SELECTING_TARGET:
		request_cancel_selection()
	if flow_state != FlowState.PLAY_ACTIVE:
		return
	_activate_play_card(player1, hand_index)


func request_card_on_target(hand_index: int, target_index: int) -> void:
	if flow_state == FlowState.SKILL_SELECT_TARGET:
		request_skill_target(target_index)
		return
	if _pending_borrow_slash_target:
		_resolve_borrow_slash_target(target_index)
		return
	if not _pending_serpent_spear.is_empty():
		_resolve_serpent_spear_target(target_index)
		return
	if flow_state == FlowState.GAME_OVER or current_player().is_ai:
		return
	if phase != Phase.PLAY or hand_index < 0 or hand_index >= player1.hand.size():
		return
	var card: Card = player1.hand[hand_index]
	if target_index < 0 or target_index >= players.size():
		return
	var target: BattlePlayer = players[target_index]
	if target.is_dying():
		_reject("该角色已经阵亡。")
		return
	if card.card_type == Card.CardType.SLASH:
		if target == player1:
			_reject("【杀】必须指定对方。")
			return
		_play_slash(player1, target, hand_index)
	elif card.category == Card.CardCategory.EQUIPMENT and target == player1:
		_play_equipment(player1, hand_index)
	elif card.is_trick():
		if card.target_mode == Card.TargetMode.SELF and target == player1:
			_use_self_or_global_trick(player1, hand_index)
		elif _is_valid_trick_target(card, player1, target):
			_use_target_trick(player1, target, hand_index)
		else:
			_reject("该角色不是【%s】的合法目标。" % card.display_name)
	else:
		request_card_use(hand_index)


func request_target(target_index: int) -> void:
	if flow_state == FlowState.SKILL_SELECT_TARGET:
		request_skill_target(target_index)
		return
	if _pending_borrow_slash_target:
		_resolve_borrow_slash_target(target_index)
		return
	if not _pending_serpent_spear.is_empty():
		_resolve_serpent_spear_target(target_index)
		return
	if flow_state != FlowState.SELECTING_TARGET:
		return
	if selected_hand_index < 0 or selected_hand_index >= current_player().hand.size():
		request_cancel_selection()
		return
	var card: Card = current_player().hand[selected_hand_index]
	if target_index < 0 or target_index >= players.size():
		request_cancel_selection()
		return
	var target: BattlePlayer = players[target_index]
	if target.is_dying():
		_reject("该角色已经阵亡。")
		return
	if card.card_type == Card.CardType.SLASH:
		if target == current_player():
			_reject("【杀】必须指定对方。")
			return
		_play_slash(current_player(), target, selected_hand_index)
	elif _is_valid_trick_target(card, current_player(), target):
		_use_target_trick(current_player(), target, selected_hand_index)
	else:
		_reject("该角色不是【%s】的合法目标。" % card.display_name)


func request_cancel_selection() -> void:
	if flow_state != FlowState.SELECTING_TARGET:
		return
	if _pending_borrow_slash_target:
		## 取消借刀杀人：指定流程中止，锦囊按未结算处理。
		_pending_borrow_slash_target = false
		_borrow_slash_target = null
		selected_hand_index = -1
		_finish_nullifiable_effect()
		return
	if not _pending_serpent_spear.is_empty():
		## 取消丈八蛇矛：代价牌已进入处理区，直接返回出牌阶段。
		_pending_serpent_spear.clear()
		selected_hand_index = -1
		_return_to_play()
		return
	selected_hand_index = -1
	flow_state = FlowState.PLAY_ACTIVE
	_emit_state()


func request_begin_skill(skill_id: StringName) -> void:
	if flow_state in [
		FlowState.GENERAL_SELECTION,
		FlowState.GAME_OVER,
		FlowState.SKILL_CONFIRM,
		FlowState.SKILL_SELECT_CARDS,
		FlowState.SKILL_SELECT_TARGET,
		FlowState.SKILL_RESOLVING,
		FlowState.JUDGEMENT_REPLACE,
		FlowState.DECK_REORDER,
		FlowState.SKILL_ASSIGN_CARDS,
		FlowState.CHOOSING_SUIT,
	]:
		return
	var actor: BattlePlayer
	if flow_state == FlowState.DYING_RESCUE:
		actor = rescue_actor
	else:
		actor = current_player() if is_play_phase_for(current_player()) else _current_response_player()
	if actor == null or actor.is_ai:
		return
	var skill: Skill = actor.get_skill(skill_id)
	if skill == null or not can_use_skill(actor, skill):
		_reject("当前不能发动【%s】。" % (skill.display_name if skill != null else "技能"))
		return
	_begin_active_or_view_as_skill(actor, skill)


func request_skill_toggle_hand_card(hand_index: int) -> void:
	if flow_state != FlowState.SKILL_SELECT_CARDS or skill_actor == null or skill_actor.is_ai:
		return
	if hand_index < 0 or hand_index >= skill_actor.hand.size():
		return
	var card: Card = skill_actor.hand[hand_index]
	if _ganglie_discard_active:
		if card in pending_skill_cards:
			pending_skill_cards.erase(card)
			_add_log("%s 取消选择%s作为【刚烈】弃牌。" % [skill_actor.player_name, card.identity_text()])
		elif pending_skill_cards.size() < 2:
			pending_skill_cards.append(card)
			_add_log("%s 选择%s作为【刚烈】弃牌（%d/2）。" % [
				skill_actor.player_name,
				card.identity_text(),
				pending_skill_cards.size(),
			])
		_emit_state()
		return
	if pending_skill.activation_mode == Skill.ActivationMode.ACTIVE:
		if not pending_skill.allows_hand_cost():
			return
		if card in pending_skill_cards:
			pending_skill_cards.erase(card)
			_add_log("%s 取消选择%s作为【%s】代价。" % [
				skill_actor.player_name,
				card.identity_text(),
				pending_skill.display_name,
			])
		else:
			pending_skill_cards.append(card)
			_add_log("%s 选择%s作为【%s】代价。" % [
				skill_actor.player_name,
				card.identity_text(),
				pending_skill.display_name,
			])
		_emit_state()
		return
	if pending_skill.id == &"liuli":
		if card not in pending_skill_cards:
			pending_skill_cards = [card]
			_add_log("%s 选择%s作为【流离】代价。" % [skill_actor.player_name, card.identity_text()])
		_finish_liuli_cost_selection()
		return
	if not pending_skill.can_view_as(card, _skill_effective_card_type, self, skill_actor):
		_reject("该牌不能通过【%s】转化为【%s】。" % [
			pending_skill.display_name,
			CardFactory.create_card(_skill_effective_card_type).display_name,
		])
		return
	pending_skill_cards = [card]
	_finish_view_as_cost_selection()


func request_skill_select_equipment(slot: int) -> void:
	if flow_state != FlowState.SKILL_SELECT_CARDS or skill_actor == null or skill_actor.is_ai:
		return
	var card: Card = skill_actor.equipment_in_slot(slot)
	if card == null:
		return
	if pending_skill.activation_mode == Skill.ActivationMode.ACTIVE:
		if not pending_skill.allows_equipment_cost():
			_reject("该技能不能选择装备牌作为代价。")
			return
		if card in pending_skill_cards:
			pending_skill_cards.erase(card)
		else:
			pending_skill_cards.append(card)
		_emit_state()
		return
	if pending_skill.id == &"liuli":
		pending_skill_cards = [card]
		_add_log("%s 选择装备%s作为【流离】代价。" % [skill_actor.player_name, card.identity_text()])
		_finish_liuli_cost_selection()
		return
	if not pending_skill.allows_view_as_equipment() or not pending_skill.can_view_as(card, _skill_effective_card_type, self, skill_actor):
		_reject("该装备不能作为【%s】的代价。" % pending_skill.display_name)
		return
	pending_skill_cards = [card]
	_finish_view_as_cost_selection()


func request_confirm_skill_cards() -> void:
	if _ganglie_discard_active:
		if pending_skill_cards.size() != 2:
			_reject("请选择两张手牌弃置。")
			return
		_confirm_ganglie_discard()
		return
	if (
		flow_state != FlowState.SKILL_SELECT_CARDS
		or skill_actor == null
		or skill_actor.is_ai
		or pending_skill == null
		or pending_skill.activation_mode != Skill.ActivationMode.ACTIVE
	):
		return
	if not pending_skill.validate_cost(pending_skill_cards, self, skill_actor):
		_reject("【%s】代价不合法。" % pending_skill.display_name)
		return
	if pending_skill.requires_target():
		flow_state = FlowState.SKILL_SELECT_TARGET
		_emit_state()
		return
	_resolve_active_skill()


func request_skill_target(target_index: int) -> void:
	if (
		flow_state != FlowState.SKILL_SELECT_TARGET
		or skill_actor == null
		or skill_actor.is_ai
		or target_index < 0
		or target_index >= players.size()
	):
		return
	var target: BattlePlayer = players[target_index]
	if target.is_dying():
		_reject("该角色已经阵亡。")
		return
	if target == skill_actor and not pending_skill.allows_self_target():
		_reject("该技能必须指定其他角色。")
		return
	if pending_skill != null and pending_skill.id == &"lijian":
		_resolve_lijian_target(target)
		return
	if pending_skill.activation_mode == Skill.ActivationMode.ACTIVE:
		if not pending_skill.validate_target(target, pending_skill_cards, self, skill_actor):
			_reject("该目标不满足【%s】的条件。" % pending_skill.display_name)
			return
		pending_skill_targets = [target]
		_resolve_active_skill()
		return
	if pending_skill.id == &"liuli":
		if target not in liuli_transfer_candidates(skill_actor, _liuli_slash_context):
			_reject("该角色不是【流离】的合法转移目标。")
			return
		pending_skill_targets = [target]
		_resolve_liuli_transfer(target)
		return
	if _skill_effective_card_type == Card.CardType.SLASH:
		if not can_slash_target(skill_actor, target):
			_reject("目标超出【杀】的攻击范围。")
			return
		pending_skill_targets = [target]
		_use_selected_view_as_card(target)
	elif _skill_effective_card_type == Card.CardType.DISMANTLE:
		var virtual_dismantle: Card = CardFactory.create_card(Card.CardType.DISMANTLE)
		if not _is_valid_trick_target(virtual_dismantle, skill_actor, target):
			_reject("目标没有可被弃置的牌。")
			return
		pending_skill_targets = [target]
		_use_selected_view_as_card(target)
	elif _skill_effective_card_type == Card.CardType.INDULGENCE:
		var virtual_indulgence: Card = CardFactory.create_card(Card.CardType.INDULGENCE)
		if not _is_valid_trick_target(virtual_indulgence, skill_actor, target):
			_reject("该角色不能成为【乐不思蜀】的目标或已有同名延时锦囊。")
			return
		pending_skill_targets = [target]
		_use_selected_view_as_card(target)


func request_cancel_skill() -> void:
	if (
		flow_state not in [FlowState.SKILL_SELECT_CARDS, FlowState.SKILL_SELECT_TARGET]
		or skill_actor == null
		or skill_actor.is_ai
	):
		return
	if _ganglie_discard_active:
		_add_log("%s 取消【刚烈】弃牌，未弃置任何牌。" % skill_actor.player_name)
		_reopen_ganglie_choice()
		return
	var return_state: FlowState = _skill_return_state
	_add_log("%s 取消发动【%s】，未支付任何代价。" % [skill_actor.player_name, pending_skill.display_name])
	if pending_skill != null and pending_skill.id == &"liuli":
		var liuli_continue: Callable = _liuli_continue
		_clear_skill_context()
		_liuli_slash_context = null
		_liuli_continue = Callable()
		_call_safe(liuli_continue)
		return
	_clear_skill_context()
	flow_state = return_state
	_emit_state()


func request_confirm_skill() -> void:
	if flow_state != FlowState.SKILL_CONFIRM or skill_actor == null or skill_actor.is_ai:
		return
	_resolve_pending_trigger(true)


func request_decline_skill() -> void:
	if flow_state != FlowState.SKILL_CONFIRM or skill_actor == null or skill_actor.is_ai:
		return
	_resolve_pending_trigger(false)


func _begin_active_or_view_as_skill(actor: BattlePlayer, skill: Skill) -> void:
	skill_owner = actor
	skill_actor = actor
	pending_skill = skill
	pending_skill_cards.clear()
	pending_skill_targets.clear()
	_skill_return_state = flow_state
	if skill.activation_mode == Skill.ActivationMode.ACTIVE:
		if not skill.requires_card_cost():
			if skill.requires_target():
				flow_state = FlowState.SKILL_SELECT_TARGET
				_emit_state()
				return
			_resolve_active_skill()
			return
		flow_state = FlowState.SKILL_SELECT_CARDS
		_add_log("%s 准备发动主动技【%s】，请选择代价牌。" % [actor.player_name, skill.display_name])
		_emit_state()
		return
	var effective_value: int = _required_view_as_type(actor, skill)
	if effective_value < 0:
		_clear_skill_context()
		return
	_skill_effective_card_type = effective_value
	flow_state = FlowState.SKILL_SELECT_CARDS
	_add_log("%s 准备发动视为技【%s】，请选择实体牌代价。" % [actor.player_name, skill.display_name])
	_emit_state()


func _required_view_as_type(player: BattlePlayer, skill: Skill) -> int:
	if skill == null or skill.activation_mode != Skill.ActivationMode.VIEW_AS:
		return -1
	if is_play_phase_for(player):
		if skill.id == &"qixi":
			return Card.CardType.DISMANTLE
		if skill.id == &"guose":
			return Card.CardType.INDULGENCE
		return Card.CardType.SLASH
	if flow_state == FlowState.DYING_RESCUE and player == rescue_actor and _can_use_jijiu(player):
		return Card.CardType.PEACH
	if is_waiting_for_dodge_from(player):
		if _slash_dodge_forbidden and player == pending_target:
			return -1
		return Card.CardType.DODGE
	if is_waiting_for_slash_from(player):
		return Card.CardType.SLASH
	return -1


func _view_as_candidates(
	player: BattlePlayer,
	skill: Skill,
	effective_type: Card.CardType
) -> Array[Card]:
	var result: Array[Card] = []
	for card: Card in player.hand:
		if skill.can_view_as(card, effective_type, self, player):
			result.append(card)
	if skill.allows_view_as_equipment():
		for card: Card in player.all_equipment():
			if skill.can_view_as(card, effective_type, self, player):
				result.append(card)
	return result


func _finish_view_as_cost_selection() -> void:
	if pending_skill_cards.size() != 1:
		return
	if _skill_return_state in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]:
		flow_state = FlowState.SKILL_SELECT_TARGET
		_emit_state()
		return
	_use_selected_view_as_card(null)


func _use_selected_view_as_card(target: BattlePlayer) -> void:
	if pending_skill_cards.size() != 1 or skill_actor == null or pending_skill == null:
		return
	var actor: BattlePlayer = skill_actor
	var skill: Skill = pending_skill
	var physical: Card = pending_skill_cards[0]
	var effective: Card.CardType = _skill_effective_card_type
	var return_state: FlowState = _skill_return_state
	_move_cards(
		actor,
		actor,
		[physical],
		CardZone.PROCESSING,
		"作为【%s】代价" % skill.display_name,
		null,
		skill,
		null,
		Callable(self, "_use_view_as_card_after_cost").bind(actor, skill, physical, effective, return_state, target)
	)


func _use_view_as_card_after_cost(
	actor: BattlePlayer,
	skill: Skill,
	paid: Card,
	effective: Card.CardType,
	return_state: FlowState,
	target: BattlePlayer
) -> void:
	if paid == null:
		_reject("技能代价已不再合法。")
		flow_state = return_state
		_clear_skill_context()
		return
	actor.record_skill_use(skill)
	_add_log("%s 发动【%s】，将%s当【%s】%s。" % [
		actor.player_name,
		skill.display_name,
		paid.identity_text(),
		CardFactory.create_card(effective).display_name,
		"使用" if return_state in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET] else "打出",
	])
	_clear_skill_context()
	flow_state = return_state
	if return_state in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]:
		var use_context := SkillUseContext.new(
			actor,
			[paid],
			effective,
			skill,
			target,
			true,
			"技能【%s】" % skill.display_name
		)
		if effective == Card.CardType.SLASH:
			_use_virtual_slash(use_context, target)
		elif effective == Card.CardType.DISMANTLE:
			_use_virtual_dismantle(use_context, target)
		elif effective == Card.CardType.INDULGENCE:
			## 真实代价牌成为延时锦囊实体牌，但按【乐不思蜀】的规则类型进入判定区与判定流程。
			paid.effective_card_type = int(Card.CardType.INDULGENCE)
			_active_use_context = use_context
			_start_delayed_placement(paid, actor, target)
	elif return_state == FlowState.DYING_RESCUE and effective == Card.CardType.PEACH:
		_apply_rescue_recovery(actor, "【急救】视为【桃】")
	else:
		var response_origin: FlowState = (
			_multi_response_origin
			if return_state == FlowState.MULTI_RESPONSE
			else return_state
		)
		var response_context := SkillUseContext.new(
			actor,
			[paid],
			effective,
			skill,
			_response_opponent(actor),
			true,
			"技能响应"
		)
		_accept_effective_response(response_context, response_origin)


func _use_virtual_slash(context: SkillUseContext, target: BattlePlayer) -> void:
	var actor: BattlePlayer = context.user
	if not can_use_slash_in_play(actor) or target == null or not can_slash_target(actor, target):
		_add_log("【%s】形成的【杀】目标已不合法，实体牌进入弃牌堆。" % context.source_skill.display_name)
		_settle_processing_cards()
		_return_to_play()
		return
	_record_slash_use(actor)
	var amount: int = 2 if actor.wine_active else 1
	actor.wine_active = false
	var nature: DamageNature = DamageNature.FIRE if _has_equipment(actor, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
	_attack_use_context = context
	_add_log("%s 对 %s 使用由【%s】转化的【杀】（距离 %d / 范围 %d）。" % [
		actor.player_name,
		target.player_name,
		context.source_skill.display_name,
		distance_between(actor, target),
		attack_range(actor),
	])
	_start_slash_response(actor, target, amount, Callable(self, "_return_to_play"), nature, context)


func _use_virtual_dismantle(context: SkillUseContext, target: BattlePlayer) -> void:
	var virtual_card: Card = CardFactory.create_card(Card.CardType.DISMANTLE)
	_active_use_context = context
	_start_nullifiable_effect(
		virtual_card,
		context.user,
		target,
		Callable(self, "_apply_dismantle"),
		Callable(self, "_finish_nullifiable_effect"),
		Callable(self, "_return_to_play"),
		true
	)


func _resolve_active_skill() -> void:
	var actor: BattlePlayer = skill_actor
	var skill: Skill = pending_skill
	var cards: Array[Card] = pending_skill_cards.duplicate()
	if actor == null or skill == null or not skill.validate_cost(cards, self, actor):
		return
	flow_state = FlowState.SKILL_RESOLVING
	var preview_context := SkillUseContext.new(actor, cards, Card.CardType.SLASH, skill, null, true, "主动技能预览")
	var preview_request: Dictionary = skill.build_resolution_request(preview_context, self, actor)
	var preview_action: StringName = preview_request.get("action", &"")
	if preview_action == &"rende":
		_resolve_rende(actor, skill, cards)
		return
	if preview_action == &"kurou":
		actor.record_skill_use(skill)
		_add_log("%s 发动【苦肉】，失去1点体力。" % actor.player_name)
		_clear_skill_context()
		lose_hp(actor, 1, Callable(self, "_finish_kurou").bind(actor))
		return
	if preview_action == &"fanjian":
		var fanjian_target: BattlePlayer = pending_skill_targets[0] if not pending_skill_targets.is_empty() else null
		actor.record_skill_use(skill)
		_clear_skill_context()
		_begin_fanjian(actor, fanjian_target)
		return
	if preview_action == &"jieyin":
		_resolve_jieyin(actor, skill, cards)
		return
	if preview_action == &"qingnang":
		_resolve_qingnang(actor, skill, cards)
		return
	if preview_action == &"lijian":
		## 多人局：两步选择两名男性角色（发起者、决斗对象）后结算。
		if pending_skill_targets.size() >= 2:
			_resolve_lijian(actor, skill, cards, pending_skill_targets[0], pending_skill_targets[1])
		else:
			_add_log("【离间】需要选择两名男性角色。")
			_clear_skill_context()
			_return_to_play()
		return
	_move_cards(
		actor,
		actor,
		cards,
		CardZone.DISCARD,
		"作为【%s】代价被弃置" % skill.display_name,
		null,
		skill,
		null,
		Callable(self, "_apply_paid_active_skill").bind(actor, skill, cards)
	)


func _apply_paid_active_skill(actor: BattlePlayer, skill: Skill, paid: Array[Card]) -> void:
	if paid.is_empty():
		_add_log("【%s】代价支付失败。" % skill.display_name)
		_clear_skill_context()
		_return_to_play()
		return
	var use_context := SkillUseContext.new(actor, paid, Card.CardType.SLASH, skill, null, true, "主动技")
	var request: Dictionary = skill.build_resolution_request(use_context, self, actor)
	actor.record_skill_use(skill)
	_add_log("%s 发动【%s】，弃置%s。" % [actor.player_name, skill.display_name, _card_list_text(paid)])
	_clear_skill_context()
	_apply_skill_resolution(request, use_context, actor, skill, Callable(self, "_return_to_play"))


func _resolve_jieyin(actor: BattlePlayer, skill: Skill, cards: Array[Card]) -> void:
	var target: BattlePlayer = pending_skill_targets[0] if not pending_skill_targets.is_empty() else null
	if target == null or not skill.validate_target(target, cards, self, actor):
		_add_log("【结姻】目标已不再合法。")
		_clear_skill_context()
		_return_to_play()
		return
	_move_cards(
		actor,
		actor,
		cards,
		CardZone.DISCARD,
		"作为【结姻】代价",
		null,
		skill,
		null,
		Callable(self, "_apply_jieyin").bind(actor, skill, target, cards)
	)


func _apply_jieyin(actor: BattlePlayer, skill: Skill, target: BattlePlayer, paid: Array[Card]) -> void:
	actor.record_skill_use(skill)
	_add_log("%s 发动【结姻】，弃置%s；与 %s 各回复1点体力。" % [
		actor.player_name,
		_card_list_text(paid),
		target.player_name,
	])
	_clear_skill_context()
	recover_hp(actor, 1, "【结姻】")
	recover_hp(target, 1, "【结姻】")
	_return_to_play()


func _resolve_qingnang(actor: BattlePlayer, skill: Skill, cards: Array[Card]) -> void:
	var target: BattlePlayer = pending_skill_targets[0] if not pending_skill_targets.is_empty() else null
	if target == null or not skill.validate_target(target, cards, self, actor):
		_add_log("【青囊】目标已不再合法。")
		_clear_skill_context()
		_return_to_play()
		return
	_move_cards(
		actor,
		actor,
		cards,
		CardZone.DISCARD,
		"作为【青囊】代价",
		null,
		skill,
		null,
		Callable(self, "_apply_qingnang").bind(actor, skill, target, cards)
	)


func _apply_qingnang(actor: BattlePlayer, skill: Skill, target: BattlePlayer, paid: Array[Card]) -> void:
	actor.record_skill_use(skill)
	_add_log("%s 发动【青囊】，弃置%s，令 %s 回复1点体力。" % [
		actor.player_name,
		_card_list_text(paid),
		target.player_name,
	])
	_clear_skill_context()
	recover_hp(target, 1, "【青囊】")
	_return_to_play()


func _offer_triggered_skill(
	owner: BattlePlayer,
	skill: Skill,
	event_context: RefCounted,
	continuation: Callable
) -> void:
	skill_owner = owner
	skill_actor = owner
	pending_skill = skill
	_skill_event_context = event_context
	_skill_confirm_continue = continuation
	_skill_cancel_continue = continuation
	if skill.has_tag(Skill.SkillTag.LOCKED):
		var locked_previous_state: FlowState = flow_state
		_resolve_pending_trigger(true)
		if flow_state == FlowState.SKILL_RESOLVING:
			flow_state = locked_previous_state
		return
	flow_state = FlowState.SKILL_CONFIRM
	_add_log("%s 可以发动触发技【%s】。" % [owner.player_name, skill.display_name])
	_emit_state()
	if owner.is_ai:
		_schedule("_perform_ai_skill_confirm", 0.35)


func _perform_ai_skill_confirm() -> void:
	if flow_state != FlowState.SKILL_CONFIRM or skill_actor == null or not skill_actor.is_ai:
		return
	_resolve_pending_trigger(pending_skill.should_ai_activate(_skill_event_context, self, skill_owner))


func _resolve_pending_trigger(activate: bool) -> void:
	if pending_skill == null or skill_owner == null:
		return
	var skill: Skill = pending_skill
	var owner: BattlePlayer = skill_owner
	var event_context: RefCounted = _skill_event_context
	var continuation: Callable = _skill_confirm_continue if activate else _skill_cancel_continue
	flow_state = FlowState.SKILL_RESOLVING
	if activate:
		owner.record_skill_use(skill)
		_add_log("%s 发动【%s】。" % [owner.player_name, skill.display_name])
		var request: Dictionary = skill.build_resolution_request(event_context, self, owner)
		_clear_skill_context()
		_apply_skill_resolution(request, event_context, owner, skill, continuation)
		return
	else:
		_add_log("%s 放弃发动【%s】。" % [owner.player_name, skill.display_name])
	_clear_skill_context()
	_call_safe(continuation)


func _apply_skill_resolution(
	request: Dictionary,
	event_context: RefCounted,
	owner: BattlePlayer,
	skill: Skill,
	continuation: Callable = Callable()
) -> void:
	var action: StringName = request.get("action", &"")
	var asynchronous: bool = false
	match action:
		&"gain_processing_card":
			var gain_cards: Array = request.get("cards", [])
			if gain_cards.is_empty():
				var single_card: Card = request.get("card")
				if single_card != null:
					gain_cards = [single_card]
			for gained_card: Card in gain_cards:
				if _claim_processing_card(owner, gained_card):
					_add_log("%s 通过【%s】获得了造成伤害的%s。" % [
						owner.player_name,
						skill.display_name,
						gained_card.identity_text(),
					])
		&"replace_draw_with_steal":
			var draw := event_context as DrawContext
			var target: BattlePlayer = _steal_target_for(owner)
			if draw != null and not target.hand.is_empty():
				draw.draw_replaced = true
				draw.final_count = 0
				draw.replacement_skill = skill
				var index: int = randi_range(0, target.hand.size() - 1)
				var stolen: Card = target.remove_card_at(index)
				owner.add_card(stolen)
				_add_log("%s 发动【突袭】，放弃摸牌并随机获得 %s 的一张手牌。" % [
					owner.player_name,
					target.player_name,
				])
		&"activate_luoyi":
			var draw := event_context as DrawContext
			if draw != null:
				draw.final_count = maxi(draw.final_count - 1, 0)
				owner.luoyi_active = true
				_add_log("%s 发动【裸衣】，本次少摸一张；本回合【杀】和【决斗】伤害+1。" % owner.player_name)
		&"discard_and_draw":
			var count: int = int(request.get("count", 0))
			draw_cards(owner, count)
			_add_log("%s 因【%s】摸 %d 张牌。" % [owner.player_name, skill.display_name, count])
		&"yingzi":
			var draw := event_context as DrawContext
			if draw != null:
				draw.final_count += 1
				_add_log("【英姿】令 %s 本次摸牌数+1，最终摸%d张。" % [owner.player_name, draw.final_count])
		&"tiandu":
			var judgement := event_context as JudgementContextScript
			if judgement != null and judgement.effective_card != null and not judgement.is_claimed():
				judgement.claim(owner)
				_add_log("%s 通过【天妒】获得最终判定牌%s。" % [owner.player_name, judgement.effective_card.identity_text()])
		&"fankui":
			asynchronous = true
			_begin_fankui(owner, event_context as DamageContext, continuation)
		&"ganglie":
			asynchronous = true
			_begin_ganglie(owner, event_context as DamageContext, continuation)
		&"yiji":
			asynchronous = true
			_begin_yiji(owner, continuation)
		&"luoshen":
			asynchronous = true
			_begin_luoshen(owner, continuation)
		&"guanxing":
			asynchronous = true
			_begin_guanxing(owner, continuation)
		&"keji":
			owner.skip_discard_this_turn = true
			_add_log("%s 发动【克己】，跳过本回合弃牌阶段。" % owner.player_name)
		&"jizhi_draw":
			draw_cards(owner, 1)
			_add_log("%s 发动【集智】，摸一张牌。" % owner.player_name)
		&"lianying_draw":
			draw_cards(owner, 1)
			_add_log("%s 发动【连营】，摸一张牌。" % owner.player_name)
		&"xiaoji_draw":
			draw_cards(owner, 2)
			_add_log("%s 发动【枭姬】，摸两张牌。" % owner.player_name)
		&"biyue_draw":
			draw_cards(owner, 1)
			_add_log("%s 发动【闭月】，摸一张牌。" % owner.player_name)
		&"silver_lion_recover":
			recover_hp(owner, 1, "【白银狮子】离开装备区")
		&"tieqi":
			asynchronous = true
			_begin_tieqi(event_context as SlashTargetContextScript, owner, continuation)
		&"liuli":
			asynchronous = true
			_begin_liuli(event_context as SlashTargetContextScript, owner, continuation)
	if not asynchronous:
		_call_safe(continuation)


func _find_triggered_skill(
	owner: BattlePlayer,
	timing: StringName,
	event_context: RefCounted
) -> Skill:
	for skill: Skill in owner.skills:
		if (
			skill.activation_mode == Skill.ActivationMode.TRIGGERED
			and skill.trigger_timing() == timing
			and owner.can_pay_skill_usage(skill)
			and skill.can_trigger(event_context, self, owner)
		):
			return skill
	return null


func _resolve_rende(actor: BattlePlayer, skill: Skill, cards: Array[Card]) -> void:
	## 多人局：玩家可任选一名其他存活角色作为接收者（AI 交给玩家）。
	var target: BattlePlayer = pending_skill_targets[0] if not pending_skill_targets.is_empty() else other_player(actor)
	if target == null or target.is_dying() or target == actor:
		_add_log("【仁德】目标已不再合法。")
		_clear_skill_context()
		_return_to_play()
		return
	_move_cards(
		actor, actor, cards, CardZone.HAND, "通过【仁德】交给",
		null, skill, target,
		Callable(self, "_apply_rende").bind(actor, skill, target, cards)
	)


func _apply_rende(actor: BattlePlayer, skill: Skill, target: BattlePlayer, moved: Array[Card]) -> void:
	if moved.is_empty():
		_add_log("【仁德】确认时已无合法手牌，未移动任何牌。")
		_clear_skill_context()
		_return_to_play()
		return
	actor.record_skill_use(skill)
	actor.rende_given_this_phase += moved.size()
	_add_log("%s 发动【仁德】，将%d张手牌交给%s；本阶段累计%d张。" % [actor.player_name, moved.size(), target.player_name, actor.rende_given_this_phase])
	if actor.rende_given_this_phase >= 2 and not actor.rende_recovery_consumed:
		actor.rende_recovery_consumed = true
		var before: int = actor.hp
		actor.recover(1)
		_add_log("【仁德】首次累计达到2张，回复机会已消耗；体力%d→%d。" % [before, actor.hp])
	_clear_skill_context()
	_return_to_play()


func _finish_kurou(actor: BattlePlayer) -> void:
	if flow_state == FlowState.GAME_OVER or actor.hp <= 0:
		return
	draw_cards(actor, 2)
	_add_log("%s 完成【苦肉】结算，摸两张牌。" % actor.player_name)
	_return_to_play()


func lose_hp(player: BattlePlayer, amount: int, continuation: Callable = Callable()) -> void:
	if player == null or amount <= 0 or flow_state == FlowState.GAME_OVER:
		_call_safe(continuation)
		return
	player.lose_hp(amount)
	_add_log("%s 失去%d点体力，当前体力%d/%d；此过程不属于伤害。" % [player.player_name, amount, player.hp, player.max_hp])
	_emit_state()
	if player.is_dying():
		_enter_dying(player, continuation)
	else:
		_call_safe(continuation)


func _begin_fankui(owner: BattlePlayer, context: DamageContext, continuation: Callable) -> void:
	if context == null or context.source == null or not context.source.has_any_card_in_play_area():
		_add_log("【反馈】结算时伤害来源已无牌，安全跳过。")
		_call_safe(continuation)
		return
	var source: BattlePlayer = context.source
	var codes: Array[String] = []
	var labels: Array[String] = []
	if not source.hand.is_empty():
		codes.append("hand")
		labels.append("暗置手牌区（随机）")
	for entry: Dictionary in _equipment_choice_entries(source):
		codes.append("equip:%s" % entry.code)
		labels.append("%s：%s" % [entry.slot_name, (entry.card as Card).identity_text()])
	for delayed: Card in source.delayed_tricks_in_judgement_order():
		codes.append("delayed:%d" % int(delayed.card_type))
		labels.append("判定区：%s" % delayed.identity_text())
	if codes.is_empty():
		_call_safe(continuation)
		return
	if owner.is_ai:
		_resolve_fankui_choice(0, owner, source, codes, continuation)
		return
	choice_owner = owner
	choice_labels = labels
	_zone_choice_codes = codes
	_choice_handler = Callable(self, "_resolve_fankui_choice").bind(owner, source, codes, continuation)
	flow_state = FlowState.CHOOSING_OPTION
	_add_log("%s 发动【反馈】，请选择伤害来源的一张牌。" % owner.player_name)
	_emit_state()


func _resolve_fankui_choice(index: int, owner: BattlePlayer, source: BattlePlayer, codes: Array[String], continuation: Callable) -> void:
	if index < 0 or index >= codes.size() or not source.has_any_card_in_play_area():
		_call_safe(continuation)
		return
	var code: String = codes[index]
	var gained: Card = null
	var gained_zone: int = -1
	if code == "hand" and not source.hand.is_empty():
		var random_index: int = randi_range(0, source.hand.size() - 1)
		gained = source.hand[random_index]
		gained_zone = CardZone.HAND
	elif code.begins_with("equip:"):
		var slot: int = _slot_from_code(code.trim_prefix("equip:"))
		gained = source.equipment_in_slot(slot)
		gained_zone = _slot_to_zone(slot)
	elif code.begins_with("delayed:"):
		var delayed_type: Card.CardType = int(code.trim_prefix("delayed:"))
		if source.indulgence_card != null and source.indulgence_card.card_type == delayed_type:
			gained = source.indulgence_card
		elif source.supply_shortage_card != null and source.supply_shortage_card.card_type == delayed_type:
			gained = source.supply_shortage_card
		elif source.lightning_card != null and source.lightning_card.card_type == delayed_type:
			gained = source.lightning_card
		gained_zone = CardZone.DELAYED_TRICK
	if gained == null or gained_zone < 0:
		_add_log("【反馈】所选牌已离开原区域，未复制牌。")
		_call_safe(continuation)
		return
	_add_log("%s 通过【反馈】从%s获得一张%s。" % [owner.player_name, source.player_name, "暗置手牌" if code == "hand" else gained.identity_text()])
	_move_cards(
		source, owner, [gained], CardZone.HAND,
		"被【反馈】获得", null, owner.get_skill(&"fankui"), owner,
		continuation
	)


func _begin_ganglie(owner: BattlePlayer, context: DamageContext, continuation: Callable) -> void:
	if context == null or context.source == null or context.source.hp <= 0:
		_call_safe(continuation)
		return
	_start_judgement(&"ganglie", owner, Callable(self, "_evaluate_ganglie"), Callable(self, "_after_ganglie").bind(owner, context.source, continuation))


func _evaluate_ganglie(context: JudgementContextScript) -> void:
	context.result_data["punish"] = context.effective_card.suit != Card.Suit.HEART
	_add_log("【刚烈】最终判定为%s：%s。" % [context.effective_card.identity_text(), "非红桃，伤害来源须受惩罚" if bool(context.result_data.get("punish", false)) else "红桃，无后续效果"])


func _after_ganglie(context: JudgementContextScript, owner: BattlePlayer, source: BattlePlayer, continuation: Callable) -> void:
	if not bool(context.result_data.get("punish", false)) or source == null or source.hp <= 0:
		_call_safe(continuation)
		return
	if source.is_ai:
		_resolve_ganglie_choice(0 if _ai_ganglie_discard_choice(source) else 1, owner, source, continuation)
		return
	choice_owner = source
	choice_labels.clear()
	if source.hand.size() >= 2:
		choice_labels.append("弃置两张手牌")
	choice_labels.append("受到1点普通伤害")
	_choice_handler = Callable(self, "_resolve_ganglie_human_choice").bind(owner, source, continuation)
	flow_state = FlowState.CHOOSING_OPTION
	_add_log("【刚烈】：%s 请选择弃置两张手牌或受到1点伤害。" % source.player_name)
	_emit_state()


## AI 对【刚烈】的选择：返回 true 表示弃两张手牌，false 表示受到 1 点伤害。
func _ai_ganglie_discard_choice(source: BattlePlayer) -> bool:
	if source == null or source.hand.size() < 2:
		return false
	## 受伤后是否必死（桃不足以自救）：必死则只能弃牌。
	var hp_after: int = source.hp - 1
	if hp_after < 1:
		var needed_peaches: int = 1 - hp_after
		if source.count_card(Card.CardType.PEACH) < needed_peaches:
			return true
	## 弃牌会失去【桃】【无懈可击】等关键牌时，选择受伤保留（若会濒死，靠手中桃自救）。
	if _ganglie_discard_would_lose_key(source):
		return false
	## 其余情况优先弃两张低价值手牌保体力。
	return true


## 判断 AI 弃两张手牌是否必然失去桃/无懈等关键牌（AI 弃价值最低的两张）。
func _ganglie_discard_would_lose_key(source: BattlePlayer) -> bool:
	if source == null:
		return false
	var sorted: Array[Card] = source.hand.duplicate()
	sorted.sort_custom(func(a: Card, b: Card) -> bool:
		return _ai_card_value(a) < _ai_card_value(b)
	)
	var check_count: int = mini(sorted.size(), 2)
	for index: int in check_count:
		var card: Card = sorted[index]
		if card.card_type in [Card.CardType.PEACH, Card.CardType.NULLIFICATION]:
			return true
	return false


func _resolve_ganglie_human_choice(index: int, owner: BattlePlayer, source: BattlePlayer, continuation: Callable) -> void:
	if index == 0 and source.hand.size() >= 2:
		_begin_ganglie_discard(owner, source, continuation)
		return
	_resolve_ganglie_choice(1, owner, source, continuation)


func _resolve_ganglie_choice(choice: int, owner: BattlePlayer, source: BattlePlayer, continuation: Callable) -> void:
	if choice == 0 and source.hand.size() >= 2:
		## AI 弃价值最低的两张手牌，保留桃/无懈等关键牌。
		var sorted: Array[Card] = source.hand.duplicate()
		sorted.sort_custom(func(a: Card, b: Card) -> bool:
			return _ai_card_value(a) < _ai_card_value(b)
		)
		var discarded: Array[Card] = [sorted[0], sorted[1]]
		_move_cards(
			source, owner, discarded, CardZone.DISCARD,
			"因【刚烈】弃置", null, owner.get_skill(&"ganglie"), null,
			Callable(self, "_finish_ganglie_discard").bind(source, discarded, continuation)
		)
		return
	var remaining: Array[DamageContext] = _damage_queue.duplicate()
	var outer_after: Callable = _damage_after
	_start_damage(owner, source, 1, DamageNature.NORMAL, Callable(self, "_finish_nested_ganglie_damage").bind(remaining, outer_after, continuation), null, null, "【刚烈】")


func _begin_ganglie_discard(owner: BattlePlayer, source: BattlePlayer, continuation: Callable) -> void:
	skill_owner = owner
	skill_actor = source
	pending_skill = owner.get_skill(&"ganglie")
	pending_skill_cards.clear()
	pending_skill_targets.clear()
	_ganglie_discard_active = true
	_ganglie_discard_continue = continuation
	_ganglie_discard_owner = owner
	_ganglie_discard_source = source
	_skill_return_state = FlowState.CHOOSING_OPTION
	flow_state = FlowState.SKILL_SELECT_CARDS
	_add_log("【刚烈】：%s 请选择两张手牌弃置（点击手牌，选满两张后确认）。" % source.player_name)
	_emit_state()


func _confirm_ganglie_discard() -> void:
	var source: BattlePlayer = skill_actor
	var owner: BattlePlayer = _ganglie_discard_owner
	var continuation: Callable = _ganglie_discard_continue
	var cards: Array[Card] = pending_skill_cards.duplicate()
	_ganglie_discard_active = false
	_ganglie_discard_continue = Callable()
	_ganglie_discard_owner = null
	_ganglie_discard_source = null
	_clear_skill_context()
	_move_cards(
		source, owner, cards, CardZone.DISCARD,
		"因【刚烈】弃置", null, owner.get_skill(&"ganglie"), null,
		Callable(self, "_finish_ganglie_discard").bind(source, cards, continuation)
	)


func _reopen_ganglie_choice() -> void:
	var owner: BattlePlayer = _ganglie_discard_owner
	var source: BattlePlayer = _ganglie_discard_source
	var continuation: Callable = _ganglie_discard_continue
	_ganglie_discard_active = false
	_ganglie_discard_continue = Callable()
	_ganglie_discard_owner = null
	_ganglie_discard_source = null
	_clear_skill_context()
	if owner == null or source == null:
		return
	choice_owner = source
	choice_labels.clear()
	if source.hand.size() >= 2:
		choice_labels.append("弃置两张手牌")
	choice_labels.append("受到1点普通伤害")
	_choice_handler = Callable(self, "_resolve_ganglie_human_choice").bind(owner, source, continuation)
	flow_state = FlowState.CHOOSING_OPTION
	_add_log("【刚烈】：%s 请选择弃置两张手牌或受到1点伤害。" % source.player_name)
	_emit_state()


func _finish_ganglie_discard(source: BattlePlayer, discarded: Array[Card], continuation: Callable) -> void:
	_add_log("%s 因【刚烈】弃置两张手牌：%s。" % [source.player_name, _card_list_text(discarded)])
	_call_safe(continuation)


func _finish_nested_ganglie_damage(remaining: Array[DamageContext], outer_after: Callable, continuation: Callable) -> void:
	_damage_queue = remaining
	_damage_after = outer_after
	_call_safe(continuation)


func _begin_yiji(owner: BattlePlayer, continuation: Callable) -> void:
	private_cards.clear()
	for _i: int in 2:
		var card: Card = _draw_one_from_pile()
		if card != null:
			private_cards.append(card)
	if private_cards.is_empty():
		_add_log("【遗计】没有可分配的牌，安全结束。")
		_call_safe(continuation)
		return
	private_card_owner = owner
	private_card_assignments.resize(private_cards.size())
	private_card_assignments.fill(-1)
	_async_skill_continue = continuation
	flow_state = FlowState.SKILL_ASSIGN_CARDS
	_add_log("%s 发动【遗计】，观看牌堆顶%d张牌并逐张分配。" % [owner.player_name, private_cards.size()])
	_emit_state()
	if owner.is_ai:
		for index: int in private_card_assignments.size(): private_card_assignments[index] = player_index(owner)
		_schedule("_perform_ai_confirm_private_cards", 0.2)


func request_assign_private_card(card_index: int, target_index: int) -> void:
	if flow_state != FlowState.SKILL_ASSIGN_CARDS or private_card_owner == null or private_card_owner.is_ai:
		return
	if card_index < 0 or card_index >= private_cards.size() or target_index < 0 or target_index >= players.size():
		return
	private_card_assignments[card_index] = target_index
	_add_log("【遗计】第%d张临时牌已指定交给%s。" % [card_index + 1, players[target_index].player_name])
	_emit_state()


func request_confirm_card_assignment() -> void:
	if flow_state != FlowState.SKILL_ASSIGN_CARDS or private_card_owner == null or private_card_owner.is_ai:
		return
	if -1 in private_card_assignments:
		_reject("请先为每张【遗计】牌指定获得者。")
		return
	_finish_private_card_assignment()


func request_cancel_card_assignment() -> void:
	if flow_state != FlowState.SKILL_ASSIGN_CARDS or private_card_owner == null or private_card_owner.is_ai:
		return
	for index: int in private_card_assignments.size():
		private_card_assignments[index] = player_index(private_card_owner)
	_add_log("取消【遗计】分配调整：临时牌全部交给技能拥有者，保证不丢失。")
	_finish_private_card_assignment()


func _perform_ai_confirm_private_cards() -> void:
	if flow_state == FlowState.SKILL_ASSIGN_CARDS and private_card_owner != null and private_card_owner.is_ai:
		_finish_private_card_assignment()


func _finish_private_card_assignment() -> void:
	var cards: Array[Card] = private_cards.duplicate()
	var assignments: Array[int] = private_card_assignments.duplicate()
	var continuation: Callable = _async_skill_continue
	private_cards.clear()
	private_card_assignments.clear()
	private_card_owner = null
	_async_skill_continue = Callable()
	for index: int in cards.size():
		var target_index: int = assignments[index] if index < assignments.size() and assignments[index] >= 0 else 0
		players[target_index].add_card(cards[index])
		_add_log("【遗计】第%d张牌交给%s。" % [index + 1, players[target_index].player_name])
	_call_safe(continuation)


func _begin_guanxing(owner: BattlePlayer, continuation: Callable) -> void:
	private_cards.clear()
	for _i: int in 2:
		var card: Card = _draw_one_from_pile()
		if card != null: private_cards.append(card)
	if private_cards.is_empty():
		_call_safe(continuation)
		return
	private_card_owner = owner
	deck_reorder_top = private_cards.duplicate()
	deck_reorder_bottom.clear()
	_async_skill_continue = continuation
	flow_state = FlowState.DECK_REORDER
	_add_log("%s 发动【观星】，观看牌堆顶%d张牌并调整顺序。" % [owner.player_name, private_cards.size()])
	_emit_state()
	if owner.is_ai:
		deck_reorder_top.sort_custom(func(a: Card, b: Card) -> bool: return _ai_card_value(a) > _ai_card_value(b))
		_schedule("_perform_ai_confirm_deck_reorder", 0.2)


func request_confirm_deck_reorder(top_indices: Array[int], bottom_indices: Array[int] = []) -> void:
	if flow_state != FlowState.DECK_REORDER or private_card_owner == null or private_card_owner.is_ai:
		return
	var seen: Dictionary = {}
	var top: Array[Card] = []
	for index: int in top_indices:
		if index < 0 or index >= private_cards.size() or seen.has(index):
			_reject("【观星】置顶索引无效或重复。")
			return
		seen[index] = true
		top.append(private_cards[index])
	var bottom: Array[Card] = []
	if bottom_indices.is_empty():
		for index: int in private_cards.size():
			if not seen.has(index): bottom.append(private_cards[index])
	else:
		for index: int in bottom_indices:
			if index < 0 or index >= private_cards.size() or seen.has(index):
				_reject("【观星】置底索引无效、重复或与置顶重叠。")
				return
			seen[index] = true
			bottom.append(private_cards[index])
		if seen.size() != private_cards.size():
			_reject("【观星】确认时必须为每张牌指定唯一去向。")
			return
	deck_reorder_top = top
	deck_reorder_bottom = bottom
	_finish_deck_reorder()


func request_cancel_deck_reorder() -> void:
	if flow_state != FlowState.DECK_REORDER or private_card_owner == null or private_card_owner.is_ai:
		return
	deck_reorder_top = private_cards.duplicate()
	deck_reorder_bottom.clear()
	_add_log("取消调整【观星】，按原顺序放回牌堆顶。")
	_finish_deck_reorder()


func _perform_ai_confirm_deck_reorder() -> void:
	if flow_state == FlowState.DECK_REORDER and private_card_owner != null and private_card_owner.is_ai:
		_finish_deck_reorder()


func _finish_deck_reorder() -> void:
	for index: int in range(deck_reorder_bottom.size() - 1, -1, -1):
		draw_pile.push_front(deck_reorder_bottom[index])
	for index: int in range(deck_reorder_top.size() - 1, -1, -1):
		draw_pile.push_back(deck_reorder_top[index])
	_add_log("【观星】完成：%d张置顶，%d张置底。" % [deck_reorder_top.size(), deck_reorder_bottom.size()])
	var continuation: Callable = _async_skill_continue
	private_cards.clear()
	private_card_owner = null
	deck_reorder_top.clear()
	deck_reorder_bottom.clear()
	_async_skill_continue = Callable()
	_call_safe(continuation)


func _begin_luoshen(owner: BattlePlayer, continuation: Callable) -> void:
	if not _luoshen_final_continue.is_valid():
		_luoshen_final_continue = continuation
	_start_judgement(&"luoshen", owner, Callable(self, "_evaluate_luoshen"), Callable(self, "_after_luoshen").bind(owner))


func _evaluate_luoshen(context: JudgementContextScript) -> void:
	var black: bool = context.effective_card.is_black()
	context.result_data["black"] = black
	if black:
		context.claim(context.judged_player)
	_add_log("【洛神】最终判定为%s，%s。" % [context.effective_card.identity_text(), "黑色，获得此牌" if black else "红色，流程结束"])


func _after_luoshen(context: JudgementContextScript, owner: BattlePlayer) -> void:
	if not bool(context.result_data.get("black", false)):
		_finish_luoshen()
		return
	owner.luoshen_cards_gained += 1
	var skill: Skill = owner.get_skill(&"luoshen")
	skill_owner = owner
	skill_actor = owner
	pending_skill = skill
	_skill_event_context = RefCounted.new()
	_skill_confirm_continue = Callable(self, "_repeat_luoshen")
	_skill_cancel_continue = Callable(self, "_finish_luoshen")
	flow_state = FlowState.SKILL_CONFIRM
	_add_log("%s 已通过【洛神】获得%d张牌，是否继续判定？" % [owner.player_name, owner.luoshen_cards_gained])
	_emit_state()
	if owner.is_ai: _schedule("_perform_ai_skill_confirm", 0.2)


func _repeat_luoshen() -> void:
	pass


func _finish_luoshen() -> void:
	var continuation: Callable = _luoshen_final_continue
	_luoshen_final_continue = Callable()
	_clear_skill_context()
	_call_safe(continuation)


func _begin_fanjian(source: BattlePlayer, target: BattlePlayer = null) -> void:
	if source == null or source.hand.is_empty():
		_return_to_play()
		return
	if target == null or target.is_dying() or target == source:
		target = other_player(source)
	if target == null:
		_return_to_play()
		return
	_fanjian_source = source
	_fanjian_target = target
	flow_state = FlowState.CHOOSING_SUIT
	choice_owner = _fanjian_target
	choice_labels = ["黑桃", "红桃", "梅花", "方块"]
	_add_log("%s 发动【反间】：%s 先选择一种花色，尚未查看随机牌。" % [source.player_name, _fanjian_target.player_name])
	_emit_state()
	if _fanjian_target.is_ai:
		_schedule("_perform_ai_choose_fanjian_suit", 0.25)


func request_choose_suit(suit_index: int) -> void:
	if flow_state != FlowState.CHOOSING_SUIT or choice_owner == null or choice_owner.is_ai:
		return
	if suit_index < 0 or suit_index > 3:
		return
	_resolve_fanjian_suit(suit_index)


func _perform_ai_choose_fanjian_suit() -> void:
	if flow_state == FlowState.CHOOSING_SUIT and choice_owner != null and choice_owner.is_ai:
		_resolve_fanjian_suit(randi_range(0, 3))


func _resolve_fanjian_suit(suit_index: int) -> void:
	_fanjian_selected_suit = suit_index + 1
	var source: BattlePlayer = _fanjian_source
	var target: BattlePlayer = _fanjian_target
	choice_labels.clear()
	choice_owner = null
	if source == null or target == null or source.hand.is_empty():
		_add_log("【反间】获得牌前来源已无手牌，安全结束。")
		_return_to_play()
		return
	var index: int = randi_range(0, source.hand.size() - 1)
	var gained: Card = source.hand[index]
	_add_log("%s 选择%s并随机获得%s；此时才公开牌面。" % [target.player_name, Card.suit_name(_fanjian_selected_suit), gained.identity_text()])
	_move_cards(
		source, source, [gained], CardZone.HAND,
		"被【反间】获得", null, source.get_skill(&"fanjian"), target,
		Callable(self, "_after_fanjian_gained").bind(source, target, gained)
	)


func _after_fanjian_gained(source: BattlePlayer, target: BattlePlayer, gained: Card) -> void:
	if gained.suit == _fanjian_selected_suit:
		_add_log("【反间】花色相同，不造成伤害。")
		_return_to_play()
	else:
		var use_context := SkillUseContext.new(source, [], Card.CardType.DUEL, source.get_skill(&"fanjian"), target, true, "【反间】")
		_start_damage(source, target, 1, DamageNature.NORMAL, Callable(self, "_return_to_play"), null, use_context, "【反间】")


## 【离间】两步选目标：第一步选【决斗】使用者，第二步选【决斗】对象。
func _resolve_lijian_target(target: BattlePlayer) -> void:
	if target == null or target.is_dying() or target == skill_actor or target.gender != GeneralDefinition.Gender.MALE:
		_reject("【离间】只能选择两名其他男性角色。")
		return
	if _lijian_first_target == null:
		_lijian_first_target = target
		_add_log("%s 选择 %s 作为【离间】的【决斗】使用者，请再选择【决斗】对象。" % [
			skill_actor.player_name,
			target.player_name,
		])
		flow_state = FlowState.SKILL_SELECT_TARGET
		_emit_state()
		return
	if target == _lijian_first_target:
		_reject("【决斗】对象不能与使用者相同。")
		return
	var first: BattlePlayer = _lijian_first_target
	_lijian_first_target = null
	pending_skill_targets = [first, target]
	_resolve_active_skill()


func _resolve_lijian(
	actor: BattlePlayer,
	skill: Skill,
	cards: Array[Card],
	first: BattlePlayer,
	second: BattlePlayer
) -> void:
	if (
		first == null or second == null or first == second
		or first == actor or second == actor
		or first.is_dying() or second.is_dying()
		or first.gender != GeneralDefinition.Gender.MALE
		or second.gender != GeneralDefinition.Gender.MALE
	):
		_add_log("【离间】目标组合已不再合法。")
		_clear_skill_context()
		_return_to_play()
		return
	_move_cards(
		actor,
		actor,
		cards,
		CardZone.DISCARD,
		"作为【离间】代价",
		null,
		skill,
		null,
		Callable(self, "_apply_lijian").bind(actor, skill, first, second, cards)
	)


func _apply_lijian(
	actor: BattlePlayer,
	skill: Skill,
	first: BattlePlayer,
	second: BattlePlayer,
	paid: Array[Card]
) -> void:
	actor.record_skill_use(skill)
	_add_log("%s 发动【离间】，弃置%s；令 %s 视为对 %s 使用【决斗】。" % [
		actor.player_name,
		_card_list_text(paid),
		first.player_name,
		second.player_name,
	])
	_clear_skill_context()
	var virtual_duel: Card = DuelCard.new()
	_active_use_context = SkillUseContext.new(
		first, [], Card.CardType.DUEL, skill, second, true, "【离间】"
	)
	_start_nullifiable_effect(
		virtual_duel,
		first,
		second,
		Callable(self, "_apply_duel"),
		Callable(self, "_finish_nullifiable_effect"),
		Callable(self, "_return_to_play"),
		true
	)


## 将同一时机的技能一次性构造后串行结算，避免异步选择覆盖 pending_skill。
func _enqueue_triggers(
	timing: StringName,
	event_context: RefCounted,
	owners: Array[BattlePlayer],
	continuation: Callable
) -> void:
	if not _trigger_queue.is_empty() or _trigger_queue_continue.is_valid():
		_trigger_stack.append({"queue": _trigger_queue.duplicate(), "continuation": _trigger_queue_continue})
	_trigger_queue.clear()
	_trigger_queue_continue = continuation
	for owner: BattlePlayer in owners:
		if owner == null or owner.hp <= 0:
			continue
		for skill: Skill in owner.skills:
			if skill.activation_mode != Skill.ActivationMode.TRIGGERED or skill.trigger_timing() != timing:
				continue
			if not owner.can_pay_skill_usage(skill) or not skill.can_trigger(event_context, self, owner):
				continue
			var repeat_count: int = maxi(skill.trigger_repeat_count(event_context, self, owner), 0)
			for _index: int in repeat_count:
				_trigger_queue.append(TriggerEntryScript.new(owner, skill, event_context, timing))
	## 白银狮子离场效果进入同一触发队列串行结算。
	if timing == &"after_card_move":
		var move_event := event_context as CardMoveContextScript
		if move_event != null:
			for lost: Card in move_event.lost_equipment_cards():
				if lost.card_type == Card.CardType.SILVER_LION and move_event.owner.hp < move_event.owner.max_hp:
					_trigger_queue.append(TriggerEntryScript.new(move_event.owner, SilverLionLeaveScript.new(), event_context, timing))
	_process_next_trigger()


func _process_next_trigger() -> void:
	while not _trigger_queue.is_empty():
		var entry: TriggerEntryScript = _trigger_queue.pop_front()
		if entry.owner == null or entry.owner.hp <= 0:
			continue
		if not entry.owner.can_pay_skill_usage(entry.skill) or not entry.skill.can_trigger(entry.event_context, self, entry.owner):
			continue
		_offer_triggered_skill(entry.owner, entry.skill, entry.event_context, Callable(self, "_process_next_trigger"))
		return
	var continuation: Callable = _trigger_queue_continue
	if not _trigger_stack.is_empty():
		var previous: Dictionary = _trigger_stack.pop_back()
		_trigger_queue = previous.queue
		_trigger_queue_continue = previous.continuation
	else:
		_trigger_queue_continue = Callable()
	_call_safe(continuation)


func request_dodge() -> void:
	if (
		flow_state in [FlowState.RESPONDING_SLASH, FlowState.MULTI_RESPONSE]
		and is_waiting_for_dodge_from(pending_target)
		and not pending_target.is_ai
	):
		if _slash_dodge_forbidden and pending_target == pending_target:
			_reject("【铁骑】判定为红色，本次【杀】不能使用或打出【闪】响应。")
			return
		var index: int = pending_target.find_card(Card.CardType.DODGE)
		if index < 0:
			_reject("手牌中没有【闪】。")
			return
		_resolve_slash_dodge(index)
	elif (
		flow_state == FlowState.AOE_RESPONSE
		and _response_card_type == Card.CardType.DODGE
		and not pending_target.is_ai
	):
		request_response_card()


func request_pass_response() -> void:
	if (
		flow_state in [FlowState.RESPONDING_SLASH, FlowState.MULTI_RESPONSE]
		and _multi_response_origin in [FlowState.IDLE, FlowState.RESPONDING_SLASH]
		and not pending_target.is_ai
	):
		_add_log("%s 未使用【闪】。" % pending_target.player_name)
		_resolve_slash_damage()
	elif flow_state in [FlowState.AOE_RESPONSE, FlowState.DUEL_RESPONSE, FlowState.BORROW_RESPONSE, FlowState.MULTI_RESPONSE]:
		if _current_response_player() != null and not _current_response_player().is_ai:
			_pass_current_response()


func request_bagua_judgement() -> void:
	var defender: BattlePlayer = _current_response_player()
	if defender == null or defender.is_ai or not can_use_bagua(defender):
		return
	if _slash_dodge_forbidden and defender == pending_target:
		return
	_resolve_bagua_judgement(defender)


func request_serpent_spear() -> void:
	var user: BattlePlayer = current_player()
	if flow_state not in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]:
		user = _current_response_player()
	if user == null or user.is_ai or not can_use_serpent_spear(user):
		return
	_use_serpent_spear(user)


func request_response_card() -> void:
	match flow_state:
		FlowState.AOE_RESPONSE:
			var index: int = pending_target.find_card(_response_card_type)
			if index < 0:
				_reject("没有所需的响应牌。")
				return
			var response: Card = pending_target.hand[index]
			var response_context := SkillUseContext.new(
				pending_target,
				[response],
				_response_card_type,
				null,
				_global_source,
				false,
				"群体锦囊响应"
			)
			_move_cards(
				pending_target,
				_global_source,
				[response],
				CardZone.PROCESSING,
				"打出【%s】响应" % CardFactory.create_card(_response_card_type).display_name,
				_effect_card,
				null,
				null,
				Callable(self, "_accept_effective_response").bind(response_context, FlowState.AOE_RESPONSE)
			)
		FlowState.DUEL_RESPONSE, FlowState.MULTI_RESPONSE:
			if flow_state == FlowState.MULTI_RESPONSE and _multi_response_origin != FlowState.DUEL_RESPONSE:
				return
			var duel_index: int = _duel_responder.find_card(Card.CardType.SLASH)
			if duel_index < 0:
				_reject("没有【杀】可用于决斗。")
				return
			var response: Card = _duel_responder.hand[duel_index]
			var context := SkillUseContext.new(
				_duel_responder,
				[response],
				Card.CardType.SLASH,
				null,
				_duel_other,
				false,
				"【决斗】响应"
			)
			_move_cards(
				_duel_responder,
				_duel_other,
				[response],
				CardZone.PROCESSING,
				"打出【杀】响应【决斗】",
				_duel_use_context.primary_physical_card() if _duel_use_context != null else null,
				null,
				null,
				Callable(self, "_accept_effective_response").bind(context, FlowState.DUEL_RESPONSE)
			)
		FlowState.BORROW_RESPONSE:
			_borrow_use_slash()


func request_nullification() -> void:
	if flow_state != FlowState.NULLIFICATION_RESPONSE:
		return
	var responder: BattlePlayer = players[_nullification_responder_index]
	if responder.is_ai:
		return
	var index: int = responder.find_card(Card.CardType.NULLIFICATION)
	if index < 0:
		_reject("手牌中没有【无懈可击】。")
		return
	_play_nullification(responder, index)


func request_pass_nullification() -> void:
	if flow_state != FlowState.NULLIFICATION_RESPONSE:
		return
	var responder: BattlePlayer = players[_nullification_responder_index]
	if responder.is_ai:
		return
	_pass_nullification(responder)


func request_option(option_index: int) -> void:
	if flow_state != FlowState.CHOOSING_OPTION or choice_owner == null or choice_owner.is_ai:
		return
	if option_index < 0 or option_index >= choice_labels.size():
		return
	var handler: Callable = _choice_handler
	choice_labels.clear()
	_choice_handler = Callable()
	handler.call(option_index)


func request_revealed_card(card_index: int) -> void:
	if (
		flow_state != FlowState.CHOOSING_REVEALED
		or _revealed_selecting_player == null
		or _revealed_selecting_player.is_ai
	):
		return
	_take_amazing_grace_card(card_index)


func request_fire_reveal(hand_index: int) -> void:
	if flow_state != FlowState.FIRE_REVEAL or _fire_target.is_ai:
		return
	if hand_index < 0 or hand_index >= _fire_target.hand.size():
		return
	_reveal_for_fire_attack(_fire_target.hand[hand_index])


func request_fire_discard(hand_index: int) -> void:
	if flow_state != FlowState.FIRE_DISCARD or _fire_source.is_ai:
		return
	if hand_index < 0 or hand_index >= _fire_source.hand.size():
		return
	var card: Card = _fire_source.hand[hand_index]
	if card.suit != _fire_revealed_card.suit:
		_reject("必须弃置与展示牌花色相同的牌。")
		return
	_consume_hand_card(_fire_source, hand_index)


func request_pass_fire_discard() -> void:
	if flow_state == FlowState.FIRE_DISCARD and not _fire_source.is_ai:
		_add_log("%s 放弃弃置同花色牌，【火攻】未造成伤害。" % _fire_source.player_name)
		_finish_nullifiable_effect()


func request_rescue(card_type: Card.CardType) -> void:
	if flow_state != FlowState.DYING_RESCUE or rescue_actor == null or rescue_actor.is_ai:
		return
	if card_type == Card.CardType.WINE and rescue_actor != dying_player:
		_reject("【酒】只能由濒死角色本人使用。")
		return
	var card_index: int = rescue_actor.find_card(card_type)
	if card_index < 0:
		_reject("没有可用于救援的牌。")
		return
	_use_rescue_card(rescue_actor, card_index)


func request_give_up_rescue() -> void:
	if flow_state == FlowState.DYING_RESCUE and rescue_actor != null and not rescue_actor.is_ai:
		_resolve_rescue_pass(rescue_actor)


func request_end_play_phase() -> void:
	if (
		flow_state not in [FlowState.PLAY_ACTIVE, FlowState.SELECTING_TARGET]
		or phase != Phase.PLAY
		or current_player().is_ai
	):
		return
	selected_hand_index = -1
	_finish_play_phase()


func _finish_play_phase() -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	flow_state = FlowState.IDLE
	_enqueue_triggers(&"after_play_phase", RefCounted.new(), [current_player()], Callable(self, "_after_play_phase_triggers"))


func _after_play_phase_triggers() -> void:
	if current_player().skip_discard_this_turn:
		phase = Phase.END
		flow_state = FlowState.IDLE
		_add_log("弃牌阶段已跳过，进入结束阶段。")
		_finish_turn_from_end_phase()
	else:
		_enter_discard_phase()


func _finish_turn_from_end_phase() -> void:
	current_player().wine_active = false
	_add_log("结束阶段。")
	_emit_state()
	_enqueue_triggers(&"end_phase_start", RefCounted.new(), [current_player()], Callable(self, "_after_end_phase_triggers"))


func _after_end_phase_triggers() -> void:
	## 线性轮转：寻找下一名存活角色，已死亡角色自动跳过。
	current_player_index = next_living_player_index(current_player_index)
	_schedule("_begin_turn", 0.6)


func request_discard(hand_index: int) -> void:
	if flow_state != FlowState.DISCARDING or current_player().is_ai:
		return
	if current_player().hand.size() <= hand_limit_for(current_player()):
		_finish_discard_phase()
		return
	var card: Card = current_player().hand[hand_index]
	if card == null:
		return
	_move_cards(
		current_player(), current_player(), [card], CardZone.DISCARD,
		"在弃牌阶段弃置", null, null, null,
		Callable(self, "_after_phase_discard").bind(current_player(), card)
	)


func _after_phase_discard(player: BattlePlayer, card: Card) -> void:
	_add_log("%s 弃置了%s。" % [player.player_name, card.identity_text()])
	if flow_state != FlowState.DISCARDING:
		return
	if player.hand.size() <= hand_limit_for(player):
		_finish_discard_phase()
	else:
		_emit_state()


func draw_cards(player: BattlePlayer, count: int) -> void:
	for _index: int in count:
		var card: Card = _draw_one_from_pile()
		if card == null:
			return
		player.add_card(card)


func _activate_play_card(user: BattlePlayer, hand_index: int) -> void:
	var card: Card = user.hand[hand_index]
	match card.card_type:
		Card.CardType.SLASH:
			if not card.can_use_in_play(self, user):
				_reject("本回合已经使用过【杀】。")
				return
			_select_target(hand_index, card)
		Card.CardType.PEACH:
			if not card.can_use_in_play(self, user):
				_reject("体力已满，不能主动使用【桃】。")
				return
			_play_peach(user, hand_index)
		Card.CardType.WINE:
			if not card.can_use_in_play(self, user):
				_reject("本回合已有【酒】效果。")
				return
			_play_wine(user, hand_index)
		Card.CardType.DODGE, Card.CardType.NULLIFICATION:
			_reject("该牌只能在对应的响应时机使用。")
		Card.CardType.IRON_CHAIN:
			_begin_iron_chain_choice(user, hand_index)
		_:
			if card.category == Card.CardCategory.EQUIPMENT:
				_play_equipment(user, hand_index)
			elif not card.can_use_in_play(self, user):
				_reject("当前没有【%s】的合法目标。" % card.display_name)
			elif card.target_mode in [Card.TargetMode.SELF, Card.TargetMode.ALL]:
				_use_self_or_global_trick(user, hand_index)
			else:
				_select_target(hand_index, card)


func _select_target(hand_index: int, card: Card) -> void:
	selected_hand_index = hand_index
	flow_state = FlowState.SELECTING_TARGET
	_add_log("%s 选择【%s】，等待指定目标。" % [current_player().player_name, card.display_name])
	_emit_state()


func _is_valid_trick_target(card: Card, source: BattlePlayer, target: BattlePlayer) -> bool:
	match card.card_type:
		Card.CardType.DISMANTLE:
			return target != source and target.total_cards_in_hand_and_equipment() > 0
		Card.CardType.STEAL:
			return (
				target != source
				and (_trick_distance_free(source, Card.CardType.STEAL) or distance_between(source, target) == 1)
				and not target.hand.is_empty()
				and _skills_allow_target(source, target, Card.CardType.STEAL)
			)
		Card.CardType.DUEL:
			return target != source and _skills_allow_target(source, target, Card.CardType.DUEL)
		Card.CardType.BORROW_SWORD:
			return (
				target != source
				and (_trick_distance_free(source, Card.CardType.BORROW_SWORD) or distance_between(source, target) == 1)
				and target.weapon != null
				and can_slash_target(target, source)
			)
		Card.CardType.FIRE_ATTACK:
			return not target.hand.is_empty()
		Card.CardType.INDULGENCE, Card.CardType.SUPPLY_SHORTAGE:
			return (
				target != source
				and not target.has_delayed_trick(card.card_type)
				and _skills_allow_target(source, target, card.card_type)
			)
	return target != source


func _use_self_or_global_trick(user: BattlePlayer, hand_index: int) -> void:
	var card: Card = user.hand[hand_index]
	if card.card_type == Card.CardType.LIGHTNING:
		_move_cards(
			user, user, [card], CardZone.PROCESSING, "使用【闪电】",
			null, null, null,
			Callable(self, "_proceed_lightning_use").bind(user, card)
		)
		return
	_move_cards(
		user, user, [card], CardZone.PROCESSING, "使用%s" % card.display_name,
		null, null, null,
		Callable(self, "_proceed_self_trick_use").bind(user, card)
	)


func _proceed_lightning_use(user: BattlePlayer, delayed: Card) -> void:
	_active_use_context = SkillUseContext.new(
		user, [delayed], delayed.card_type, null, user, false, "延时锦囊"
	)
	_start_delayed_placement(delayed, user, user)


func _proceed_self_trick_use(user: BattlePlayer, used: Card) -> void:
	_active_use_context = SkillUseContext.new(
		user, [used], used.card_type, null, user, false, "主动锦囊"
	)
	_add_log("%s 使用%s。" % [user.player_name, used.identity_text()])
	var continuation: Callable = Callable(self, "_apply_self_trick_effect").bind(user, used)
	if _is_non_delayed_trick(used):
		_enqueue_triggers(&"after_trick_use", _active_use_context, [user], continuation)
	else:
		_call_safe(continuation)


func _apply_self_trick_effect(user: BattlePlayer, used: Card) -> void:
	match used.card_type:
		Card.CardType.DRAW_TWO:
			_start_nullifiable_effect(
				used, user, user,
				Callable(self, "_apply_draw_two"),
				Callable(self, "_finish_nullifiable_effect"),
				Callable(self, "_return_to_play"),
				false
			)
		Card.CardType.AMAZING_GRACE, Card.CardType.PEACH_GARDEN, Card.CardType.BARBARIAN_INVASION, Card.CardType.ARROW_BARRAGE:
			_start_global_trick(used, user)


func _is_non_delayed_trick(card: Card) -> bool:
	return card != null and card.is_trick() and not card.is_delayed_trick


func _use_target_trick(user: BattlePlayer, target: BattlePlayer, hand_index: int) -> void:
	if hand_index < 0 or hand_index >= user.hand.size():
		return
	var card: Card = user.hand[hand_index]
	if not _is_valid_trick_target(card, user, target):
		_reject("目标已不再合法。")
		return
	selected_hand_index = -1
	if card.is_delayed_trick:
		_move_cards(
			user, user, [card], CardZone.PROCESSING, "使用延时锦囊%s" % card.display_name,
			null, null, null,
			Callable(self, "_proceed_delayed_placement_use").bind(user, card, target)
		)
		return
	_move_cards(
		user, user, [card], CardZone.PROCESSING, "使用%s" % card.display_name,
		null, null, null,
		Callable(self, "_proceed_target_trick_use").bind(user, card, target)
	)


func _proceed_delayed_placement_use(user: BattlePlayer, delayed: Card, target: BattlePlayer) -> void:
	_active_use_context = SkillUseContext.new(
		user, [delayed], delayed.card_type, null, target, false, "延时锦囊"
	)
	_start_delayed_placement(delayed, user, target)


func _proceed_target_trick_use(user: BattlePlayer, used: Card, target: BattlePlayer) -> void:
	_active_use_context = SkillUseContext.new(
		user, [used], used.card_type, null, target, false, "主动锦囊"
	)
	_add_log("%s 对 %s 使用%s。" % [user.player_name, target.player_name, used.identity_text()])
	var continuation: Callable = Callable(self, "_apply_target_trick_effect").bind(user, used, target)
	if _is_non_delayed_trick(used):
		_enqueue_triggers(&"after_trick_use", _active_use_context, [user], continuation)
	else:
		_call_safe(continuation)


func _apply_target_trick_effect(user: BattlePlayer, used: Card, target: BattlePlayer) -> void:
	match used.card_type:
		Card.CardType.DISMANTLE:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_dismantle"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)
		Card.CardType.STEAL:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_steal"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)
		Card.CardType.DUEL:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_duel"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)
		Card.CardType.BORROW_SWORD:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_borrow_sword"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)
		Card.CardType.FIRE_ATTACK:
			_start_nullifiable_effect(used, user, target, Callable(self, "_apply_fire_attack"), Callable(self, "_finish_nullifiable_effect"), Callable(self, "_return_to_play"), true)


func _play_peach(user: BattlePlayer, hand_index: int) -> void:
	if hand_index < 0 or hand_index >= user.hand.size():
		return
	var card: Card = user.hand[hand_index]
	_move_cards(
		user, user, [card], CardZone.PROCESSING, "使用【桃】",
		null, null, null,
		Callable(self, "_apply_play_peach").bind(user, card)
	)


func _apply_play_peach(user: BattlePlayer, card: Card) -> void:
	user.recover(1)
	_add_log("%s 使用【桃】，回复至 %d/%d。" % [user.player_name, user.hp, user.max_hp])
	_settle_processing_card(card)
	## 若本次移动触发过连营等，flow 仍在 SKILL_RESOLVING，必须恢复出牌状态。
	flow_state = FlowState.PLAY_ACTIVE
	_emit_state()
	if user.is_ai:
		_schedule("_perform_ai_play", 0.4)


func _play_wine(user: BattlePlayer, hand_index: int) -> void:
	if hand_index < 0 or hand_index >= user.hand.size():
		return
	var card: Card = user.hand[hand_index]
	_move_cards(
		user, user, [card], CardZone.PROCESSING, "使用【酒】",
		null, null, null,
		Callable(self, "_apply_play_wine").bind(user, card)
	)


func _apply_play_wine(user: BattlePlayer, card: Card) -> void:
	user.wine_active = true
	_add_log("%s 使用【酒】：本回合下一张【杀】伤害 +1。" % user.player_name)
	_settle_processing_card(card)
	flow_state = FlowState.PLAY_ACTIVE
	_emit_state()
	if user.is_ai:
		_schedule("_perform_ai_play", 0.4)


func _play_equipment(user: BattlePlayer, hand_index: int) -> void:
	if not can_equip(user):
		return
	if (
		hand_index < 0
		or hand_index >= user.hand.size()
		or user.hand[hand_index].category != Card.CardCategory.EQUIPMENT
	):
		return
	var equipment: Card = user.hand[hand_index]
	var replaced: Card = user.equipment_in_slot(equipment.equipment_slot)
	var slot_zone: int = _slot_to_zone(equipment.equipment_slot)
	var excluded: Array[Card] = []
	if replaced != null:
		excluded.append(replaced)
	_move_cards(
		user, user, [equipment], slot_zone, "装备【%s】" % equipment.display_name,
		null, null, user,
		Callable(self, "_after_equipment_placed").bind(user, equipment, replaced),
		excluded
	)


func _after_equipment_placed(user: BattlePlayer, equipment: Card, replaced: Card) -> void:
	_add_log("%s 装备【%s】到%s。" % [
		user.player_name,
		equipment.display_name,
		_equipment_slot_text(equipment.equipment_slot),
	])
	if replaced != null:
		_lose_equipment(
			user,
			replaced,
			"被同类装备替换",
			false,
			Callable(self, "_after_equipment_replacement").bind(user),
			true
		)
	else:
		_after_equipment_replacement(user)


func _after_equipment_replacement(user: BattlePlayer) -> void:
	flow_state = FlowState.PLAY_ACTIVE
	_emit_state()
	if user.is_ai:
		_schedule("_perform_ai_play", 0.45)


func _slot_to_zone(slot: int) -> int:
	match slot:
		EquipmentScript.Slot.WEAPON:
			return CardZone.WEAPON
		EquipmentScript.Slot.ARMOR:
			return CardZone.ARMOR
		EquipmentScript.Slot.HORSE_PLUS:
			return CardZone.HORSE_PLUS
		EquipmentScript.Slot.HORSE_MINUS:
			return CardZone.HORSE_MINUS
	return CardZone.WEAPON


func _play_slash(attacker: BattlePlayer, target: BattlePlayer, hand_index: int) -> void:
	if attacker == target or not can_use_slash_in_play(attacker):
		_reject("现在不能使用【杀】。")
		return
	if not can_slash_target(attacker, target):
		_reject("目标距离为 %d，超出攻击范围 %d。" % [distance_between(attacker, target), attack_range(attacker)])
		return
	var card: Card = attacker.hand[hand_index]
	if card == null or card.card_type != Card.CardType.SLASH:
		return
	_move_cards(
		attacker,
		attacker,
		[card],
		CardZone.PROCESSING,
		"使用【杀】",
		null,
		null,
		null,
		Callable(self, "_proceed_play_slash").bind(attacker, target, card)
	)


func _proceed_play_slash(attacker: BattlePlayer, target: BattlePlayer, card: Card) -> void:
	_record_slash_use(attacker)
	selected_hand_index = -1
	var amount: int = 2 if attacker.wine_active else 1
	attacker.wine_active = false
	var nature: DamageNature = DamageNature.FIRE if _has_equipment(attacker, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
	var use_context := SkillUseContext.new(
		attacker,
		[card],
		Card.CardType.SLASH,
		null,
		target,
		false,
		"使用【杀】"
	)
	_attack_use_context = use_context
	_add_log("%s 对 %s 使用%s【杀】%s（距离 %d / 范围 %d）。" % [
		attacker.player_name,
		target.player_name,
		"火属性" if nature == DamageNature.FIRE else "",
		"（酒杀，伤害 2）" if amount == 2 else "",
		distance_between(attacker, target),
		attack_range(attacker),
	])
	_start_slash_response(attacker, target, amount, Callable(self, "_return_to_play"), nature, use_context)


func _start_slash_response(
	attacker: BattlePlayer,
	target: BattlePlayer,
	amount: int,
	after: Callable,
	nature: DamageNature = DamageNature.NORMAL,
	use_context: SkillUseContext = null
) -> void:
	pending_attacker = attacker
	pending_target = target
	pending_damage = amount
	_attack_after = after
	_attack_nature = nature
	if use_context == null:
		use_context = SkillUseContext.new(
			attacker,
			[],
			Card.CardType.SLASH,
			null,
			target,
			true,
			"【杀】"
		)
	_attack_use_context = use_context
	_slash_ignores_armor = _has_equipment(attacker, Card.CardType.QINGGANG_SWORD)
	_ice_sword_checked = false
	_bagua_attempted = false
	_slash_dodge_forbidden = false
	if _slash_ignores_armor:
		_add_log("【青釭剑】锁定技：本次【杀】无视 %s 的防具。" % target.player_name)
	## 铁骑、流离等“杀指定后、闪响应前”技能进入触发队列，之后才进入闪响应。
	var slash_context := SlashTargetContextScript.new(
		attacker,
		target,
		use_context.physical_cards if use_context != null else [],
		use_context.effective_card_type if use_context != null else Card.CardType.SLASH,
		amount,
		nature,
		_slash_ignores_armor,
		use_context
	)
	_enqueue_triggers(&"slash_targeted", slash_context, [attacker, target], Callable(self, "_continue_slash_response"))


func _continue_slash_response() -> void:
	var target: BattlePlayer = pending_target
	var use_context: SkillUseContext = _attack_use_context
	if target == null or flow_state == FlowState.GAME_OVER:
		return
	_response_card_type = Card.CardType.DODGE
	response_required_count = _response_requirement(use_context, target)
	response_received_count = 0
	_multi_response_origin = FlowState.RESPONDING_SLASH
	flow_state = FlowState.MULTI_RESPONSE if response_required_count > 1 else FlowState.RESPONDING_SLASH
	if response_required_count > 1:
		_add_log("【无双】锁定技：%s 需要连续打出 %d 张【闪】。" % [
			target.player_name,
			response_required_count,
		])
	_emit_state()
	if target.is_ai:
		_schedule("_perform_ai_response", 0.55)


func _begin_tieqi(ctx: SlashTargetContextScript, owner: BattlePlayer, continuation: Callable) -> void:
	if ctx == null or ctx.source == null or ctx.current_target == null:
		_call_safe(continuation)
		return
	_start_judgement(
		&"tieqi",
		owner,
		Callable(self, "_evaluate_tieqi"),
		Callable(self, "_after_tieqi").bind(owner, ctx.current_target, continuation)
	)


func _evaluate_tieqi(context: JudgementContextScript) -> void:
	context.result_data["red"] = context.effective_card != null and context.effective_card.is_red()
	_add_log("【铁骑】最终判定为%s（%s）。" % [
		context.effective_card.identity_text() if context.effective_card != null else "无牌",
		"红色" if bool(context.result_data.get("red", false)) else "黑色",
	])


func _after_tieqi(context: JudgementContextScript, owner: BattlePlayer, target: BattlePlayer, continuation: Callable) -> void:
	if bool(context.result_data.get("red", false)) and target != null and target == pending_target:
		_slash_dodge_forbidden = true
		_add_log("【铁骑】判定为红色：%s 不能使用或打出【闪】响应此【杀】。" % target.player_name)
	_call_safe(continuation)


func _begin_liuli(ctx: SlashTargetContextScript, owner: BattlePlayer, continuation: Callable) -> void:
	if ctx == null or ctx.current_target != owner:
		_call_safe(continuation)
		return
	var candidates: Array[BattlePlayer] = liuli_transfer_candidates(owner, ctx)
	if candidates.is_empty():
		_add_log("【流离】当前双人局没有合法转移目标，自动放弃。")
		_call_safe(continuation)
		return
	if owner.is_ai:
		_add_log("【流离】AI 判断没有合法转移目标，放弃。")
		_call_safe(continuation)
		return
	skill_owner = owner
	skill_actor = owner
	pending_skill = owner.get_skill(&"liuli")
	pending_skill_cards.clear()
	pending_skill_targets.clear()
	_liuli_slash_context = ctx
	_liuli_continue = continuation
	_skill_return_state = FlowState.RESPONDING_SLASH
	flow_state = FlowState.SKILL_SELECT_CARDS
	_add_log("%s 发动【流离】：请选择一张手牌或装备牌作为代价。" % owner.player_name)
	_emit_state()


func _finish_liuli_cost_selection() -> void:
	if pending_skill_cards.size() != 1:
		return
	flow_state = FlowState.SKILL_SELECT_TARGET
	_emit_state()


func _resolve_liuli_transfer(target: BattlePlayer) -> void:
	var owner: BattlePlayer = skill_actor
	if owner == null or pending_skill_cards.size() != 1 or target == null:
		_reject("【流离】转移失败。")
		return
	var ctx := _liuli_slash_context as SlashTargetContextScript
	if ctx == null or target not in liuli_transfer_candidates(owner, ctx):
		_reject("该角色不是【流离】的合法转移目标。")
		return
	var cost: Card = pending_skill_cards[0]
	owner.record_skill_use(pending_skill)
	var new_target: BattlePlayer = target
	var continuation: Callable = _liuli_continue
	_liuli_slash_context = null
	_liuli_continue = Callable()
	_move_cards(
		owner,
		owner,
		[cost],
		CardZone.DISCARD,
		"作为【流离】代价",
		null,
		pending_skill,
		null,
		Callable(self, "_apply_liuli_transfer").bind(owner, ctx, new_target, continuation)
	)


func _apply_liuli_transfer(owner: BattlePlayer, ctx: SlashTargetContextScript, new_target: BattlePlayer, continuation: Callable) -> void:
	_clear_skill_context()
	if flow_state == FlowState.GAME_OVER or pending_attacker == null or new_target == null:
		_call_safe(continuation)
		return
	if new_target == pending_attacker or new_target == ctx.original_target:
		_add_log("【流离】转移目标已不合法，原目标不变。")
		_call_safe(continuation)
		return
	ctx.retarget(new_target)
	pending_target = new_target
	_attack_use_context.target = new_target if _attack_use_context != null else null
	_add_log("【流离】：%s 将【杀】转移给 %s，%s 不再成为目标。" % [
		owner.player_name,
		new_target.player_name,
		ctx.original_target.player_name,
	])
	## 不重新支付【杀】、不重复计出杀次数、不生成第二张实体牌，直接进入新目标的闪响应。
	_continue_slash_response()


func _resolve_slash_dodge(dodge_index: int) -> void:
	var defender: BattlePlayer = pending_target
	if defender == null or dodge_index < 0 or dodge_index >= defender.hand.size():
		return
	var dodge: Card = defender.hand[dodge_index]
	var context := SkillUseContext.new(
		defender,
		[dodge],
		Card.CardType.DODGE,
		null,
		pending_attacker,
		false,
		"响应【杀】"
	)
	_move_cards(
		defender,
		pending_attacker,
		[dodge],
		CardZone.PROCESSING,
		"打出【闪】响应【杀】",
		_attack_use_context.primary_physical_card() if _attack_use_context != null else null,
		null,
		null,
		Callable(self, "_accept_effective_response").bind(context, _multi_response_origin)
	)


func _response_requirement(context: SkillUseContext, responder: BattlePlayer) -> int:
	var required: int = 1
	if context == null or context.user == null:
		return required
	for skill: Skill in context.user.skills:
		if skill.activation_mode == Skill.ActivationMode.MODIFIER:
			required = skill.modify_response_required_count(
				context,
				responder,
				required,
				self,
				context.user
			)
	return maxi(required, 1)


func _accept_effective_response(context: SkillUseContext, origin: FlowState) -> void:
	if context == null:
		return
	if (
		context.effective_card_type == Card.CardType.DODGE
		and _slash_dodge_forbidden
		and context.user == pending_target
		and flow_state in [FlowState.RESPONDING_SLASH, FlowState.MULTI_RESPONSE]
	):
		_add_log("【铁骑】禁止响应：%s 不能使用或打出【闪】。" % context.user.player_name)
		_resolve_slash_damage()
		return
	_record_effective_card_action(context.user, context.effective_card_type)
	if context.effective_card_type == Card.CardType.DODGE:
		if origin == FlowState.AOE_RESPONSE:
			## 万箭齐发：AI/玩家打出【闪】即完成本次响应，走锦囊结算而非杀闪路径。
			_add_log("%s 打出【闪】，响应成功。" % context.user.player_name)
			_finish_nullifiable_effect()
			return
		response_received_count += 1
		_add_log("%s 打出第 %d/%d 张【闪】。" % [
			context.user.player_name,
			response_received_count,
			response_required_count,
		])
		if response_received_count >= response_required_count:
			_add_log("%s 的响应满足要求，本次【杀】被抵消。" % context.user.player_name)
			_handle_slash_dodged()
			return
		flow_state = FlowState.MULTI_RESPONSE
		_multi_response_origin = FlowState.RESPONDING_SLASH
		_bagua_attempted = false
		_emit_state()
		if context.user.is_ai:
			_schedule("_perform_ai_response", 0.35)
		return
	if context.effective_card_type != Card.CardType.SLASH:
		return
	match origin:
		FlowState.AOE_RESPONSE:
			_add_log("%s 打出【杀】，响应成功。" % context.user.player_name)
			_finish_nullifiable_effect()
		FlowState.DUEL_RESPONSE:
			response_received_count += 1
			_add_log("%s 在【决斗】中打出第 %d/%d 张【杀】。" % [
				context.user.player_name,
				response_received_count,
				response_required_count,
			])
			if response_received_count < response_required_count:
				flow_state = FlowState.MULTI_RESPONSE
				_multi_response_origin = FlowState.DUEL_RESPONSE
				_emit_state()
				if context.user.is_ai:
					_schedule("_perform_ai_response", 0.35)
				return
			var previous: BattlePlayer = _duel_responder
			_duel_responder = _duel_other
			_duel_other = previous
			_configure_duel_response()
		FlowState.BORROW_RESPONSE:
			var slash_target: BattlePlayer = _borrow_slash_target if _borrow_slash_target != null else _borrow_source
			_add_log("%s 响应【借刀杀人】，对 %s 使用【杀】。" % [
				_borrow_target.player_name,
				slash_target.player_name,
			])
			context.target = slash_target
			var nature: DamageNature = DamageNature.FIRE if _has_equipment(_borrow_target, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
			_start_slash_response(
				_borrow_target,
				slash_target,
				1,
				Callable(self, "_finish_nullifiable_effect"),
				nature,
				context
			)


func _configure_duel_response() -> void:
	var round_context := SkillUseContext.new(
		_duel_other,
		_duel_use_context.physical_cards if _duel_use_context != null else [],
		Card.CardType.DUEL,
		_duel_use_context.source_skill if _duel_use_context != null else null,
		_duel_responder,
		_duel_use_context.is_virtual if _duel_use_context != null else false,
		"【决斗】响应需求"
	)
	response_required_count = _response_requirement(round_context, _duel_responder)
	response_received_count = 0
	_response_card_type = Card.CardType.SLASH
	_multi_response_origin = FlowState.DUEL_RESPONSE
	flow_state = FlowState.MULTI_RESPONSE if response_required_count > 1 else FlowState.DUEL_RESPONSE
	if response_required_count > 1:
		_add_log("【无双】锁定技：%s 本轮【决斗】需要连续打出 %d 张【杀】。" % [
			_duel_responder.player_name,
			response_required_count,
		])
	_emit_state()
	if _duel_responder.is_ai:
		_schedule("_perform_ai_response", 0.45)


func _handle_slash_dodged() -> void:
	var attacker: BattlePlayer = pending_attacker
	if _has_equipment(attacker, Card.CardType.GREEN_DRAGON_BLADE) and _can_supply_slash(attacker):
		_pending_weapon_skill = Card.CardType.GREEN_DRAGON_BLADE
		_show_choices(attacker, ["发动【青龙偃月刀】继续出杀", "结束本次攻击"], Callable(self, "_resolve_after_dodge_weapon"))
		return
	if (
		_has_equipment(attacker, Card.CardType.ROCK_CLEAVING_AXE)
		and attacker.total_cards_in_hand_and_equipment() >= 2
	):
		_pending_weapon_skill = Card.CardType.ROCK_CLEAVING_AXE
		_show_choices(attacker, ["弃两张牌发动【贯石斧】", "结束本次攻击"], Callable(self, "_resolve_after_dodge_weapon"))
		return
	_add_log("本次【杀】被【闪】抵消。")
	_finish_attack()


func _resolve_after_dodge_weapon(option_index: int) -> void:
	if option_index != 0:
		_add_log("%s 放弃发动武器技能。" % pending_attacker.player_name)
		_finish_attack()
		return
	if _pending_weapon_skill == Card.CardType.GREEN_DRAGON_BLADE:
		_use_follow_up_slash()
	elif _pending_weapon_skill == Card.CardType.ROCK_CLEAVING_AXE:
		var axe_attacker: BattlePlayer = pending_attacker
		_discard_n_cards(
			axe_attacker, 2,
			Callable(self, "_finish_axe_discard").bind(axe_attacker)
		)


func _finish_axe_discard(discarded: Array[Card], attacker: BattlePlayer) -> void:
	if discarded.size() < 2:
		_add_log("可弃置牌不足，【贯石斧】发动失败。")
		_finish_attack()
		return
	_add_log("%s 弃置%s，发动【贯石斧】：【杀】依然命中。" % [
		attacker.player_name,
		_card_list_text(discarded),
	])
	_resolve_slash_damage()


func _use_follow_up_slash() -> void:
	var attacker: BattlePlayer = pending_attacker
	var target: BattlePlayer = pending_target
	var after: Callable = _attack_after
	var slash_index: int = attacker.find_card(Card.CardType.SLASH)
	if slash_index >= 0:
		var slash: Card = attacker.hand[slash_index]
		var follow_up_cards: Array[Card] = [slash]
		_move_cards(
			attacker, attacker, follow_up_cards, CardZone.PROCESSING, "使用【杀】追击",
			null, null, null,
			Callable(self, "_proceed_follow_up_slash").bind(attacker, target, after, follow_up_cards, true)
		)
		return
	var paid: Array[Card] = _consume_serpent_spear_cost(attacker)
	if paid.size() < 2:
		_finish_attack()
		return
	_move_cards(
		attacker, attacker, paid, CardZone.PROCESSING, "作为【丈八蛇矛】代价",
		null, null, null,
		Callable(self, "_proceed_follow_up_slash").bind(attacker, target, after, paid, false)
	)


func _proceed_follow_up_slash(attacker: BattlePlayer, target: BattlePlayer, after: Callable, paid_cards: Array[Card], is_physical: bool) -> void:
	var context: SkillUseContext = SkillUseContext.new(
		attacker,
		paid_cards,
		Card.CardType.SLASH,
		null,
		target,
		not is_physical,
		"青龙追杀"
	)
	_add_log("%s 发动【青龙偃月刀】，继续对 %s 使用【杀】。" % [attacker.player_name, target.player_name])
	var nature: DamageNature = DamageNature.FIRE if _has_equipment(attacker, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
	_start_slash_response(attacker, target, 1, after, nature, context)


func _resolve_slash_damage() -> void:
	if (
		not _ice_sword_checked
		and _has_equipment(pending_attacker, Card.CardType.ICE_SWORD)
		and pending_target.total_cards_in_hand_and_equipment() > 0
	):
		_ice_sword_checked = true
		_show_choices(
			pending_attacker,
			["发动【寒冰剑】防止伤害并弃其两张牌", "正常造成伤害"],
			Callable(self, "_resolve_ice_sword_choice")
		)
		return
	var ignore_for: BattlePlayer = pending_target if _slash_ignores_armor else null
	_start_damage(
		pending_attacker,
		pending_target,
		pending_damage,
		_attack_nature,
		Callable(self, "_after_slash_damage"),
		ignore_for,
		_attack_use_context,
		"【杀】"
	)


func _resolve_ice_sword_choice(option_index: int) -> void:
	if option_index == 0:
		var attacker: BattlePlayer = pending_attacker
		var target: BattlePlayer = pending_target
		_add_log("%s 发动【寒冰剑】，防止本次伤害并弃置 %s 的两张牌。" % [
			attacker.player_name,
			target.player_name,
		])
		_discard_n_cards(
			target, 2,
			Callable(self, "_finish_ice_sword_discard").bind(attacker, target)
		)
	else:
		_resolve_slash_damage()


func _finish_ice_sword_discard(discarded: Array[Card], attacker: BattlePlayer, target: BattlePlayer) -> void:
	if not discarded.is_empty():
		_add_log("【寒冰剑】弃置 %s 的%s。" % [target.player_name, _card_list_text(discarded)])
	_finish_attack()


func _after_slash_damage() -> void:
	if (
		pending_attacker != null
		and pending_target != null
		and _has_equipment(pending_attacker, Card.CardType.QILIN_BOW)
		and (pending_target.horse_plus != null or pending_target.horse_minus != null)
	):
		var labels: Array[String] = []
		_zone_choice_codes.clear()
		if pending_target.horse_plus != null:
			labels.append("弃置其【+1马】")
			_zone_choice_codes.append("horse_plus")
		if pending_target.horse_minus != null:
			labels.append("弃置其【-1马】")
			_zone_choice_codes.append("horse_minus")
		labels.append("不发动【麒麟弓】")
		_zone_choice_codes.append("pass")
		_show_choices(pending_attacker, labels, Callable(self, "_resolve_qilin_bow_choice"))
		return
	_finish_attack()


func _resolve_qilin_bow_choice(option_index: int) -> void:
	if option_index >= 0 and option_index < _zone_choice_codes.size():
		var code: String = _zone_choice_codes[option_index]
		var slot: int
		if code == "horse_plus":
			slot = EquipmentScript.Slot.HORSE_PLUS
		elif code == "horse_minus":
			slot = EquipmentScript.Slot.HORSE_MINUS
		else:
			_add_log("%s 不发动【麒麟弓】。" % pending_attacker.player_name)
			_finish_attack()
			return
		var removed: Card = pending_target.equipment_in_slot(slot)
		if removed != null:
			_add_log("%s 发动【麒麟弓】，弃置 %s 的【%s】。" % [
				pending_attacker.player_name,
				pending_target.player_name,
				removed.display_name,
			])
			_move_cards(
				pending_target, pending_attacker, [removed], CardZone.DISCARD,
				"被【麒麟弓】弃置", _attack_use_context.primary_physical_card() if _attack_use_context != null else null,
				null, null,
				Callable(self, "_finish_attack")
			)
			return
	_finish_attack()


func _finish_attack() -> void:
	var after: Callable = _attack_after
	_clear_attack_context()
	_call_safe(after)


func _clear_attack_context() -> void:
	pending_attacker = null
	pending_target = null
	pending_damage = 0
	_attack_after = Callable()
	_attack_nature = DamageNature.NORMAL
	_attack_use_context = null
	_slash_ignores_armor = false
	_ice_sword_checked = false
	_bagua_attempted = false
	_slash_dodge_forbidden = false
	response_required_count = 1
	response_received_count = 0
	_multi_response_origin = FlowState.IDLE


func _start_nullifiable_effect(
	card: Card,
	source: BattlePlayer,
	target: BattlePlayer,
	apply_callback: Callable,
	cancel_callback: Callable,
	finish_callback: Callable,
	harmful: bool
) -> void:
	_effect_card = card
	_effect_source = source
	_effect_target = target
	_effect_apply = apply_callback
	_effect_cancel = cancel_callback
	_effect_finish = finish_callback
	_effect_harmful = harmful
	_nullification_count = 0
	_nullification_passes = 0
	## 无懈可击链按行动顺序从来源的下一名存活角色开始，全员依次响应。
	_nullification_responder_index = next_living_player_index(player_index(source))
	flow_state = FlowState.NULLIFICATION_RESPONSE
	_add_log("【%s】即将对 %s 生效，进入【无懈可击】响应链。" % [card.rule_display_name(), target.player_name])
	_emit_state()
	if players[_nullification_responder_index].is_ai:
		_schedule("_perform_ai_nullification", 0.5)


func _play_nullification(responder: BattlePlayer, hand_index: int) -> void:
	if hand_index < 0 or hand_index >= responder.hand.size():
		return
	var nullification_card: Card = responder.hand[hand_index]
	_move_cards(
		responder,
		responder,
		[nullification_card],
		CardZone.PROCESSING,
		"使用【无懈可击】",
		_effect_card,
		null,
		null,
		Callable(self, "_apply_nullification_played").bind(responder)
	)


func _apply_nullification_played(responder: BattlePlayer) -> void:
	_nullification_count += 1
	_nullification_passes = 0
	_add_log("%s 使用【无懈可击】（链数 %d）。" % [responder.player_name, _nullification_count])
	_nullification_responder_index = next_living_player_index(_nullification_responder_index)
	flow_state = FlowState.NULLIFICATION_RESPONSE
	_emit_state()
	if players[_nullification_responder_index].is_ai:
		_schedule("_perform_ai_nullification", 0.45)


func _pass_nullification(responder: BattlePlayer) -> void:
	_add_log("%s 放弃使用【无懈可击】。" % responder.player_name)
	_nullification_passes += 1
	## 全员连续放弃（存活角色数）后才结算，死亡角色会被跳过。
	if _nullification_passes >= living_players().size():
		_finalize_nullification_chain()
		return
	_nullification_responder_index = next_living_player_index(_nullification_responder_index)
	flow_state = FlowState.NULLIFICATION_RESPONSE
	_emit_state()
	if players[_nullification_responder_index].is_ai:
		_schedule("_perform_ai_nullification", 0.35)


func _perform_ai_nullification() -> void:
	if flow_state != FlowState.NULLIFICATION_RESPONSE:
		return
	var responder: BattlePlayer = players[_nullification_responder_index]
	if not responder.is_ai:
		return
	var currently_enabled: bool = _nullification_count % 2 == 0
	var target_is_ai: bool = _effect_target == responder
	var desired_enabled: bool = target_is_ai != _effect_harmful
	var index: int = responder.find_card(Card.CardType.NULLIFICATION)
	if index >= 0 and currently_enabled != desired_enabled:
		_play_nullification(responder, index)
	else:
		_pass_nullification(responder)


func _finalize_nullification_chain() -> void:
	if _nullification_count % 2 == 0:
		_add_log("无懈链为偶数，【%s】对 %s 生效。" % [_effect_card.rule_display_name(), _effect_target.player_name])
		_call_safe(_effect_apply)
	else:
		_add_log("无懈链为奇数，【%s】对 %s 的效果被抵消。" % [_effect_card.rule_display_name(), _effect_target.player_name])
		_call_safe(_effect_cancel)


func _finish_nullifiable_effect() -> void:
	var finish: Callable = _effect_finish
	_effect_card = null
	_effect_source = null
	_effect_target = null
	_effect_apply = Callable()
	_effect_cancel = Callable()
	_effect_finish = Callable()
	_call_safe(finish)


func _apply_draw_two() -> void:
	draw_cards(_effect_target, 2)
	_add_log("%s 因【无中生有】摸两张牌。" % _effect_target.player_name)
	_finish_nullifiable_effect()


func _apply_dismantle() -> void:
	var target: BattlePlayer = _effect_target
	_zone_choice_codes.clear()
	var labels: Array[String] = []
	if not target.hand.is_empty():
		_zone_choice_codes.append("hand")
		labels.append("弃置其随机手牌")
	for entry: Dictionary in _equipment_choice_entries(target):
		_zone_choice_codes.append(entry["code"])
		labels.append("弃置%s【%s】" % [entry["slot_name"], (entry["card"] as Card).display_name])
	if labels.size() == 1:
		_resolve_dismantle_choice(0)
	else:
		_show_choices(_effect_source, labels, Callable(self, "_resolve_dismantle_choice"))


func _resolve_dismantle_choice(option_index: int) -> void:
	if option_index < 0 or option_index >= _zone_choice_codes.size():
		_finish_nullifiable_effect()
		return
	var code: String = _zone_choice_codes[option_index]
	if code == "hand" and not _effect_target.hand.is_empty():
		var index: int = randi_range(0, _effect_target.hand.size() - 1)
		var removed: Card = _effect_target.hand[index]
		_add_log("%s 随机弃置了 %s 的一张手牌。" % [_effect_source.player_name, _effect_target.player_name])
		_move_cards(
			_effect_target, _effect_source, [removed], CardZone.DISCARD,
			"被【过河拆桥】弃置", _effect_card, null, null,
			Callable(self, "_finish_nullifiable_effect")
		)
		return
	var slot: int = _slot_from_code(code)
	var equipment: Card = _effect_target.equipment_in_slot(slot)
	if equipment != null:
		_add_log("%s 弃置了 %s 的【%s】。" % [
			_effect_source.player_name,
			_effect_target.player_name,
			equipment.display_name,
		])
		_move_cards(
			_effect_target, _effect_source, [equipment], CardZone.DISCARD,
			"被【过河拆桥】弃置", _effect_card, null, null,
			Callable(self, "_finish_nullifiable_effect")
		)
		return
	_finish_nullifiable_effect()


func _apply_steal() -> void:
	if _effect_target.hand.is_empty():
		_add_log("目标已无手牌，【顺手牵羊】无可获得之牌。")
		_finish_nullifiable_effect()
		return
	var index: int = randi_range(0, _effect_target.hand.size() - 1)
	var stolen: Card = _effect_target.hand[index]
	_add_log("%s 从 %s 获得一张手牌。" % [_effect_source.player_name, _effect_target.player_name])
	_move_cards(
		_effect_target, _effect_source, [stolen], CardZone.HAND,
		"被【顺手牵羊】获得", _effect_card, null, _effect_source,
		Callable(self, "_finish_nullifiable_effect")
	)


func _apply_duel() -> void:
	_duel_responder = _effect_target
	_duel_other = _effect_source
	_duel_use_context = _active_use_context
	if _duel_use_context == null:
		_duel_use_context = SkillUseContext.new(
			_effect_source,
			[_effect_card] if _effect_card != null else [],
			Card.CardType.DUEL,
			null,
			_effect_target,
			false,
			"【决斗】"
		)
	_add_log("【决斗】开始，由 %s 先打出【杀】。" % _duel_responder.player_name)
	_configure_duel_response()


func _apply_borrow_sword() -> void:
	_borrow_source = _effect_source
	_borrow_target = _effect_target
	_borrow_slash_target = null
	_pending_borrow_slash_target = false
	if _borrow_target.weapon == null:
		_add_log("目标已失去武器，【借刀杀人】结束。")
		_finish_nullifiable_effect()
		return
	## 人类使用借刀杀人时，可指定“被出杀”的目标角色；候选多于一个时进入选择，
	## 只有一个候选（如 1v1）时自动指定，保持旧体验。
	if _borrow_source == player1:
		var candidates: Array[BattlePlayer] = _borrow_designated_candidates()
		if candidates.size() > 1:
			_pending_borrow_slash_target = true
			flow_state = FlowState.SELECTING_TARGET
			_add_log("请选择【借刀杀人】指定出【杀】的目标角色。")
			_emit_state()
			return
		_borrow_slash_target = candidates[0] if not candidates.is_empty() else _borrow_source
	else:
		## AI 使用借刀杀人：总是指定自己。
		_borrow_slash_target = _borrow_source
	_enter_borrow_response()


## 借刀杀人“被出杀”目标：武器持有者攻击范围内的其他存活角色。
func _borrow_designated_candidates() -> Array[BattlePlayer]:
	var result: Array[BattlePlayer] = []
	if _borrow_target == null:
		return result
	for player: BattlePlayer in living_players():
		if player != _borrow_target and can_slash_target(_borrow_target, player):
			result.append(player)
	return result


func _resolve_borrow_slash_target(target_index: int) -> void:
	if not _pending_borrow_slash_target:
		return
	_pending_borrow_slash_target = false
	if target_index < 0 or target_index >= players.size():
		_finish_nullifiable_effect()
		return
	var target: BattlePlayer = players[target_index]
	if (
		target == null or target.is_dying()
		or target == _borrow_target
		or not can_slash_target(_borrow_target, target)
	):
		_reject("该角色不是【借刀杀人】指定出【杀】的合法目标。")
		_pending_borrow_slash_target = true
		return
	_borrow_slash_target = target
	_enter_borrow_response()


func _enter_borrow_response() -> void:
	if _borrow_slash_target == null:
		_borrow_slash_target = _borrow_source
	flow_state = FlowState.BORROW_RESPONSE
	_emit_state()
	if _borrow_target.is_ai:
		_schedule("_perform_ai_response", 0.55)
	else:
		var labels: Array[String] = []
		if _can_supply_slash(_borrow_target):
			labels.append("对 %s 打出【杀】" % _borrow_slash_target.player_name)
		labels.append("交出武器")
		_show_choices(_borrow_target, labels, Callable(self, "_resolve_borrow_choice"))


func _resolve_borrow_choice(option_index: int) -> void:
	if choice_labels.size() == 1 or option_index == 0:
		_borrow_use_slash()
	else:
		_borrow_give_weapon()


func _borrow_use_slash() -> void:
	var slash_index: int = _borrow_target.find_card(Card.CardType.SLASH)
	if slash_index < 0:
		if can_use_serpent_spear(_borrow_target):
			_use_serpent_spear(_borrow_target)
			return
		_borrow_give_weapon()
		return
	var slash: Card = _borrow_target.hand[slash_index]
	var slash_target: BattlePlayer = _borrow_slash_target if _borrow_slash_target != null else _borrow_source
	var context := SkillUseContext.new(
		_borrow_target,
		[slash],
		Card.CardType.SLASH,
		null,
		slash_target,
		false,
		"【借刀杀人】响应"
	)
	_move_cards(
		_borrow_target,
		slash_target,
		[slash],
		CardZone.PROCESSING,
		"打出【杀】响应【借刀杀人】",
		_effect_card,
		null,
		null,
		Callable(self, "_accept_effective_response").bind(context, FlowState.BORROW_RESPONSE)
	)


func _borrow_give_weapon() -> void:
	var weapon: Card = _borrow_target.weapon
	if weapon != null:
		_move_cards(
			_borrow_target,
			_borrow_source,
			[weapon],
			CardZone.HAND,
			"因【借刀杀人】交出",
			_effect_card,
			null,
			_borrow_source,
			Callable(self, "_finish_borrow_weapon_given").bind(weapon)
		)
	else:
		_finish_nullifiable_effect()


func _finish_borrow_weapon_given(weapon: Card) -> void:
	_add_log("%s 未出【杀】，将武器【%s】交给 %s。" % [
		_borrow_target.player_name,
		weapon.display_name,
		_borrow_source.player_name,
	])
	_finish_nullifiable_effect()


func _apply_fire_attack() -> void:
	_fire_source = _effect_source
	_fire_target = _effect_target
	if _fire_target.hand.is_empty():
		_add_log("%s 已无手牌，【火攻】结束。" % _fire_target.player_name)
		_finish_nullifiable_effect()
		return
	if _fire_target.is_ai:
		var index: int = randi_range(0, _fire_target.hand.size() - 1)
		_reveal_for_fire_attack(_fire_target.hand[index])
	else:
		flow_state = FlowState.FIRE_REVEAL
		_emit_state()


func _reveal_for_fire_attack(card: Card) -> void:
	_fire_revealed_card = card
	_add_log("%s 为【火攻】展示了%s。" % [_fire_target.player_name, card.identity_text()])
	if _fire_source.is_ai:
		flow_state = FlowState.FIRE_DISCARD
		_emit_state()
		_schedule("_perform_ai_fire_discard", 0.5)
	else:
		flow_state = FlowState.FIRE_DISCARD
		_emit_state()


func _perform_ai_fire_discard() -> void:
	if _fire_source == null or _fire_revealed_card == null:
		return
	for index: int in _fire_source.hand.size():
		if _fire_source.hand[index].suit == _fire_revealed_card.suit:
			_consume_hand_card(_fire_source, index)
			return
	_add_log("%s 没有同花色牌，【火攻】未造成伤害。" % _fire_source.player_name)
	_finish_nullifiable_effect()


func _start_global_trick(card: Card, source: BattlePlayer) -> void:
	_global_card = card
	_global_source = source
	_global_targets.clear()
	_global_index = 0
	match card.card_type:
		Card.CardType.BARBARIAN_INVASION, Card.CardType.ARROW_BARRAGE:
			_global_targets = _other_living_players(source)
		Card.CardType.PEACH_GARDEN, Card.CardType.AMAZING_GRACE:
			_global_targets = _all_living_players_ordered_from(source)
	if card.card_type == Card.CardType.AMAZING_GRACE:
		revealed_cards.clear()
		for _index: int in _global_targets.size():
			var revealed: Card = _draw_one_from_pile()
			if revealed != null:
				revealed_cards.append(revealed)
		_add_log("【五谷丰登】亮出：%s。" % _card_list_text(revealed_cards))
		var order_names: PackedStringArray = []
		for player: BattlePlayer in _global_targets:
			order_names.append(player.player_name)
		_add_log("【五谷丰登】选择顺序：%s（使用者优先）。" % " → ".join(order_names))
	_process_next_global_target()


func _process_next_global_target() -> void:
	if _global_index >= _global_targets.size():
		if _global_card != null and _global_card.card_type == Card.CardType.AMAZING_GRACE:
			for leftover: Card in revealed_cards:
				discard_pile.append(leftover)
			revealed_cards.clear()
		_global_card = null
		_global_source = null
		_global_targets.clear()
		_return_to_play()
		return
	var target: BattlePlayer = _global_targets[_global_index]
	_global_index += 1
	var harmful: bool = _global_card.card_type in [Card.CardType.BARBARIAN_INVASION, Card.CardType.ARROW_BARRAGE]
	var apply: Callable
	match _global_card.card_type:
		Card.CardType.BARBARIAN_INVASION:
			apply = Callable(self, "_apply_aoe").bind(Card.CardType.SLASH)
		Card.CardType.ARROW_BARRAGE:
			apply = Callable(self, "_apply_aoe").bind(Card.CardType.DODGE)
		Card.CardType.PEACH_GARDEN:
			apply = Callable(self, "_apply_peach_garden")
		Card.CardType.AMAZING_GRACE:
			apply = Callable(self, "_apply_amazing_grace")
	_start_nullifiable_effect(
		_global_card,
		_global_source,
		target,
		apply,
		Callable(self, "_finish_nullifiable_effect"),
		Callable(self, "_process_next_global_target"),
		harmful
	)


func _apply_aoe(required_type: Card.CardType) -> void:
	_response_card_type = required_type
	pending_target = _effect_target
	_bagua_attempted = false
	if _has_equipment(pending_target, Card.CardType.VINE_ARMOR):
		_add_log("【藤甲】锁定技：【%s】对 %s 无效。" % [_effect_card.display_name, pending_target.player_name])
		_finish_nullifiable_effect()
		return
	flow_state = FlowState.AOE_RESPONSE
	_emit_state()
	if pending_target.is_ai:
		_schedule("_perform_ai_response", 0.5)


func _resolve_bagua_judgement(defender: BattlePlayer) -> void:
	if not can_use_bagua(defender):
		return
	_bagua_attempted = true
	_start_judgement(&"bagua", defender, Callable(self, "_evaluate_bagua"), Callable(self, "_after_bagua").bind(defender))


func _evaluate_bagua(context: JudgementContextScript) -> void:
	context.result_data["success"] = context.effective_card.is_red()
	_add_log("%s 发动【八卦阵】，最终判定为%s（%s）。" % [context.judged_player.player_name, context.effective_card.identity_text(), "红色" if context.effective_card.is_red() else "黑色"])


func _after_bagua(context: JudgementContextScript, defender: BattlePlayer) -> void:
	if bool(context.result_data.get("success", false)):
		_add_log("【八卦阵】判定成功，视为 %s 打出一张【闪】。" % defender.player_name)
		if _is_slash_dodge_response(defender):
			## 天妒等判定后触发会把 flow 留在 SKILL_RESOLVING，先恢复闪响应状态再结算。
			_restore_slash_response_state(defender)
			var response_context := SkillUseContext.new(
				defender,
				[],
				Card.CardType.DODGE,
				null,
				pending_attacker,
				true,
				"【八卦阵】"
			)
			_accept_effective_response(response_context, FlowState.RESPONDING_SLASH)
		elif _effect_target == defender or flow_state == FlowState.AOE_RESPONSE:
			_finish_nullifiable_effect()
	else:
		_add_log("【八卦阵】判定失败，仍可从手牌打出【闪】。")
		_restore_slash_response_state(defender)
		_emit_state()
		if defender.is_ai:
			_schedule("_perform_ai_response", 0.35)


## 当前是否仍处于【杀】的闪响应上下文（flow 可能因判定后触发暂为 SKILL_RESOLVING）。
func _is_slash_dodge_response(defender: BattlePlayer) -> bool:
	return (
		defender != null
		and pending_target == defender
		and pending_attacker != null
		and _response_card_type == Card.CardType.DODGE
		and _multi_response_origin == FlowState.RESPONDING_SLASH
	)


## 根据存储的杀响应上下文恢复 RESPONDING_SLASH/MULTI_RESPONSE 状态。
func _restore_slash_response_state(defender: BattlePlayer) -> void:
	if not _is_slash_dodge_response(defender):
		return
	flow_state = FlowState.MULTI_RESPONSE if response_required_count > 1 else FlowState.RESPONDING_SLASH


func _apply_peach_garden() -> void:
	var old_hp: int = _effect_target.hp
	_effect_target.recover(1)
	_add_log("%s 因【桃园结义】回复 %d 点体力。" % [_effect_target.player_name, _effect_target.hp - old_hp])
	_finish_nullifiable_effect()


func _apply_amazing_grace() -> void:
	if revealed_cards.is_empty():
		_finish_nullifiable_effect()
		return
	_revealed_selecting_player = _effect_target
	flow_state = FlowState.CHOOSING_REVEALED
	_emit_state()
	if _revealed_selecting_player.is_ai:
		_schedule("_perform_ai_amazing_grace", 0.45)


func _perform_ai_amazing_grace() -> void:
	if revealed_cards.is_empty():
		_finish_nullifiable_effect()
		return
	if _revealed_selecting_player == null or not _revealed_selecting_player.is_ai:
		## 高倍速下可能已被上一次选牌清空；等新定时器/看门狗，避免对 Nil 出牌。
		return
	var best_index: int = 0
	var best_score: int = -999
	for index: int in revealed_cards.size():
		var score: int = _ai_card_value(revealed_cards[index])
		if score > best_score:
			best_score = score
			best_index = index
	_take_amazing_grace_card(best_index)


func _take_amazing_grace_card(card_index: int) -> void:
	if card_index < 0 or card_index >= revealed_cards.size():
		return
	var chosen: Card = revealed_cards.pop_at(card_index)
	_revealed_selecting_player.add_card(chosen)
	_add_log("%s 从【五谷丰登】获得%s。" % [_revealed_selecting_player.player_name, chosen.identity_text()])
	_revealed_selecting_player = null
	_finish_nullifiable_effect()


func _iron_chain_options(user: BattlePlayer) -> Array[Dictionary]:
	var options: Array[Dictionary] = [{"code": "self", "label": "切换自己连环"}]
	if user.is_ai:
		## 全 AI 模式下 player1 也可能是 AI，统一按“谁在使用”决定对手。
		var rival: BattlePlayer = _default_attack_target(user)
		if rival != null:
			options.append({"code": "enemy", "label": "切换玩家连环", "target": rival})
	else:
		for enemy: BattlePlayer in living_enemies():
			options.append({"code": "enemy", "label": "切换%s连环" % enemy.player_name, "target": enemy})
	## 1v1 兼容：保持原有“自己/对手/双方/重铸”选项顺序，避免依赖旧索引的测试与旧习惯被破坏。
	if not user.is_ai and living_enemies().size() == 1:
		var rival: BattlePlayer = first_living_enemy()
		if rival != null:
			return [
				{"code": "self", "label": "切换自己连环"},
				{"code": "enemy", "label": "切换对手连环", "target": rival},
				{"code": "both", "label": "切换双方连环", "target": rival},
				{"code": "recast", "label": "重铸（摸一张）"},
			]
	if not _other_living_players(user).is_empty():
		options.append({"code": "all", "label": "切换所有其他角色连环"})
	options.append({"code": "recast", "label": "重铸（摸一张）"})
	return options


func _begin_iron_chain_choice(user: BattlePlayer, hand_index: int) -> void:
	selected_hand_index = hand_index
	_iron_chain_options_cache = _iron_chain_options(user)
	choice_labels.clear()
	for option: Dictionary in _iron_chain_options_cache:
		choice_labels.append(option["label"])
	choice_owner = user
	_choice_handler = Callable(self, "_resolve_iron_chain_choice")
	flow_state = FlowState.CHOOSING_OPTION
	_emit_state()


func _resolve_iron_chain_choice(option_index: int) -> void:
	var user: BattlePlayer = current_player()
	if selected_hand_index < 0 or selected_hand_index >= user.hand.size():
		_return_to_play()
		return
	var card: Card = user.hand[selected_hand_index]
	selected_hand_index = -1
	_move_cards(
		user, user, [card], CardZone.PROCESSING, "使用【铁索连环】",
		null, null, null,
		Callable(self, "_proceed_iron_chain_use").bind(user, card, option_index)
	)


func _proceed_iron_chain_use(user: BattlePlayer, card: Card, option_index: int) -> void:
	_active_use_context = SkillUseContext.new(
		user, [card], Card.CardType.IRON_CHAIN, null, null, false, "【铁索连环】"
	)
	if option_index < 0 or option_index >= _iron_chain_options_cache.size():
		_return_to_play()
		return
	var option: Dictionary = _iron_chain_options_cache[option_index]
	if option.get("code", "") == "recast":
		draw_cards(user, 1)
		_add_log("%s 重铸【铁索连环】，摸一张牌。" % user.player_name)
		_return_to_play()
		return
	var targets: Array[BattlePlayer] = []
	match option.get("code", ""):
		"self":
			targets = [user]
		"human", "enemy":
			var chosen: BattlePlayer = option.get("target", null)
			if chosen != null and not chosen.is_dying():
				targets = [chosen]
		"both":
			targets = [user]
			var rival: BattlePlayer = option.get("target", null)
			if rival != null and not rival.is_dying():
				targets.append(rival)
		"all":
			targets = _other_living_players(user)
	var continuation: Callable = Callable(self, "_start_iron_chain").bind(card, user, targets)
	_enqueue_triggers(&"after_trick_use", _active_use_context, [user], continuation)


func _start_iron_chain(card: Card, source: BattlePlayer, targets: Array[BattlePlayer]) -> void:
	_chain_card = card
	_chain_source = source
	_chain_targets = targets
	_chain_index = 0
	_add_log("%s 使用【铁索连环】，指定 %d 名角色。" % [source.player_name, targets.size()])
	_process_next_chain_target()


func _process_next_chain_target() -> void:
	if _chain_index >= _chain_targets.size():
		_chain_card = null
		_chain_source = null
		_chain_targets.clear()
		_return_to_play()
		return
	var target: BattlePlayer = _chain_targets[_chain_index]
	_chain_index += 1
	_start_nullifiable_effect(
		_chain_card,
		_chain_source,
		target,
		Callable(self, "_apply_chain_toggle"),
		Callable(self, "_finish_nullifiable_effect"),
		Callable(self, "_process_next_chain_target"),
		not target.chained
	)


func _apply_chain_toggle() -> void:
	_effect_target.chained = not _effect_target.chained
	_add_log("%s 的连环状态变为：%s。" % [_effect_target.player_name, "横置" if _effect_target.chained else "重置"])
	_finish_nullifiable_effect()


func _start_delayed_placement(card: Card, source: BattlePlayer, target: BattlePlayer) -> void:
	_add_log("%s 对 %s 使用延时锦囊%s。" % [source.player_name, target.player_name, card.identity_text()])
	_effect_card = card
	_start_nullifiable_effect(
		card,
		source,
		target,
		Callable(self, "_apply_delayed_placement"),
		Callable(self, "_cancel_delayed_placement"),
		Callable(self, "_return_to_play"),
		true
	)


func _apply_delayed_placement() -> void:
	var card: Card = _effect_card
	if _effect_target.add_delayed_trick(card):
		_remove_processing_card(card)
		_add_log("【%s】置入 %s 的判定区。" % [card.rule_display_name(), _effect_target.player_name])
	else:
		_settle_processing_card(card)
		_add_log("判定区已有同名牌，【%s】进入弃牌堆。" % card.rule_display_name())
	_finish_nullifiable_effect()


func _cancel_delayed_placement() -> void:
	_settle_processing_card(_effect_card)
	_finish_nullifiable_effect()


func _show_choices(owner: BattlePlayer, labels: Array[String], handler: Callable) -> void:
	choice_owner = owner
	choice_labels = labels
	_choice_handler = handler
	flow_state = FlowState.CHOOSING_OPTION
	_emit_state()
	if owner.is_ai:
		_schedule("_perform_ai_choice", 0.4)


func _perform_ai_choice() -> void:
	if flow_state != FlowState.CHOOSING_OPTION or choice_owner == null or not choice_owner.is_ai:
		return
	var handler: Callable = _choice_handler
	choice_labels.clear()
	_choice_handler = Callable()
	handler.call(0)


func _begin_turn() -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	## 防御性兜底：回合切换时若已满足胜负条件（如闪电/延时伤害造成全灭），直接结算。
	if check_battle_result():
		return
	turn_number += 1
	var active: BattlePlayer = current_player()
	active.reset_turn_flags()
	for skill: Skill in active.skills:
		skill.on_turn_reset(self, active)
		skill.on_turn_start(self, active)
	_skip_draw_phase = false
	_skip_play_phase = false

	phase = Phase.START
	flow_state = FlowState.IDLE
	_add_log("—— 第 %d 回合：%s 的回合 ——" % [turn_number, active.player_name])
	_add_log("开始阶段。")
	_emit_state()
	_enqueue_triggers(&"start_phase", RefCounted.new(), [active], Callable(self, "_begin_judgement_phase"))


func _begin_judgement_phase() -> void:
	phase = Phase.JUDGEMENT
	_judgement_queue = current_player().delayed_tricks_in_judgement_order()
	_judgement_index = 0
	if _judgement_queue.is_empty():
		_add_log("判定阶段：判定区为空。")
		_finish_judgement_phase()
	else:
		_add_log("判定阶段：共有 %d 张延时锦囊待结算。" % _judgement_queue.size())
		_process_next_judgement()


func _process_next_judgement() -> void:
	if _judgement_index >= _judgement_queue.size():
		_finish_judgement_phase()
		return
	_judging_card = _judgement_queue[_judgement_index]
	_judgement_index += 1
	if not current_player().has_delayed_trick(_judging_card.rule_card_type()):
		_process_next_judgement()
		return
	_start_nullifiable_effect(
		_judging_card,
		current_player(),
		current_player(),
		Callable(self, "_perform_judgement"),
		Callable(self, "_cancel_delayed_judgement"),
		Callable(self, "_process_next_judgement"),
		true
	)


func _perform_judgement() -> void:
	_judged_delayed_card = current_player().remove_delayed_trick(_judging_card.rule_card_type())
	if _judged_delayed_card == null:
		_finish_nullifiable_effect()
		return
	_start_judgement(
		StringName("delayed_%d" % int(_judged_delayed_card.rule_card_type())),
		current_player(),
		Callable(self, "_evaluate_delayed_judgement"),
		Callable(self, "_after_delayed_judgement")
	)


func _evaluate_delayed_judgement(context: JudgementContextScript) -> void:
	var result: Card = context.effective_card
	_add_log("【%s】最终判定牌为%s。" % [_judged_delayed_card.rule_display_name(), result.identity_text()])
	match _judged_delayed_card.rule_card_type():
		Card.CardType.INDULGENCE:
			context.result_data["indulgence_miss"] = result.suit != Card.Suit.HEART
		Card.CardType.SUPPLY_SHORTAGE:
			context.result_data["supply_miss"] = result.suit != Card.Suit.CLUB
		Card.CardType.LIGHTNING:
			context.result_data["lightning_hit"] = result.suit == Card.Suit.SPADE and result.rank >= 2 and result.rank <= 9


func _after_delayed_judgement(context: JudgementContextScript) -> void:
	var delayed: Card = _judged_delayed_card
	_judged_delayed_card = null
	if delayed == null:
		_finish_nullifiable_effect()
		return
	match delayed.rule_card_type():
		Card.CardType.INDULGENCE:
			discard_pile.append(delayed)
			if bool(context.result_data.get("indulgence_miss", false)):
				_skip_play_phase = true
				_add_log("判定不为红桃：%s 跳过出牌阶段。" % current_player().player_name)
			else: _add_log("判定为红桃：【乐不思蜀】未生效。")
			_finish_nullifiable_effect()
		Card.CardType.SUPPLY_SHORTAGE:
			discard_pile.append(delayed)
			if bool(context.result_data.get("supply_miss", false)):
				_skip_draw_phase = true
				_add_log("判定不为梅花：%s 跳过摸牌阶段。" % current_player().player_name)
			else: _add_log("判定为梅花：【兵粮寸断】未生效。")
			_finish_nullifiable_effect()
		Card.CardType.LIGHTNING:
			if bool(context.result_data.get("lightning_hit", false)):
				## 闪电牌进入处理区并作为伤害来源实体牌传入，使【奸雄】等可以获取。
				_move_card_to_processing(delayed)
				_add_log("黑桃 2~9：【闪电】命中！")
				var lightning_context := SkillUseContext.new(
					null,
					[delayed],
					Card.CardType.LIGHTNING,
					null,
					current_player(),
					false,
					"【闪电】"
				)
				_start_damage(
					null,
					current_player(),
					3,
					DamageNature.THUNDER,
					Callable(self, "_finish_nullifiable_effect"),
					null,
					lightning_context,
					"【闪电】"
				)
			else:
				_pass_lightning(delayed)
				_finish_nullifiable_effect()


func _start_judgement(
	reason: StringName,
	judged_player: BattlePlayer,
	result_handler: Callable,
	continuation: Callable
) -> void:
	var card: Card = _draw_one_from_pile()
	if card == null:
		_add_log("牌堆中没有可用于判定的牌，判定流程安全结束。")
		var empty_context := JudgementContextScript.new(reason, judged_player, null)
		if continuation.is_valid():
			continuation.call(empty_context)
		return
	judgement_context = JudgementContextScript.new(reason, judged_player, card)
	_judgement_result_handler = result_handler
	_judgement_continue = continuation
	_judgement_guicai_owners.clear()
	## 鬼才改判窗口按行动顺序遍历全部存活角色（不再假设只有两人）。
	for player: BattlePlayer in _all_living_players_ordered_from(judged_player):
		if player.has_skill(&"guicai") and player.hp > 0:
			_judgement_guicai_owners.append(player)
	_judgement_guicai_index = 0
	_add_log("%s 的判定翻出%s，进入改判窗口。" % [judged_player.player_name, card.identity_text()])
	_offer_next_guicai()


func _offer_next_guicai() -> void:
	while _judgement_guicai_index < _judgement_guicai_owners.size():
		var owner: BattlePlayer = _judgement_guicai_owners[_judgement_guicai_index]
		_judgement_guicai_index += 1
		var skill: Skill = owner.get_skill(&"guicai")
		if skill == null or not skill.can_trigger(judgement_context, self, owner):
			continue
		judgement_context.offered_guicai_owners.append(owner.general_id)
		skill_owner = owner
		skill_actor = owner
		pending_skill = skill
		flow_state = FlowState.JUDGEMENT_REPLACE
		_add_log("%s 可以发动【鬼才】：当前判定牌为%s。" % [owner.player_name, judgement_context.effective_card.identity_text()])
		_emit_state()
		if owner.is_ai:
			_schedule("_perform_ai_guicai", 0.25)
		return
	_finish_judgement_replacement_window()


func request_judgement_replace(hand_index: int) -> void:
	if flow_state != FlowState.JUDGEMENT_REPLACE or skill_actor == null or skill_actor.is_ai:
		return
	if hand_index < 0 or hand_index >= skill_actor.hand.size():
		return
	_apply_guicai_card(skill_actor, hand_index)


func request_pass_judgement_replace() -> void:
	if flow_state != FlowState.JUDGEMENT_REPLACE or skill_actor == null or skill_actor.is_ai:
		return
	_add_log("%s 放弃发动【鬼才】。" % skill_actor.player_name)
	_clear_skill_context()
	_offer_next_guicai()


func _perform_ai_guicai() -> void:
	if flow_state != FlowState.JUDGEMENT_REPLACE or skill_actor == null or not skill_actor.is_ai:
		return
	var best_index: int = _ai_guicai_card_index(skill_actor, judgement_context)
	if best_index >= 0:
		_apply_guicai_card(skill_actor, best_index)
	else:
		_add_log("%s 判断改判无益，放弃【鬼才】。" % skill_actor.player_name)
		_clear_skill_context()
		_offer_next_guicai()


func _apply_guicai_card(owner: BattlePlayer, hand_index: int) -> void:
	var replacement: Card = owner.remove_card_at(hand_index)
	var old: Card = judgement_context.replace_with(owner, replacement)
	discard_pile.append(old)
	owner.record_skill_use(owner.get_skill(&"guicai"))
	_add_log("%s 发动【鬼才】，打出%s替换%s；原判定牌进入弃牌堆。" % [owner.player_name, replacement.identity_text(), old.identity_text()])
	_clear_skill_context()
	_offer_next_guicai()


func _ai_guicai_card_index(owner: BattlePlayer, context: JudgementContextScript) -> int:
	var current_good: bool = _judgement_is_good_for(context.effective_card, context.reason, context.judged_player)
	var wants_good: bool = context.judged_player == owner
	for index: int in owner.hand.size():
		var candidate_good: bool = _judgement_is_good_for(owner.hand[index], context.reason, context.judged_player)
		if candidate_good == wants_good and candidate_good != current_good:
			return index
	return -1


func _judgement_is_good_for(card: Card, reason: StringName, _judged: BattlePlayer) -> bool:
	if card == null: return false
	var key: String = String(reason)
	if key.begins_with("delayed_%d" % int(Card.CardType.INDULGENCE)): return card.suit == Card.Suit.HEART
	if key.begins_with("delayed_%d" % int(Card.CardType.SUPPLY_SHORTAGE)): return card.suit == Card.Suit.CLUB
	if key.begins_with("delayed_%d" % int(Card.CardType.LIGHTNING)): return not (card.suit == Card.Suit.SPADE and card.rank >= 2 and card.rank <= 9)
	if reason == &"bagua": return card.is_red()
	if reason == &"ganglie": return card.suit == Card.Suit.HEART
	if reason == &"luoshen": return card.is_black()
	return false


func _finish_judgement_replacement_window() -> void:
	_clear_skill_context()
	if judgement_context == null:
		return
	if _judgement_result_handler.is_valid():
		_judgement_result_handler.call(judgement_context)
	_enqueue_triggers(&"after_judgement", judgement_context, [judgement_context.judged_player], Callable(self, "_finalize_judgement_card"))


func _finalize_judgement_card() -> void:
	var context: JudgementContextScript = judgement_context
	if context == null:
		return
	var card: Card = context.effective_card
	if context.final_owner != null:
		context.final_owner.add_card(card)
		_add_log("最终判定牌%s进入%s的手牌。" % [card.identity_text(), context.final_owner.player_name])
	else:
		discard_pile.append(card)
		_add_log("最终判定牌%s进入弃牌堆。" % card.identity_text())
	var continuation: Callable = _judgement_continue
	judgement_context = null
	_judgement_result_handler = Callable()
	_judgement_continue = Callable()
	if continuation.is_valid():
		continuation.call(context)


func _cancel_delayed_judgement() -> void:
	var card: Card = current_player().remove_delayed_trick(_judging_card.rule_card_type())
	if card != null and card.rule_card_type() == Card.CardType.LIGHTNING:
		_pass_lightning(card)
	elif card != null:
		discard_pile.append(card)
	_add_log("【%s】本次判定效果被【无懈可击】抵消。" % _judging_card.rule_display_name())
	_finish_nullifiable_effect()


func _pass_lightning(card: Card) -> void:
	var next: BattlePlayer = _next_living_player_after(current_player())
	if next == null:
		next = current_player()
	if not next.has_delayed_trick(Card.CardType.LIGHTNING):
		next.add_delayed_trick(card)
		_add_log("【闪电】未命中，传递到 %s 的判定区。" % next.player_name)
	else:
		discard_pile.append(card)
		_add_log("下一名角色已有【闪电】，此【闪电】进入弃牌堆。")


func _finish_judgement_phase() -> void:
	phase = Phase.DRAW
	if _skip_draw_phase:
		_add_log("摸牌阶段被【兵粮寸断】跳过。")
		_finish_draw_phase()
		return
	_draw_context = DrawContext.new(current_player(), 2)
	_enqueue_triggers(&"before_draw", _draw_context, [current_player()], Callable(self, "_resolve_draw_context"))


func _resolve_draw_context() -> void:
	if _draw_context == null:
		_finish_draw_phase()
		return
	if not _draw_context.draw_replaced:
		draw_cards(_draw_context.player, _draw_context.final_count)
		_add_log("摸牌阶段：%s 摸 %d 张牌。" % [
			_draw_context.player.player_name,
			_draw_context.final_count,
		])
	_draw_context = null
	_finish_draw_phase()


func _finish_draw_phase() -> void:
	phase = Phase.PLAY
	if _skip_play_phase:
		_add_log("出牌阶段被【乐不思蜀】跳过。")
		_enter_discard_phase()
		return
	flow_state = FlowState.PLAY_ACTIVE
	_add_log("进入出牌阶段。")
	_emit_state()
	if current_player().is_ai:
		_schedule("_perform_ai_play", 0.6)


func _start_damage(
	source: BattlePlayer,
	target: BattlePlayer,
	amount: int,
	nature: DamageNature,
	after: Callable,
	ignore_armor_for: BattlePlayer = null,
	use_context: SkillUseContext = null,
	reason: String = ""
) -> void:
	_damage_after = after
	_damage_queue.clear()
	var source_card: Card = use_context.primary_physical_card() if use_context != null else null
	var effective_type: int = int(use_context.effective_card_type) if use_context != null else -1
	var base_context := DamageContext.new(
		source,
		target,
		amount,
		nature,
		source_card,
		effective_type,
		reason,
		false
	)
	if use_context != null:
		base_context.source_cards.clear()
		base_context.source_cards.append_array(use_context.physical_cards)
		base_context.card_user = use_context.user
	base_context.ignore_armor = target == ignore_armor_for
	if source != null:
		for skill: Skill in source.skills:
			var before: int = base_context.amount
			base_context.amount = skill.modify_damage_amount(base_context, base_context.amount, self, source)
			if base_context.amount != before:
				_add_log("【%s】使本次伤害由 %d 增加至 %d。" % [
					skill.display_name,
					before,
					base_context.amount,
				])
	if nature != DamageNature.NORMAL and target.chained:
		_damage_queue.append(base_context)
		for player: BattlePlayer in players:
			if player != target and player.chained:
				_damage_queue.append(base_context.duplicate_for_target(player, true))
		for player: BattlePlayer in players:
			if player.chained:
				player.chained = false
		_add_log("%s属性伤害触发铁索连环，所有横置角色重置并依次传导。" % _nature_text(nature))
	else:
		_damage_queue.append(base_context)
	_process_damage_queue()


func _process_damage_queue() -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	if _damage_queue.is_empty():
		var after: Callable = _damage_after
		_damage_after = Callable()
		_call_safe(after)
		return
	var context: DamageContext = _damage_queue.pop_front()
	var target: BattlePlayer = context.target
	var actual_amount: int = context.amount
	if not context.ignore_armor and _has_equipment(target, Card.CardType.VINE_ARMOR) and context.nature == DamageNature.FIRE:
		actual_amount += 1
		_add_log("【藤甲】锁定技：%s 受到的火焰伤害 +1。" % target.player_name)
	if not context.ignore_armor and _has_equipment(target, Card.CardType.SILVER_LION) and actual_amount > 1:
		_add_log("【白银狮子】锁定技：%s 本次伤害由 %d 限制为 1。" % [target.player_name, actual_amount])
		actual_amount = 1
	context.amount = actual_amount
	target.take_damage(actual_amount)
	_add_log("%s 受到 %d 点%s伤害，当前体力 %d/%d。" % [
		target.player_name,
		actual_amount,
		_nature_text(context.nature),
		target.hp,
		target.max_hp,
	])
	_emit_state()
	_last_damage_context = context
	_continue_after_damage(context)


func _continue_after_damage(context: DamageContext) -> void:
	var target: BattlePlayer = context.target
	if target.is_dying():
		_enter_dying(target, Callable(self, "_after_damage_dying_resolved").bind(context))
	else:
		_after_damage_dying_resolved(context)


func _after_damage_dying_resolved(context: DamageContext) -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	if context.target.hp <= 0:
		## 目标阵亡但战斗未结束（1v2+）：继续结算剩余伤害，不阻断后续目标。
		_process_damage_queue()
		return
	_enqueue_triggers(&"after_damage", context, [context.target], Callable(self, "_process_damage_queue"))


func _enter_dying(player: BattlePlayer, after: Callable) -> void:
	dying_player = player
	_dying_after = after
	rescue_actor = player
	flow_state = FlowState.DYING_RESCUE
	_add_log("%s 进入濒死状态，需要将体力回复至 1。" % player.player_name)
	_emit_state()
	if _rescue_options(player).is_empty():
		_add_log("%s 没有可用的自救牌，放弃自救。" % player.player_name)
		_resolve_rescue_pass(player)
		return
	if player.is_ai:
		_schedule("_perform_ai_rescue", 0.6)


func _perform_ai_rescue() -> void:
	if flow_state != FlowState.DYING_RESCUE or rescue_actor == null or not rescue_actor.is_ai:
		return
	var actor: BattlePlayer = rescue_actor
	var dying: BattlePlayer = dying_player
	## AI 不主动救援敌方：包括真实桃与华佗急救，必须明确放弃并让救援流程继续。
	if dying != actor:
		_add_log("%s 不救援%s，放弃。" % [actor.player_name, dying.player_name])
		_resolve_rescue_pass(actor)
		return
	var index: int = actor.find_card(Card.CardType.PEACH)
	if index >= 0:
		_use_rescue_card(actor, index)
		return
	index = actor.find_card(Card.CardType.WINE)
	if index >= 0:
		_use_rescue_card(actor, index)
		return
	if _can_use_jijiu(actor):
		var jijiu_card: Card = _jijiu_cost_card(actor)
		if jijiu_card != null:
			_use_jijiu_card(actor, jijiu_card)
			return
	_add_log("%s 没有可用自救牌，放弃。" % actor.player_name)
	_resolve_rescue_pass(actor)


func _use_rescue_card(actor: BattlePlayer, hand_index: int) -> void:
	if actor == null or hand_index < 0 or hand_index >= actor.hand.size():
		return
	var card: Card = actor.hand[hand_index]
	_move_cards(
		actor,
		actor,
		[card],
		CardZone.PROCESSING,
		"濒死时使用【%s】" % card.display_name,
		null,
		null,
		null,
		Callable(self, "_apply_rescue_recovery").bind(actor, "【%s】" % card.display_name)
	)


func _use_jijiu_card(actor: BattlePlayer, card: Card) -> void:
	if actor == null or card == null:
		return
	actor.record_skill_use(actor.get_skill(&"jijiu"))
	_add_log("%s 发动【急救】，将%s当【桃】使用。" % [actor.player_name, card.identity_text()])
	_move_cards(
		actor,
		actor,
		[card],
		CardZone.PROCESSING,
		"作为【急救】代价",
		null,
		actor.get_skill(&"jijiu"),
		null,
		Callable(self, "_apply_rescue_recovery").bind(actor, "【急救】视为【桃】")
	)


func _apply_rescue_recovery(actor: BattlePlayer, label: String) -> void:
	if flow_state != FlowState.DYING_RESCUE or dying_player == null or dying_player.hp > 0:
		return
	dying_player.recover(1)
	_add_log("%s 使用%s，%s 体力回复至 %d。" % [
		actor.player_name,
		label,
		dying_player.player_name,
		dying_player.hp,
	])
	_emit_state()
	_check_rescue_state()


func _check_rescue_state() -> void:
	if flow_state != FlowState.DYING_RESCUE or dying_player == null:
		return
	if dying_player.hp >= 1:
		_add_log("%s 脱离濒死状态。" % dying_player.player_name)
		var after: Callable = _dying_after
		_dying_after = Callable()
		rescue_actor = null
		dying_player = null
		_call_safe(after)
		return
	_emit_state()
	if rescue_actor != null and rescue_actor.is_ai:
		_schedule("_perform_ai_rescue", 0.45)


func _resolve_rescue_pass(actor: BattlePlayer) -> void:
	if flow_state != FlowState.DYING_RESCUE or dying_player == null or actor == null:
		return
	_add_log("%s 放弃救援%s。" % [actor.player_name, dying_player.player_name])
	if actor == dying_player:
		var next: BattlePlayer = _next_rescue_actor(dying_player)
		if next != null:
			rescue_actor = next
			if _rescue_options(next).is_empty():
				_add_log("%s 没有可用救援牌，放弃。" % next.player_name)
				_resolve_rescue_pass(next)
				return
			_emit_state()
			if next.is_ai:
				_perform_ai_rescue()
			return
	_declare_death(dying_player)


func _declare_death(loser: BattlePlayer) -> void:
	_add_log("%s 阵亡。" % loser.player_name)
	if check_battle_result():
		return
	## 仍有存活敌人：战斗继续。恢复原结算链（伤害队列/技能 continuation），
	## 死亡角色由回合状态机与目标合法性检查自动跳过。
	var after: Callable = _dying_after
	_dying_after = Callable()
	rescue_actor = null
	dying_player = null
	_emit_state()
	_call_safe(after)


## 所有胜负出口的汇总判定：玩家死亡 → 失败；存活反贼为空 → 胜利。
## 返回 true 表示战斗已终结，返回 false 表示战斗继续进行。
func check_battle_result() -> bool:
	if flow_state == FlowState.GAME_OVER:
		return true
	if player1 != null and player1.is_dying():
		_finish_battle_loss(player1)
		return true
	if living_enemies().is_empty():
		_finish_battle_win()
		return true
	return false


func _finish_battle_win() -> void:
	winner = player1
	flow_state = FlowState.GAME_OVER
	_action_generation += 1
	_settle_processing_cards()
	_clear_skill_context()
	_clear_attack_context()
	rescue_actor = null
	dying_player = null
	_add_log("所有反贼阵亡，%s（%s）获胜！" % [player1.player_name, player1.role_name])
	_emit_state()
	match_finished.emit(winner, null)
	battle_finished.emit(true)
	_schedule_auto_restart()


func _finish_battle_loss(loser: BattlePlayer) -> void:
	winner = first_living_enemy()
	if winner == null and not enemies.is_empty():
		winner = enemies[0]
	if winner == null:
		winner = player1
	flow_state = FlowState.GAME_OVER
	_action_generation += 1
	_settle_processing_cards()
	_clear_skill_context()
	_clear_attack_context()
	rescue_actor = null
	dying_player = null
	_add_log("%s 阵亡。%s（%s）获胜！" % [loser.player_name, winner.player_name, winner.role_name])
	_emit_state()
	match_finished.emit(winner, loser)
	battle_finished.emit(false)
	_schedule_auto_restart()


func _schedule_auto_restart() -> void:
	if not automated_mode:
		return
	## 纯 AI 死循环：本局结束后按相同配置自动重开。
	## 不使用 _schedule（其 generation 守卫会被 start_automated_match 复位使回调失效）。
	if is_inside_tree():
		get_tree().create_timer(1.0).timeout.connect(_restart_automated_match)


func _perform_ai_response() -> void:
	var response_state: FlowState = _multi_response_origin if flow_state == FlowState.MULTI_RESPONSE else flow_state
	match response_state:
		FlowState.RESPONDING_SLASH:
			if pending_target == null or pending_attacker == null:
				## 攻击上下文已被清空的状态残留：安全收尾，避免对 Nil 结算。
				_finish_attack()
				return
			if _try_ai_effective_response(pending_target, Card.CardType.DODGE, FlowState.RESPONDING_SLASH):
				return
			if can_use_bagua(pending_target):
				_resolve_bagua_judgement(pending_target)
			else:
				_add_log("%s 未能继续提供【闪】响应。" % pending_target.player_name)
				_resolve_slash_damage()
		FlowState.AOE_RESPONSE:
			if pending_target == null:
				## AOE 目标已被清空（效果上下文残留）：安全收尾返回出牌阶段。
				_finish_nullifiable_effect()
				return
			if _try_ai_effective_response(pending_target, _response_card_type, FlowState.AOE_RESPONSE):
				return
			if _response_card_type == Card.CardType.DODGE and can_use_bagua(pending_target):
				_resolve_bagua_judgement(pending_target)
			elif (
				_response_card_type == Card.CardType.SLASH
				and can_use_serpent_spear(pending_target)
			):
				_use_serpent_spear(pending_target)
			else:
				_pass_current_response()
		FlowState.DUEL_RESPONSE:
			if _try_ai_effective_response(_duel_responder, Card.CardType.SLASH, FlowState.DUEL_RESPONSE):
				return
			if can_use_serpent_spear(_duel_responder):
				_use_serpent_spear(_duel_responder)
			else:
				_pass_current_response()
		FlowState.BORROW_RESPONSE:
			if _borrow_target.find_card(Card.CardType.SLASH) >= 0:
				_borrow_use_slash()
			elif _try_ai_effective_response(_borrow_target, Card.CardType.SLASH, FlowState.BORROW_RESPONSE):
				return
			elif can_use_serpent_spear(_borrow_target):
				_use_serpent_spear(_borrow_target)
			else:
				_borrow_give_weapon()


func _try_ai_effective_response(
	player: BattlePlayer,
	effective_type: Card.CardType,
	origin: FlowState
) -> bool:
	if (
		effective_type == Card.CardType.DODGE
		and _slash_dodge_forbidden
		and player == pending_target
		and flow_state in [FlowState.RESPONDING_SLASH, FlowState.MULTI_RESPONSE]
	):
		_add_log("【铁骑】禁止响应：%s 不能使用或打出【闪】。" % player.player_name)
		_resolve_slash_damage()
		return true
	var direct_index: int = player.find_card(effective_type)
	if direct_index >= 0:
		var direct: Card = player.hand[direct_index]
		var direct_context := SkillUseContext.new(
			player,
			[direct],
			effective_type,
			null,
			_response_opponent(player),
			false,
			"响应"
		)
		_move_cards(
			player,
			_response_opponent(player),
			[direct],
			CardZone.PROCESSING,
			"打出【%s】响应" % CardFactory.create_card(effective_type).display_name,
			null,
			null,
			null,
			Callable(self, "_accept_effective_response").bind(direct_context, origin)
		)
		return true
	for skill: Skill in player.skills:
		if skill.activation_mode != Skill.ActivationMode.VIEW_AS:
			continue
		if (
			effective_type == Card.CardType.DODGE
			and _slash_dodge_forbidden
			and player == pending_target
			and flow_state in [FlowState.RESPONDING_SLASH, FlowState.MULTI_RESPONSE]
		):
			break
		var candidates: Array[Card] = _view_as_candidates(player, skill, effective_type)
		if candidates.is_empty():
			continue
		var physical: Card = candidates[0]
		player.record_skill_use(skill)
		var context := SkillUseContext.new(
			player,
			[physical],
			effective_type,
			skill,
			_response_opponent(player),
			true,
			"技能响应"
		)
		_add_log("%s 发动【%s】，将%s当【%s】打出。" % [
			player.player_name,
			skill.display_name,
			physical.identity_text(),
			CardFactory.create_card(effective_type).display_name,
		])
		_move_cards(
			player,
			_response_opponent(player),
			[physical],
			CardZone.PROCESSING,
			"作为【%s】响应代价" % skill.display_name,
			null,
			skill,
			null,
			Callable(self, "_accept_effective_response").bind(context, origin)
		)
		return true
	return false


func _pass_current_response() -> void:
	var response_state: FlowState = _multi_response_origin if flow_state == FlowState.MULTI_RESPONSE else flow_state
	match response_state:
		FlowState.AOE_RESPONSE:
			var target: BattlePlayer = pending_target
			_add_log("%s 未打出所需响应牌。" % target.player_name)
			_start_damage(
				_global_source,
				target,
				1,
				DamageNature.NORMAL,
				Callable(self, "_finish_nullifiable_effect"),
				null,
				_active_use_context,
				"【%s】" % _global_card.display_name
			)
		FlowState.DUEL_RESPONSE:
			var loser: BattlePlayer = _duel_responder
			var source: BattlePlayer = _duel_other
			_add_log("%s 未满足【决斗】所需的【杀】响应。" % loser.player_name)
			_start_damage(
				source,
				loser,
				1,
				DamageNature.NORMAL,
				Callable(self, "_finish_nullifiable_effect"),
				null,
				_duel_use_context,
				"【决斗】"
			)
		FlowState.BORROW_RESPONSE:
			_borrow_give_weapon()


func _current_response_player() -> BattlePlayer:
	match flow_state:
		FlowState.AOE_RESPONSE, FlowState.RESPONDING_SLASH:
			return pending_target
		FlowState.MULTI_RESPONSE:
			return pending_target if _multi_response_origin == FlowState.RESPONDING_SLASH else _duel_responder
		FlowState.DUEL_RESPONSE:
			return _duel_responder
		FlowState.BORROW_RESPONSE:
			return _borrow_target
	return null


func _perform_ai_play() -> void:
	if flow_state != FlowState.PLAY_ACTIVE or phase != Phase.PLAY or not current_player().is_ai:
		return
	var ai: BattlePlayer = current_player()
	## AI 行动前检查：自己存活、玩家存活、战斗未结束。
	if ai.is_dying() or player1 == null or player1.is_dying():
		_finish_play_phase()
		return
	## 全 AI 模式下 player1 也可能是 AI：按“谁在使用”决定目标，
	## player1 打第一个存活反贼，其余 AI 打 player1。
	var enemy: BattlePlayer = _default_attack_target(ai)
	if enemy == null:
		_finish_play_phase()
		return

	if ai.hp < ai.max_hp:
		var peach_index: int = ai.find_card(Card.CardType.PEACH)
		if peach_index >= 0:
			_play_peach(ai, peach_index)
			return

	var jieyin: Skill = ai.get_skill(&"jieyin")
	if jieyin != null and can_use_skill(ai, jieyin):
		skill_owner = ai
		skill_actor = ai
		pending_skill = jieyin
		pending_skill_cards = [ai.hand[0], ai.hand[1]]
		pending_skill_targets = [enemy]
		_skill_return_state = FlowState.PLAY_ACTIVE
		_resolve_active_skill()
		return

	var qingnang: Skill = ai.get_skill(&"qingnang")
	if qingnang != null and can_use_skill(ai, qingnang):
		## 优先用青囊治疗自己，通常不治疗敌方。
		if ai.hp < ai.max_hp:
			skill_owner = ai
			skill_actor = ai
			pending_skill = qingnang
			pending_skill_cards = [ai.hand[0]]
			pending_skill_targets = [ai]
			_skill_return_state = FlowState.PLAY_ACTIVE
			_resolve_active_skill()
			return

	var zhiheng: Skill = ai.get_skill(&"zhiheng")
	if zhiheng != null and can_use_skill(ai, zhiheng):
		var low_index: int = -1
		var low_value: int = 999
		for index: int in ai.hand.size():
			var value: int = _ai_card_value(ai.hand[index])
			if value < low_value:
				low_value = value
				low_index = index
		if low_index >= 0 and (ai.hand.size() > hand_limit_for(ai) or low_value <= 45):
			skill_owner = ai
			skill_actor = ai
			pending_skill = zhiheng
			pending_skill_cards = [ai.hand[low_index]]
			_skill_return_state = FlowState.PLAY_ACTIVE
			_resolve_active_skill()
			return

	var fanjian: Skill = ai.get_skill(&"fanjian")
	if fanjian != null and can_use_skill(ai, fanjian):
		skill_owner = ai
		skill_actor = ai
		pending_skill = fanjian
		pending_skill_targets = [enemy]
		_skill_return_state = FlowState.PLAY_ACTIVE
		_resolve_active_skill()
		return

	var kurou: Skill = ai.get_skill(&"kurou")
	if kurou != null and can_use_skill(ai, kurou) and ai.hp > 1 and ai.kurou_ai_uses_this_turn < 1:
		ai.kurou_ai_uses_this_turn += 1
		skill_owner = ai
		skill_actor = ai
		pending_skill = kurou
		_skill_return_state = FlowState.PLAY_ACTIVE
		_resolve_active_skill()
		return

	var equipment_index: int = _find_equipment_in_hand(ai)
	if equipment_index >= 0:
		_play_equipment(ai, equipment_index)
		return

	var self_tricks: Array[Card.CardType] = [Card.CardType.DRAW_TWO, Card.CardType.AMAZING_GRACE]
	for type: Card.CardType in self_tricks:
		var self_index: int = ai.find_card(type)
		if self_index >= 0:
			_use_self_or_global_trick(ai, self_index)
			return

	if ai.hp < ai.max_hp:
		var garden_index: int = ai.find_card(Card.CardType.PEACH_GARDEN)
		if garden_index >= 0:
			_use_self_or_global_trick(ai, garden_index)
			return

	var guose: Skill = ai.get_skill(&"guose")
	if (
		guose != null
		and can_use_skill(ai, guose)
		and _is_valid_trick_target(CardFactory.create_card(Card.CardType.INDULGENCE), ai, enemy)
	):
		var guose_cards: Array[Card] = _view_as_candidates(ai, guose, Card.CardType.INDULGENCE)
		if not guose_cards.is_empty():
			_execute_ai_view_as_play(guose, guose_cards[0], Card.CardType.INDULGENCE, enemy)
			return

	var harmful_types: Array[Card.CardType] = [
		Card.CardType.DISMANTLE,
		Card.CardType.STEAL,
		Card.CardType.BORROW_SWORD,
		Card.CardType.INDULGENCE,
		Card.CardType.SUPPLY_SHORTAGE,
		Card.CardType.FIRE_ATTACK,
		Card.CardType.DUEL,
	]
	for type: Card.CardType in harmful_types:
		var index: int = ai.find_card(type)
		if index >= 0 and _is_valid_trick_target(ai.hand[index], ai, enemy):
			_use_target_trick(ai, enemy, index)
			return

	var qixi: Skill = ai.get_skill(&"qixi")
	if (
		qixi != null
		and can_use_skill(ai, qixi)
		and enemy.total_cards_in_hand_and_equipment() > 0
	):
		var qixi_cards: Array[Card] = _view_as_candidates(ai, qixi, Card.CardType.DISMANTLE)
		if not qixi_cards.is_empty():
			_execute_ai_view_as_play(qixi, qixi_cards[0], Card.CardType.DISMANTLE, enemy)
			return

	var aoe_types: Array[Card.CardType] = [Card.CardType.BARBARIAN_INVASION, Card.CardType.ARROW_BARRAGE]
	for type: Card.CardType in aoe_types:
		var aoe_index: int = ai.find_card(type)
		if aoe_index >= 0:
			_use_self_or_global_trick(ai, aoe_index)
			return

	var lightning_index: int = ai.find_card(Card.CardType.LIGHTNING)
	if lightning_index >= 0 and not ai.has_delayed_trick(Card.CardType.LIGHTNING):
		_use_self_or_global_trick(ai, lightning_index)
		return

	var chain_index: int = ai.find_card(Card.CardType.IRON_CHAIN)
	if chain_index >= 0:
		var chain_card: Card = ai.hand[chain_index]
		_move_cards(
			ai, ai, [chain_card], CardZone.PROCESSING, "使用【铁索连环】",
			null, null, null,
			Callable(self, "_proceed_ai_iron_chain").bind(ai, enemy, chain_card)
		)
		return
	var slash_index: int = ai.find_card(Card.CardType.SLASH)
	if slash_index >= 0 and can_use_slash_in_play(ai):
		var wine_index: int = ai.find_card(Card.CardType.WINE)
		if wine_index >= 0 and not ai.wine_active:
			_play_wine(ai, wine_index)
			return
		_play_slash(ai, enemy, slash_index)
		return
	for skill: Skill in ai.skills:
		if skill.activation_mode != Skill.ActivationMode.VIEW_AS:
			continue
		var slash_cards: Array[Card] = _view_as_candidates(ai, skill, Card.CardType.SLASH)
		if not slash_cards.is_empty() and can_use_slash_in_play(ai):
			_execute_ai_view_as_play(skill, slash_cards[0], Card.CardType.SLASH, enemy)
			return
	if can_use_serpent_spear(ai):
		_use_serpent_spear(ai)
		return
	_finish_play_phase()


func _proceed_ai_iron_chain(ai: BattlePlayer, enemy: BattlePlayer, chain_card: Card) -> void:
	_active_use_context = SkillUseContext.new(
		ai, [chain_card], Card.CardType.IRON_CHAIN, null, enemy, false, "【铁索连环】"
	)
	if not enemy.chained:
		var chain_targets: Array[BattlePlayer] = [enemy]
		var continuation: Callable = Callable(self, "_start_iron_chain").bind(chain_card, ai, chain_targets)
		_enqueue_triggers(&"after_trick_use", _active_use_context, [ai], continuation)
		return
	draw_cards(ai, 1)
	_settle_processing_card(chain_card)
	_active_use_context = null
	_add_log("%s 重铸【铁索连环】，摸一张牌。" % ai.player_name)
	## 重铸后必须恢复出牌状态；若此前连营/集智触发过，flow 仍在 SKILL_RESOLVING。
	_return_to_play()





func _execute_ai_view_as_play(
	skill: Skill,
	card: Card,
	effective_type: Card.CardType,
	target: BattlePlayer
) -> void:
	var actor: BattlePlayer = current_player()
	skill_owner = actor
	skill_actor = actor
	pending_skill = skill
	pending_skill_cards = [card]
	_skill_effective_card_type = effective_type
	_skill_return_state = FlowState.PLAY_ACTIVE
	_use_selected_view_as_card(target)


func can_owner_deal_attack_damage(owner: BattlePlayer) -> bool:
	if owner == null or owner.is_dying():
		return false
	var has_slash_target: bool = false
	for target: BattlePlayer in _potential_targets_for(owner):
		if can_slash_target(owner, target):
			has_slash_target = true
			break
	if not has_slash_target:
		return false
	if owner.find_card(Card.CardType.SLASH) >= 0 or owner.find_card(Card.CardType.DUEL) >= 0:
		return true
	for skill: Skill in owner.skills:
		if (
			skill.activation_mode == Skill.ActivationMode.VIEW_AS
			and not _view_as_candidates(owner, skill, Card.CardType.SLASH).is_empty()
		):
			return true
	return false


func _return_to_play() -> void:
	if flow_state == FlowState.GAME_OVER:
		return
	_settle_processing_cards()
	_active_use_context = null
	_duel_use_context = null
	flow_state = FlowState.PLAY_ACTIVE
	selected_hand_index = -1
	choice_labels.clear()
	choice_owner = null
	_emit_state()
	if current_player().is_ai:
		_schedule("_perform_ai_play", 0.5)


func _enter_discard_phase() -> void:
	phase = Phase.DISCARD
	flow_state = FlowState.DISCARDING
	_add_log("进入弃牌阶段：手牌上限等于当前体力。")
	_emit_state()
	if current_player().hand.size() <= hand_limit_for(current_player()):
		## AI 一律走 _perform_ai_discard（计入 AI 动作计数，避免看门狗误介入）；
		## 人类无牌可弃时仍由定时器直接结束。
		if current_player().is_ai:
			_schedule("_perform_ai_discard", 0.3)
		else:
			_schedule("_finish_discard_phase", 0.3)
	elif current_player().is_ai:
		_schedule("_perform_ai_discard", 0.45)


func _perform_ai_discard() -> void:
	if flow_state != FlowState.DISCARDING or not current_player().is_ai:
		return
	var player: BattlePlayer = current_player()
	var excess: int = player.hand.size() - hand_limit_for(player)
	if excess <= 0:
		_finish_discard_phase()
		return
	## 一次性原子弃到上限：弃牌阶段手牌不会归零（上限>=1），不会触发连营等移动后事件。
	var to_discard: Array[Card] = []
	var index: int = player.hand.size() - 1
	while to_discard.size() < excess and index >= 0:
		to_discard.append(player.hand[index])
		index -= 1
	_move_cards(
		player, player, to_discard, CardZone.DISCARD,
		"在弃牌阶段弃置", null, null, null,
		Callable(self, "_after_ai_phase_discard")
	)


func _after_ai_phase_discard() -> void:
	if flow_state != FlowState.DISCARDING:
		return
	_add_log("%s 弃置到手牌上限。" % current_player().player_name)
	_finish_discard_phase()


func _finish_discard_phase() -> void:
	if flow_state != FlowState.DISCARDING:
		return
	phase = Phase.END
	flow_state = FlowState.IDLE
	_finish_turn_from_end_phase()


func _take_hand_card(player: BattlePlayer, hand_index: int) -> Card:
	return player.remove_card_at(hand_index)


func _take_hand_card_to_processing(player: BattlePlayer, hand_index: int) -> Card:
	var card: Card = _take_hand_card(player, hand_index)
	_move_card_to_processing(card)
	return card


func _move_card_to_processing(card: Card) -> void:
	if card != null and card not in processing_cards:
		processing_cards.append(card)


func _remove_processing_card(card: Card) -> bool:
	var index: int = processing_cards.find(card)
	if index < 0:
		return false
	processing_cards.remove_at(index)
	return true


func is_card_in_processing(card: Card) -> bool:
	return card != null and card in processing_cards


func _settle_processing_card(card: Card) -> void:
	if _remove_processing_card(card):
		discard_pile.append(card)


func _settle_processing_cards() -> void:
	for card: Card in processing_cards:
		discard_pile.append(card)
	processing_cards.clear()


func _claim_processing_card(owner: BattlePlayer, card: Card) -> bool:
	if owner == null or not _remove_processing_card(card):
		return false
	owner.add_card(card)
	return true


func _equipment_slot_for_card(owner: BattlePlayer, card: Card) -> int:
	if owner == null or card == null:
		return -1
	for slot: int in [
		EquipmentScript.Slot.WEAPON,
		EquipmentScript.Slot.ARMOR,
		EquipmentScript.Slot.HORSE_PLUS,
		EquipmentScript.Slot.HORSE_MINUS,
	]:
		if owner.equipment_in_slot(slot) == card:
			return slot
	return -1


func _take_cost_card_to_processing(
	owner: BattlePlayer,
	card: Card,
	reason: String
) -> Card:
	if owner == null or card == null:
		return null
	var hand_index: int = owner.hand.find(card)
	if hand_index >= 0:
		var removed: Card = owner.remove_card_at(hand_index)
		_move_card_to_processing(removed)
		return removed
	var slot: int = _equipment_slot_for_card(owner, card)
	if slot < 0:
		return null
	var equipment: Card = owner.remove_equipment(slot)
	_lose_equipment(owner, equipment, reason, true)
	return equipment


func _consume_hand_card(player: BattlePlayer, hand_index: int) -> void:
	if player == null or hand_index < 0 or hand_index >= player.hand.size():
		return
	var card: Card = player.hand[hand_index]
	_move_cards(
		player, player, [card], CardZone.DISCARD, "因【火攻】弃置",
		_fire_revealed_card, null, null,
		Callable(self, "_after_fire_discard_moved").bind(player, card)
	)


func _after_fire_discard_moved(player: BattlePlayer, card: Card) -> void:
	_add_log("%s 弃置%s，火攻成功。" % [player.player_name, card.identity_text()])
	_start_damage(
		_fire_source,
		_fire_target,
		1,
		DamageNature.FIRE,
		Callable(self, "_finish_nullifiable_effect"),
		null,
		_active_use_context,
		"【火攻】"
	)


func _has_equipment(player: BattlePlayer, card_type: Card.CardType) -> bool:
	if player == null:
		return false
	for equipment: Card in player.all_equipment():
		if equipment.card_type == card_type:
			return true
	return false


func _find_equipment_in_hand(player: BattlePlayer) -> int:
	for index: int in player.hand.size():
		if player.hand[index].category == Card.CardCategory.EQUIPMENT:
			return index
	return -1


func _equipment_slot_text(slot: int) -> String:
	match slot:
		EquipmentScript.Slot.WEAPON:
			return "武器区"
		EquipmentScript.Slot.ARMOR:
			return "防具区"
		EquipmentScript.Slot.HORSE_PLUS:
			return "+1马区"
		EquipmentScript.Slot.HORSE_MINUS:
			return "-1马区"
	return "装备区"


func _equipment_choice_entries(player: BattlePlayer) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if player.weapon != null:
		entries.append({"code": "weapon", "slot_name": "武器", "card": player.weapon})
	if player.armor != null:
		entries.append({"code": "armor", "slot_name": "防具", "card": player.armor})
	if player.horse_plus != null:
		entries.append({"code": "horse_plus", "slot_name": "+1马", "card": player.horse_plus})
	if player.horse_minus != null:
		entries.append({"code": "horse_minus", "slot_name": "-1马", "card": player.horse_minus})
	return entries


func _slot_from_code(code: String) -> int:
	match code:
		"armor":
			return EquipmentScript.Slot.ARMOR
		"horse_plus":
			return EquipmentScript.Slot.HORSE_PLUS
		"horse_minus":
			return EquipmentScript.Slot.HORSE_MINUS
	return EquipmentScript.Slot.WEAPON


func _lose_equipment(
	owner: BattlePlayer,
	equipment: Card,
	reason: String,
	to_processing: bool = false,
	continuation: Callable = Callable(),
	pre_removed: bool = false
) -> void:
	var already_removed: Array[Card] = []
	if pre_removed:
		already_removed.append(equipment)
	var no_excluded: Array[Card] = []
	_move_cards(
		owner,
		owner,
		[equipment],
		CardZone.PROCESSING if to_processing else CardZone.DISCARD,
		reason,
		null,
		null,
		null,
		continuation,
		no_excluded,
		already_removed
	)


## 统一原子牌移动入口：先完整移动全部实体牌，再触发“失去最后手牌/失去装备”事件。
func _move_cards(
	owner: BattlePlayer,
	source: BattlePlayer,
	cards: Array[Card],
	to_zone: int,
	reason: String,
	source_card: Card = null,
	source_skill: Skill = null,
	dest_player: BattlePlayer = null,
	continuation: Callable = Callable(),
	excluded_lost: Array[Card] = [],
	pre_removed: Array[Card] = []
) -> void:
	if owner == null or cards.is_empty() or flow_state == FlowState.GAME_OVER:
		_call_safe(continuation)
		return
	var hand_before: int = owner.hand.size()
	var equipment_before: Array[Card] = owner.all_equipment()
	var moved: Array[Card] = []
	for card: Card in cards:
		if card == null:
			continue
		if card in pre_removed:
			_place_card_in_zone(card, to_zone, owner if dest_player == null else dest_player)
			moved.append(card)
			continue
		var zone: int = _card_current_zone(owner, card)
		if zone == CardZone.PROCESSING and to_zone == CardZone.DISCARD:
			if _remove_processing_card(card):
				discard_pile.append(card)
				moved.append(card)
			continue
		if zone < 0 or zone == CardZone.PROCESSING or zone == CardZone.DISCARD or zone == CardZone.DECK:
			continue
		if not _remove_card_from_owner_zone(owner, card, zone):
			continue
		_place_card_in_zone(card, to_zone, owner if dest_player == null else dest_player)
		moved.append(card)
	if moved.is_empty():
		_call_safe(continuation)
		return
	var move_context := CardMoveContextScript.new(owner, source, moved, reason)
	move_context.source_card = source_card
	move_context.source_skill = source_skill
	move_context.to_zone = _zone_text(to_zone)
	move_context.hand_before = hand_before
	move_context.hand_after = owner.hand.size()
	var context_equipment_before: Array[Card] = equipment_before.duplicate()
	for already_gone: Card in pre_removed:
		if already_gone not in context_equipment_before:
			context_equipment_before.append(already_gone)
	move_context.equipment_before = context_equipment_before
	move_context.equipment_after = owner.all_equipment()
	move_context.excluded_lost = excluded_lost
	var move_tail: String = _move_tail_text(move_context)
	if dest_player != null and dest_player != owner and to_zone == CardZone.HAND:
		move_tail += "，交给 %s" % dest_player.player_name
	_add_log("%s 的%s%s。" % [owner.player_name, _card_list_text(moved), move_tail])
	_emit_state()
	_enqueue_card_move_triggers(move_context, continuation)


func _card_current_zone(owner: BattlePlayer, card: Card) -> int:
	if owner == null or card == null:
		return -1
	if card in owner.hand:
		return CardZone.HAND
	if owner.weapon == card:
		return CardZone.WEAPON
	if owner.armor == card:
		return CardZone.ARMOR
	if owner.horse_plus == card:
		return CardZone.HORSE_PLUS
	if owner.horse_minus == card:
		return CardZone.HORSE_MINUS
	if (
		owner.indulgence_card == card
		or owner.supply_shortage_card == card
		or owner.lightning_card == card
	):
		return CardZone.DELAYED_TRICK
	if card in processing_cards:
		return CardZone.PROCESSING
	if card in discard_pile:
		return CardZone.DISCARD
	if card in draw_pile:
		return CardZone.DECK
	return -1


func _remove_card_from_owner_zone(owner: BattlePlayer, card: Card, zone: int) -> bool:
	match zone:
		CardZone.HAND:
			var hand_index: int = owner.hand.find(card)
			if hand_index < 0:
				return false
			owner.remove_card_at(hand_index)
			return true
		CardZone.WEAPON:
			if owner.weapon != card:
				return false
			owner.weapon = null
			return true
		CardZone.ARMOR:
			if owner.armor != card:
				return false
			owner.armor = null
			return true
		CardZone.HORSE_PLUS:
			if owner.horse_plus != card:
				return false
			owner.horse_plus = null
			return true
		CardZone.HORSE_MINUS:
			if owner.horse_minus != card:
				return false
			owner.horse_minus = null
			return true
		CardZone.DELAYED_TRICK:
			if owner.indulgence_card == card:
				owner.indulgence_card = null
				return true
			if owner.supply_shortage_card == card:
				owner.supply_shortage_card = null
				return true
			if owner.lightning_card == card:
				owner.lightning_card = null
				return true
			return false
	return false


func _place_card_in_zone(card: Card, zone: int, dest_player: BattlePlayer) -> void:
	if card == null:
		return
	match zone:
		CardZone.HAND:
			if dest_player != null:
				dest_player.add_card(card)
		CardZone.WEAPON, CardZone.ARMOR, CardZone.HORSE_PLUS, CardZone.HORSE_MINUS:
			if dest_player != null:
				dest_player.equip(card)
		CardZone.PROCESSING:
			_move_card_to_processing(card)
		CardZone.DISCARD:
			discard_pile.append(card)
		CardZone.DECK:
			draw_pile.push_back(card)
		CardZone.PRIVATE:
			private_cards.append(card)


func _zone_text(zone: int) -> String:
	match zone:
		CardZone.HAND:
			return "手牌"
		CardZone.WEAPON:
			return "武器区"
		CardZone.ARMOR:
			return "防具区"
		CardZone.HORSE_PLUS:
			return "+1马区"
		CardZone.HORSE_MINUS:
			return "-1马区"
		CardZone.DELAYED_TRICK:
			return "判定区"
		CardZone.PROCESSING:
			return "处理区"
		CardZone.DISCARD:
			return "弃牌堆"
		CardZone.DECK:
			return "牌堆"
	return "未知区域"


func _move_tail_text(context: CardMoveContextScript) -> String:
	var base: String = "移动到%s" % String(context.to_zone)
	var pieces: PackedStringArray = []
	if not context.lost_equipment_cards().is_empty():
		pieces.append("失去装备%d张" % context.lost_equipment_cards().size())
	if context.lost_all_hand_cards():
		pieces.append("失去最后手牌")
	if pieces.is_empty():
		return base
	return "%s，%s" % [base, "，".join(pieces)]


func _enqueue_card_move_triggers(context: CardMoveContextScript, continuation: Callable) -> void:
	if context == null:
		_call_safe(continuation)
		return
	if context.lost_equipment_cards().is_empty() and not context.lost_all_hand_cards():
		_call_safe(continuation)
		return
	_enqueue_triggers(&"after_card_move", context, [context.owner], continuation)


func recover_hp(player: BattlePlayer, amount: int, reason: String = "") -> void:
	if player == null or amount <= 0 or player.hp >= player.max_hp:
		return
	var before: int = player.hp
	player.recover(amount)
	_add_log("%s 因%s回复%d点体力：%d/%d。" % [player.player_name, reason, player.hp - before, player.hp, player.max_hp])
	_emit_state()


func _can_use_jijiu(actor: BattlePlayer) -> bool:
	if actor == null or not actor.has_skill(&"jijiu") or actor == current_player():
		return false
	if flow_state != FlowState.DYING_RESCUE or actor != rescue_actor or dying_player == null:
		return false
	return not _view_as_candidates(actor, actor.get_skill(&"jijiu"), Card.CardType.PEACH).is_empty()


func _jijiu_cost_card(actor: BattlePlayer) -> Card:
	var skill: Skill = actor.get_skill(&"jijiu")
	var candidates: Array[Card] = _view_as_candidates(actor, skill, Card.CardType.PEACH)
	return candidates[0] if not candidates.is_empty() else null


func _rescue_options(actor: BattlePlayer) -> Array:
	var options: Array = []
	if actor == null or dying_player == null:
		return options
	if actor.find_card(Card.CardType.PEACH) >= 0:
		options.append(Card.CardType.PEACH)
	if actor == dying_player and actor.find_card(Card.CardType.WINE) >= 0:
		options.append(Card.CardType.WINE)
	if _can_use_jijiu(actor):
		options.append(-1)
	return options


## 【流离】的合法转移目标：另一名角色，位于大乔攻击范围内，且为该【杀】来源的合法目标。
func liuli_transfer_candidates(defender: BattlePlayer, slash_context: RefCounted) -> Array[BattlePlayer]:
	var result: Array[BattlePlayer] = []
	var ctx := slash_context as SlashTargetContextScript
	if ctx == null or ctx.source == null or defender == null:
		return result
	for player: BattlePlayer in players:
		if player == defender or player == ctx.source:
			continue
		if player.is_dying():
			continue
		if not can_slash_target(ctx.source, player):
			continue
		if distance_between(defender, player) > attack_range(defender):
			continue
		result.append(player)
	return result


func _clear_skill_context() -> void:
	skill_owner = null
	skill_actor = null
	_ganglie_discard_active = false
	_lijian_first_target = null
	pending_skill = null
	pending_skill_cards.clear()
	pending_skill_targets.clear()
	_skill_event_context = null
	_skill_confirm_continue = Callable()
	_skill_cancel_continue = Callable()
	_skill_return_state = FlowState.IDLE
	_skill_effective_card_type = Card.CardType.SLASH
	_skill_use_context = null


func _discard_n_cards(player: BattlePlayer, count: int, continuation: Callable = Callable()) -> void:
	var discarded: Array[Card] = []
	var hand_index: int = player.hand.size() - 1
	while discarded.size() < count and hand_index >= 0:
		discarded.append(player.hand[hand_index])
		hand_index -= 1
	var slot_order: Array[int] = [
		EquipmentScript.Slot.HORSE_PLUS,
		EquipmentScript.Slot.HORSE_MINUS,
		EquipmentScript.Slot.ARMOR,
		EquipmentScript.Slot.WEAPON,
	]
	for slot: int in slot_order:
		if discarded.size() >= count:
			break
		var equipment: Card = player.equipment_in_slot(slot)
		if equipment != null:
			discarded.append(equipment)
	if discarded.is_empty():
		_call_safe(continuation)
		return
	_move_cards(
		player, player, discarded, CardZone.DISCARD, "被弃置",
		null, null, null,
		Callable(self, "_finish_discard_n").bind(discarded, continuation)
	)


func _finish_discard_n(discarded: Array[Card], continuation: Callable) -> void:
	if continuation.is_valid():
		continuation.call(discarded)


func _can_supply_slash(player: BattlePlayer) -> bool:
	if player.find_card(Card.CardType.SLASH) >= 0:
		return true
	for skill: Skill in player.skills:
		if (
			skill.activation_mode == Skill.ActivationMode.VIEW_AS
			and not _view_as_candidates(player, skill, Card.CardType.SLASH).is_empty()
		):
			return true
	return (
		_has_equipment(player, Card.CardType.SERPENT_SPEAR)
		and player.hand.size() >= 2
	)


func _record_slash_use(player: BattlePlayer) -> void:
	if player.slash_used_this_turn and player.has_skill(&"paoxiao"):
		_add_log("【咆哮】锁定技：%s 本出牌阶段可以继续使用【杀】。" % player.player_name)
	player.slash_used_this_turn = true
	_record_effective_card_action(player, Card.CardType.SLASH)


func _record_effective_card_action(player: BattlePlayer, card_type: Card.CardType) -> void:
	if player != null and phase == Phase.PLAY and current_player() == player:
		player.record_effective_card(card_type)


func _consume_serpent_spear_cost(player: BattlePlayer) -> Array[Card]:
	var paid: Array[Card] = []
	var index: int = player.hand.size() - 1
	while paid.size() < 2 and index >= 0:
		paid.append(player.hand[index])
		index -= 1
	return paid


func _use_serpent_spear(user: BattlePlayer) -> void:
	if not can_use_serpent_spear(user):
		return
	var paid: Array[Card] = _consume_serpent_spear_cost(user)
	if paid.size() < 2:
		return
	## 在移动牌之前捕获使用场景：连营等移动后触发会把 flow 变成 SKILL_RESOLVING，
	## 不能在 continuation 里再用 is_play_phase_for/flow_state 判断。
	var play_use: bool = is_play_phase_for(user)
	var response_origin: FlowState = _multi_response_origin if flow_state == FlowState.MULTI_RESPONSE else flow_state
	_move_cards(
		user, user, paid, CardZone.PROCESSING, "作为【丈八蛇矛】代价",
		null, null, null,
		Callable(self, "_proceed_serpent_spear").bind(user, paid, play_use, response_origin)
	)


func _proceed_serpent_spear(user: BattlePlayer, paid: Array[Card], play_use: bool, response_origin: FlowState) -> void:
	if paid.size() < 2:
		return
	_add_log("%s 弃置%s，发动【丈八蛇矛】视为使用/打出【杀】。" % [
		user.player_name,
		_card_list_text(paid),
	])
	if not play_use:
		## 响应（打出）场景：对方由当前交互上下文决定。
		var response_context := SkillUseContext.new(
			user,
			paid,
			Card.CardType.SLASH,
			null,
			_response_opponent(user),
			true,
			"【丈八蛇矛】"
		)
		_accept_effective_response(response_context, response_origin)
		return
	## 出牌阶段视为【杀】：多人局让玩家明确选择目标，避免写死第一个反贼。
	if user == player1 and living_enemies().size() > 1:
		_pending_serpent_spear = [user, paid]
		selected_hand_index = -1
		flow_state = FlowState.SELECTING_TARGET
		_add_log("请选择【丈八蛇矛】视为【杀】的目标。")
		_emit_state()
		return
	_fire_serpent_spear_slash(user, paid, _default_attack_target(user))


func _fire_serpent_spear_slash(user: BattlePlayer, paid: Array[Card], target: BattlePlayer) -> void:
	if target == null or target.is_dying() or target == user or not can_slash_target(user, target):
		_add_log("【丈八蛇矛】的目标已不再合法，实体牌进入弃牌堆。")
		_settle_processing_cards()
		_return_to_play()
		return
	var context := SkillUseContext.new(user, paid, Card.CardType.SLASH, null, target, true, "【丈八蛇矛】")
	context.target = target
	_record_slash_use(user)
	var amount: int = 2 if user.wine_active else 1
	user.wine_active = false
	var nature: DamageNature = DamageNature.FIRE if _has_equipment(user, Card.CardType.VERMILION_FAN) else DamageNature.NORMAL
	_start_slash_response(user, target, amount, Callable(self, "_return_to_play"), nature, context)


func _resolve_serpent_spear_target(target_index: int) -> void:
	if _pending_serpent_spear.is_empty():
		return
	var user: BattlePlayer = _pending_serpent_spear[0]
	var paid: Array[Card] = _pending_serpent_spear[1]
	_pending_serpent_spear.clear()
	if target_index < 0 or target_index >= players.size():
		_return_to_play()
		return
	var target: BattlePlayer = players[target_index]
	if target.is_dying() or target == user or not can_slash_target(user, target):
		_reject("该角色不是合法的【杀】目标。")
		_return_to_play()
		return
	_fire_serpent_spear_slash(user, paid, target)


func _draw_one_from_pile() -> Card:
	if draw_pile.is_empty():
		_refill_draw_pile()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()


func _refill_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()
	_add_log("牌堆已空，洗混弃牌堆形成新的摸牌堆。")


func _selected_card_name() -> String:
	if selected_hand_index >= 0 and selected_hand_index < current_player().hand.size():
		return current_player().hand[selected_hand_index].display_name
	return "牌"


func _card_list_text(cards: Array[Card]) -> String:
	var names: PackedStringArray = []
	for card: Card in cards:
		names.append(card.identity_text())
	return "、".join(names)


func _nature_text(nature: DamageNature) -> String:
	match nature:
		DamageNature.FIRE:
			return "火焰"
		DamageNature.THUNDER:
			return "雷电"
	return "普通"


func _ai_card_value(card: Card) -> int:
	match card.card_type:
		Card.CardType.PEACH:
			return 100
		Card.CardType.NULLIFICATION:
			return 90
		Card.CardType.DODGE:
			return 80
		Card.CardType.SLASH:
			return 70
		Card.CardType.DRAW_TWO:
			return 65
		Card.CardType.WINE:
			return 60
		Card.CardType.CROSSBOW, Card.CardType.QINGGANG_SWORD, Card.CardType.ICE_SWORD, \
		Card.CardType.GREEN_DRAGON_BLADE, Card.CardType.SERPENT_SPEAR, \
		Card.CardType.ROCK_CLEAVING_AXE, Card.CardType.HALBERD, \
		Card.CardType.VERMILION_FAN, Card.CardType.QILIN_BOW, \
		Card.CardType.EIGHT_TRIGRAMS, Card.CardType.VINE_ARMOR, \
		Card.CardType.SILVER_LION, Card.CardType.HORSE_PLUS, Card.CardType.HORSE_MINUS:
			return 55
	return 45


func _schedule(method_name: StringName, delay: float) -> void:
	var generation: int = _action_generation
	var is_ai_driver: bool = String(method_name).begins_with("_perform_ai_")
	if is_ai_driver:
		_pending_ai_action_count += 1
	var callback := func() -> void:
		if is_ai_driver:
			_pending_ai_action_count = maxi(_pending_ai_action_count - 1, 0)
		if generation == _action_generation and is_inside_tree():
			call(method_name)
	get_tree().create_timer(delay).timeout.connect(callback)


func _call_safe(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()


func _reject(message: String) -> void:
	_add_log("提示：%s" % message)
	_emit_state()


func _add_log(message: String) -> void:
	print(message)
	log_added.emit(message)


func _emit_state() -> void:
	state_changed.emit()
