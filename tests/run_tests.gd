extends SceneTree

const BattleSimulationScript = preload("res://core/battle_simulation.gd")
const DataCatalogScript = preload("res://core/data_catalog.gd")
const DamageRulesScript = preload("res://combat/damage_rules.gd")
const TargetSelectorScript = preload("res://combat/target_selector.gd")
const StatusEffectRulesScript = preload("res://combat/status_effect_rules.gd")
const WalletScript = preload("res://economy/wallet.gd")
const EnhancerRulesScript = preload("res://economy/enhancer_rules.gd")
const TowerStateScript = preload("res://towers/tower_state.gd")
const EnemyStateScript = preload("res://enemies/enemy_state.gd")
const PathFollowerScript = preload("res://enemies/path_follower.gd")
const SoldierRosterScript = preload("res://units/soldier_roster.gd")
const WaveDirectorScript = preload("res://waves/wave_director.gd")

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_damage_and_armor()
	_test_range_targeting()
	_test_sniper_targeting()
	_test_sequential_upgrades()
	_test_debuff_refresh()
	_test_soldier_accumulation_and_losses()
	_test_multiple_enhancers()
	_test_wallet_purchases_and_rewards()
	_test_wave_spawn()
	_test_level_data()
	_test_playable_battle_and_victory()
	_test_defeat_condition()
	if failures == 0:
		print("PULSE tests passed: %d checks" % checks)
		quit(0)
	else:
		push_error("PULSE tests failed: %d of %d checks" % [failures, checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _expect_approx(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (got %.4f, expected %.4f)" % [message, actual, expected])


func _test_damage_and_armor() -> void:
	_expect_approx(DamageRulesScript.calculate_damage(100.0, 0.45, "physical"), 55.0, "Physical damage must be reduced by armor")
	_expect_approx(DamageRulesScript.calculate_damage(100.0, 0.45, "magic"), 100.0, "Magic damage must bypass armor")
	_expect_approx(DamageRulesScript.calculate_damage(100.0, 0.45, "physical", 0.8), 91.0, "Sniper penetration must reduce effective armor")
	_expect_approx(DamageRulesScript.calculate_damage(100.0, 1.0, "physical"), 0.0, "Full armor must reduce physical damage to zero")


func _test_sniper_targeting() -> void:
	var ordinary: EnemyState = EnemyStateScript.new("ordinary", 0, {"health": 110.0, "armor": 0.0, "speed": 1.0})
	var armored: EnemyState = EnemyStateScript.new("armored", 1, {"health": 650.0, "armor": 0.45, "speed": 1.0})
	ordinary.path_distance = 28.0
	armored.path_distance = 1.0
	var target: Variant = TargetSelectorScript.choose_highest_current_ehp([ordinary, armored])
	_expect(target == armored, "Sniper must choose globally highest current EHP, regardless of distance/progress")
	armored.take_damage(600.0)
	target = TargetSelectorScript.choose_highest_current_ehp([ordinary, armored])
	_expect(target == ordinary, "Sniper ranking must use current, not maximum, health")


func _test_range_targeting() -> void:
	var route: Array[Vector2] = [Vector2.ZERO, Vector2(10.0, 0.0)]
	var rear: EnemyState = EnemyStateScript.new("rear", 0, {"health": 10.0, "armor": 0.0, "speed": 1.0})
	var advanced: EnemyState = EnemyStateScript.new("advanced", 1, {"health": 10.0, "armor": 0.0, "speed": 1.0})
	var out_of_range: EnemyState = EnemyStateScript.new("distant", 2, {"health": 10.0, "armor": 0.0, "speed": 1.0})
	rear.path_distance = 1.0
	advanced.path_distance = 3.5
	out_of_range.path_distance = 7.0
	var target: Variant = TargetSelectorScript.choose_most_advanced_in_range(
		[rear, advanced, out_of_range], route, Vector2(0.0, 1.0), 4.0
	)
	_expect(target == advanced, "Tower should choose the most advanced enemy whose route position is in range")
	_expect(
		TargetSelectorScript.choose_most_advanced_in_range([out_of_range], route, Vector2.ZERO, 2.0) == null,
		"Tower should not target enemies outside its range"
	)


func _test_sequential_upgrades() -> void:
	var catalog: DataCatalog = DataCatalogScript.new()
	var tower: TowerState = TowerStateScript.new("rapid", catalog.tower_definition("rapid"))
	var wallet: Wallet = WalletScript.new(1000)
	_expect(wallet.try_spend(int(tower.current_stats()["purchase_cost"])), "Base tower purchase should debit its listed cost")
	_expect(tower.next_upgrade_cost("A") == -1, "Specialization must not skip levels")
	for expected_level in [2, 3]:
		var cost: int = tower.next_upgrade_cost()
		_expect(wallet.try_spend(cost), "Sequential upgrade cost should be payable")
		_expect(tower.advance(), "Sequential level transition should succeed")
		_expect(tower.level == expected_level, "Tower should reach its next level in sequence")
	var branch_cost: int = tower.next_upgrade_cost("A")
	_expect(wallet.try_spend(branch_cost), "Specialization should charge its listed cost")
	_expect(tower.advance("A"), "Available specialization should succeed")
	_expect(tower.specialization == "A", "Selected branch should be retained")
	_expect(not tower.advance("B"), "Specialization branch cannot be changed or purchased twice")
	_expect(wallet.gold == 330, "Upgrade purchases should subtract their exact stage costs")


func _test_debuff_refresh() -> void:
	var effect: Dictionary = StatusEffectRulesScript.apply_mage_debuff({}, 0.4, 0.35, 5.0)
	effect = StatusEffectRulesScript.tick(effect, 2.0)
	_expect_approx(float(effect["remaining"]), 3.0, "Debuff duration should count down")
	effect = StatusEffectRulesScript.apply_mage_debuff(effect, 0.4, 0.35, 5.0)
	_expect_approx(float(effect["remaining"]), 5.0, "Repeated hit should refresh, not add, duration")
	_expect_approx(StatusEffectRulesScript.movement_multiplier(effect), 0.6, "Slow should scale movement speed")
	effect = StatusEffectRulesScript.tick(effect, 5.0)
	_expect(effect.is_empty(), "Expired debuff should be removed")


func _test_soldier_accumulation_and_losses() -> void:
	var roster: SoldierRoster = SoldierRosterScript.new()
	roster.produce(3)
	roster.produce(3)
	_expect(roster.count == 6, "Surviving soldiers should accumulate without a cap")
	_expect(roster.lose(2) == 2 and roster.count == 4, "Soldier losses should remove the requested survivors")
	_expect(roster.lose(99) == 4 and roster.count == 0, "Losses should clamp at the available soldier count")


func _test_multiple_enhancers() -> void:
	_expect_approx(EnhancerRulesScript.growth_multiplier_for_age(300.0), 1.08, "One growth enhancer adds 0.8% per completed 30 seconds")
	_expect_approx(EnhancerRulesScript.combined_growth_multiplier([300.0, 300.0]), 1.16, "Multiple growth enhancers add linearly")
	_expect_approx(EnhancerRulesScript.combine_flat_bonuses(100.0, [0.1, 0.2]), 130.0, "Independent booster bonuses should add rather than compound")
	_expect(EnhancerRulesScript.growth_multiplier_for_age(30000.0) > 1.0, "Unlimited growth must not clamp at a maximum")


func _test_wallet_purchases_and_rewards() -> void:
	var wallet: Wallet = WalletScript.new(320)
	_expect(wallet.try_spend(100), "Affordable purchase should succeed")
	_expect(wallet.gold == 220, "Purchase must subtract exact cost")
	_expect(not wallet.try_spend(221), "Unaffordable purchase should fail")
	_expect(wallet.gold == 220, "Failed purchase must not change gold")
	_expect(wallet.add_kill_reward(16) == 16 and wallet.gold == 236, "Kill reward should credit gold")
	_expect(wallet.add_kill_reward(16, 1.5) == 24 and wallet.gold == 260, "Gold enhancer multiplier should affect kill rewards")


func _test_wave_spawn() -> void:
	var director: WaveDirector = WaveDirectorScript.new()
	director.start({"entries": [{"enemy_id": "test_raider", "count": 2, "spawn_interval": 2.65}]})
	_expect(director.advance(0.1).size() == 1, "Wave should spawn the first enemy immediately")
	_expect(director.advance(2.5).is_empty(), "Next enemy must respect its spawn interval")
	_expect(director.advance(0.15).size() == 1, "Next enemy should spawn after its configured interval")
	_expect(director.all_spawned(), "Director should report all scheduled enemies spawned")
	director.start({"entries": [
		{"enemy_id": "first", "count": 1, "spawn_interval": 1.0},
		{"enemy_id": "second", "count": 1, "spawn_interval": 1.0}
	]})
	var mixed_spawn: Array[String] = director.advance(0.1)
	_expect(mixed_spawn == ["first"], "Wave entries should retain their configured enemy type and order")
	_expect(director.advance(1.0) == ["second"], "Wave director should advance to later enemy entries")


func _test_level_data() -> void:
	var catalog: DataCatalog = DataCatalogScript.new()
	var route: Array[Vector2] = []
	for point in catalog.level["route"]:
		route.append(Vector2(float(point[0]), float(point[1])))
	_expect(catalog.level["build_slots"].size() == 28, "Level should have 28 build positions")
	_expect_approx(PathFollowerScript.total_length(route), 29.0, "Route should match its documented 29-unit length")
	_expect(catalog.towers.size() == 5, "Data catalog should keep all five designed tower roles")
	_expect(catalog.tower_definition("rapid")["prototype_enabled"], "Rapid tower should be enabled in prototype")
	_expect(not catalog.tower_definition("mage")["prototype_enabled"], "Unimplemented tower should not be exposed as functional")


func _test_playable_battle_and_victory() -> void:
	var simulation: BattleSimulation = BattleSimulationScript.new()
	simulation.wallet.gold = 10000
	for slot_id in range(simulation.build_slots.size()):
		_expect(simulation.request_build(slot_id, "rapid"), "Prototype should allow building a rapid tower on each free slot")
	_expect(not simulation.request_build(0, "rapid"), "Occupied build slot must reject duplicate construction")
	_expect(not simulation.request_build(0, "mage"), "Unimplemented tower must reject construction")
	_expect(simulation.start_wave(), "Wave should start from ready state")
	for _step in range(1000):
		if simulation.phase != "active":
			break
		simulation.tick()
	_expect(simulation.phase == "won", "Full tower defense should reach victory")
	_expect(simulation.spawned_count == 8, "All eight wave enemies should spawn")
	_expect(simulation.killed_count == 8, "Placed rapid towers should resolve damage and kills")
	_expect(simulation.leaked_count == 0, "Full test defense should prevent leaks")
	_expect(simulation.wallet.gold >= 10000 - 28 * 100 + 8 * 16 + 30, "Kills and clear bonus should enter the economy")


func _test_defeat_condition() -> void:
	var simulation: BattleSimulation = BattleSimulationScript.new()
	simulation.lives = 1
	_expect(simulation.start_wave(), "Wave should start for defeat condition test")
	for _step in range(500):
		if simulation.phase != "active":
			break
		simulation.tick()
	_expect(simulation.phase == "lost", "Core reaching zero lives should produce defeat")
	_expect(simulation.lives == 0, "Defeat should leave no remaining core lives")
