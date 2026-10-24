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
	_test_all_playable_towers()
	_test_enhancer_bonuses()
	_test_specialized_combat_effects()
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
	var winged: EnemyState = EnemyStateScript.new("winged", 3, {"health": 20.0, "speed": 1.0, "is_flying": true})
	_expect(
		TargetSelectorScript.choose_most_advanced_in_range([winged], route, Vector2.ZERO, 4.0, false) == null,
		"Tower profiles that cannot target flying enemies should filter them out"
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
	for tower_id in ["nuclear", "barracks", "mage", "enhancer"]:
		_expect(catalog.tower_definition(tower_id)["prototype_enabled"], "%s should be functional in the playable prototype" % tower_id)
	_expect(catalog.wave_config["waves"].size() == 5, "Playable prototype should contain five sequential waves")
	_expect(catalog.enemies.size() == 4, "Temporary enemy roster should include four combat profiles")


func _test_all_playable_towers() -> void:
	var simulation: BattleSimulation = BattleSimulationScript.new()
	simulation.wallet.gold = 20000
	var tower_ids: Array[String] = ["rapid", "nuclear", "barracks", "mage", "enhancer"]
	for index in range(tower_ids.size()):
		_expect(simulation.request_build(index, tower_ids[index]), "%s should be purchasable at a free slot" % tower_ids[index])
	for index in range(tower_ids.size()):
		var slot: Dictionary = simulation.snapshot()["slots"][index]
		_expect(String(slot["tower_id"]) == tower_ids[index], "Built category should be represented in the live game state")
		_expect(not Dictionary(slot["stats"]).is_empty(), "Built category should expose active combat/economy stats")
	_expect(not simulation.request_build(5, "unknown_tower"), "Unknown tower data must not create a build")
	var mage_battle: BattleSimulation = BattleSimulationScript.new()
	mage_battle.wallet.gold = 5000
	mage_battle.request_build(0, "mage")
	_expect(mage_battle.upgrade_tower(0), "Mage should purchase its next level")
	_expect(mage_battle.upgrade_tower(0), "Mage should purchase its third level")
	_expect(mage_battle.upgrade_tower(0, "A"), "Mage should purchase a specialization after its levels")
	var mage_stats: Dictionary = mage_battle.snapshot()["slots"][0]["stats"]
	_expect_approx(float(mage_stats["effect_duration"]), 20.0, "Mage A should extend its debuff duration")
	var barracks_battle: BattleSimulation = BattleSimulationScript.new()
	barracks_battle.wallet.gold = 5000
	barracks_battle.request_build(0, "barracks")
	barracks_battle.upgrade_tower(0)
	barracks_battle.upgrade_tower(0)
	barracks_battle.upgrade_tower(0, "B")
	var barracks_stats: Dictionary = barracks_battle.snapshot()["slots"][0]["stats"]
	_expect(bool(barracks_stats["can_attack_fliers"]), "Barracks B should enable attacks on flying enemies")
	_expect_approx(float(barracks_stats["soldier_damage_multiplier"]), 1.5, "Barracks B should increase soldier damage")
	var nuclear_battle: BattleSimulation = BattleSimulationScript.new()
	nuclear_battle.wallet.gold = 15000
	nuclear_battle.request_build(0, "nuclear")
	nuclear_battle.upgrade_tower(0)
	nuclear_battle.upgrade_tower(0)
	nuclear_battle.upgrade_tower(0, "B")
	var nuclear_stats: Dictionary = nuclear_battle.snapshot()["slots"][0]["stats"]
	_expect_approx(float(nuclear_stats["global_damage_fraction"]), 0.1, "Nuclear B should apply an immediate global radiation fraction")
	var rapid_battle: BattleSimulation = BattleSimulationScript.new()
	rapid_battle.wallet.gold = 3000
	rapid_battle.request_build(0, "rapid")
	rapid_battle.upgrade_tower(0)
	rapid_battle.upgrade_tower(0)
	rapid_battle.upgrade_tower(0, "B")
	_expect(String(rapid_battle.towers[0]["state"].specialization) == "B", "Rapid sniper branch should be a real in-match tower state")
	_expect(float(rapid_battle.snapshot()["slots"][0]["stats"]["range"]) >= 900.0, "Rapid B should expose its global targeting range")
	var soldiers_battle: BattleSimulation = BattleSimulationScript.new()
	soldiers_battle.wallet.gold = 1000
	soldiers_battle.request_build(0, "barracks")
	_expect(soldiers_battle.start_wave(), "Barracks production should be testable during a live wave")
	soldiers_battle.tick()
	_expect(soldiers_battle.soldiers.size() >= 2, "Barracks should produce real soldier entities during combat")
	var soldier_spawn_event: bool = false
	for event in soldiers_battle.events_after(0):
		if event["kind"] == "soldier_spawn":
			soldier_spawn_event = true
	_expect(soldier_spawn_event, "Soldier production should emit a connected presentation event")


func _test_enhancer_bonuses() -> void:
	var simulation: BattleSimulation = BattleSimulationScript.new()
	simulation.wallet.gold = 5000
	simulation.request_build(0, "rapid")
	simulation.request_build(1, "enhancer")
	var base_damage: float = float(simulation.snapshot()["slots"][0]["stats"]["damage"])
	_expect(float(simulation.build_cost("nuclear")) < 1200.0, "Enhancer should reduce the nuclear purchase cost")
	_expect(simulation.upgrade_tower(1, "B"), "Enhancer B should be a functional specialization")
	simulation.elapsed_time = 30.0
	var boosted_damage: float = float(simulation.snapshot()["slots"][0]["stats"]["damage"])
	_expect(boosted_damage > base_damage, "Enhancer B should improve affected towers after its configured interval")
	var economy: BattleSimulation = BattleSimulationScript.new()
	economy.wallet.gold = 5000
	economy.request_build(0, "enhancer")
	economy.upgrade_tower(0, "A")
	_expect_approx(economy._kill_reward_multiplier(), 1.5, "Enhancer A should increase kill gold by its configured fifty percent")


func _test_specialized_combat_effects() -> void:
	var nuclear: BattleSimulation = BattleSimulationScript.new()
	nuclear.wallet.gold = 15000
	nuclear.request_build(0, "nuclear")
	nuclear.upgrade_tower(0)
	nuclear.upgrade_tower(0)
	nuclear.upgrade_tower(0, "B")
	var blast_target: EnemyState = EnemyStateScript.new("armored", 100, nuclear.catalog.enemy_definition("armored"))
	blast_target.path_distance = 4.5
	var global_target: EnemyState = EnemyStateScript.new("raider", 101, nuclear.catalog.enemy_definition("raider"))
	global_target.path_distance = 28.5
	nuclear.enemies.append(blast_target)
	nuclear.enemies.append(global_target)
	_expect(nuclear.start_wave(), "Nuclear B should fire during an active wave")
	nuclear.tick()
	_expect(not blast_target.alive, "Nuclear B local explosion should resolve direct damage")
	_expect_approx(global_target.health, 35.0, "Nuclear B should immediately damage a distant live enemy")
	var saw_radiation: bool = false
	for event in nuclear.events_after(0):
		if event["kind"] == "radiation":
			saw_radiation = true
	_expect(saw_radiation, "Global radiation damage should create a real presentation event")
	var mage_a: BattleSimulation = BattleSimulationScript.new()
	mage_a.wallet.gold = 5000
	mage_a.request_build(0, "mage")
	mage_a.upgrade_tower(0)
	mage_a.upgrade_tower(0)
	mage_a.upgrade_tower(0, "A")
	var debuffed_target: EnemyState = EnemyStateScript.new("armored", 100, mage_a.catalog.enemy_definition("armored"))
	debuffed_target.path_distance = 4.5
	mage_a.enemies.append(debuffed_target)
	mage_a.start_wave()
	mage_a.tick()
	_expect_approx(float(debuffed_target.debuff.get("remaining", 0.0)), 20.0, "Mage A should apply a refreshed extended effect")
	var mage_b: BattleSimulation = BattleSimulationScript.new()
	mage_b.wallet.gold = 5000
	mage_b.request_build(0, "mage")
	mage_b.upgrade_tower(0)
	mage_b.upgrade_tower(0)
	mage_b.upgrade_tower(0, "B")
	var knockback_target: EnemyState = EnemyStateScript.new("armored", 100, mage_b.catalog.enemy_definition("armored"))
	knockback_target.path_distance = 4.5
	mage_b.enemies.append(knockback_target)
	mage_b.start_wave()
	mage_b.tick()
	_expect(knockback_target.path_distance < 3.9, "Mage B should push a surviving target backward along the route")
	var saw_knockback: bool = false
	for event in mage_b.events_after(0):
		if event["kind"] == "knockback":
			saw_knockback = true
	_expect(saw_knockback, "Mage knockback should emit the event the board animates")


func _test_playable_battle_and_victory() -> void:
	var simulation: BattleSimulation = BattleSimulationScript.new()
	simulation.wallet.gold = 10000
	for slot_id in range(simulation.build_slots.size()):
		_expect(simulation.request_build(slot_id, "rapid"), "Prototype should allow building a rapid tower on each free slot")
	_expect(not simulation.request_build(0, "rapid"), "Occupied build slot must reject duplicate construction")
	var total_steps: int = 0
	while simulation.phase != "won" and simulation.phase != "lost" and total_steps < 10000:
		if simulation.phase in ["ready", "intermission"]:
			_expect(simulation.start_wave(), "Next configured wave should start from the ready/intermission state")
		for _step in range(10000):
			if simulation.phase != "active" or total_steps >= 10000:
				break
			simulation.tick()
			total_steps += 1
	_expect(simulation.phase == "won", "Full tower defense should reach victory")
	_expect(simulation.spawned_count == 77, "All five configured waves should spawn their complete enemy rosters")
	_expect(simulation.killed_count == 77, "Placed rapid towers should defeat every enemy across the five waves")
	_expect(simulation.leaked_count == 0, "Full test defense should prevent leaks")
	_expect(simulation.wallet.gold >= 10000 - 28 * 100 + 8 * 16 + 5 * 30, "Kills and each clear bonus should enter the economy")


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
