extends "res://scripts/main_supercontinent_world.gd"

# V6.1 : tous les emplacements ci-dessous sont dessinés à la main. Les listes
# sont des coordonnées fixes ; aucune graine, aucun bruit et aucun placement
# pseudo-aléatoire n'est utilisé pour remplir les régions.

func _decorate_super_region(zone_index: int) -> void:
	match zone_index:
		0: _decorate_super_volcano(zone_index)
		1: _decorate_super_forest(zone_index)
		2: _decorate_super_ice(zone_index)
		3: _decorate_super_desert(zone_index)
		4: _decorate_super_marsh(zone_index)
		5: _decorate_super_ruins(zone_index)
		6: _decorate_super_pirate_coast(zone_index)
		7: _decorate_super_village(zone_index)
		8: _decorate_super_capital(zone_index)
		9: _decorate_super_highlands(zone_index)


func _decorate_super_volcano(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_add_disc(Vector3(center.x, _super_height(center.x, center.z) + 0.45, center.z), 15.0, Color(0.96, 0.09, 0.01), Color(1.0, 0.03, 0.0))
	_static_box("VolcanoForge", Vector3(34.0, 7.0, 24.0), _ground_point(center + Vector3(0.0, 3.5, 70.0)), Color(0.16, 0.12, 0.10))
	_static_box("VolcanoForgeDoor", Vector3(8.0, 5.0, 1.2), _ground_point(center + Vector3(0.0, 2.5, 57.5)), Color(0.65, 0.16, 0.03))
	var rocks = [
		Vector3(-150.0, 8.0, -95.0), Vector3(-120.0, 6.0, -40.0),
		Vector3(-145.0, 10.0, 30.0), Vector3(-110.0, 7.0, 105.0),
		Vector3(-55.0, 9.0, -130.0), Vector3(-20.0, 6.5, -95.0),
		Vector3(45.0, 8.0, -125.0), Vector3(95.0, 10.0, -82.0),
		Vector3(145.0, 7.0, -25.0), Vector3(130.0, 9.0, 55.0),
		Vector3(95.0, 6.0, 118.0), Vector3(35.0, 8.0, 142.0),
		Vector3(-35.0, 6.0, 135.0), Vector3(-90.0, 8.5, 92.0),
		Vector3(-65.0, 5.5, 35.0), Vector3(62.0, 7.0, 42.0),
		Vector3(-88.0, 6.0, -8.0), Vector3(92.0, 6.0, -5.0)
	]
	for offset in rocks:
		_add_handmade_rock(center + Vector3(offset.x, 0.0, offset.z), Vector3(4.5, offset.y, 4.5), Color(0.10, 0.08, 0.07))
	for offset in [Vector3(-44.0, 0.0, 74.0), Vector3(44.0, 0.0, 74.0), Vector3(-58.0, 0.0, 104.0), Vector3(58.0, 0.0, 104.0)]:
		_super_add_column(center + offset, 9.0)


func _decorate_super_forest(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var trees = [
		Vector3(-170.0, 0.82, -130.0), Vector3(-135.0, 0.90, -115.0),
		Vector3(-95.0, 0.78, -142.0), Vector3(-45.0, 0.88, -125.0),
		Vector3(15.0, 0.84, -138.0), Vector3(70.0, 0.92, -118.0),
		Vector3(125.0, 0.80, -135.0), Vector3(165.0, 0.88, -95.0),
		Vector3(-175.0, 0.86, -55.0), Vector3(-120.0, 0.94, -42.0),
		Vector3(-62.0, 0.82, -70.0), Vector3(5.0, 0.90, -55.0),
		Vector3(72.0, 0.86, -65.0), Vector3(138.0, 0.92, -45.0),
		Vector3(-165.0, 0.88, 25.0), Vector3(-112.0, 0.82, 18.0),
		Vector3(-55.0, 0.95, 48.0), Vector3(15.0, 0.86, 35.0),
		Vector3(80.0, 0.92, 28.0), Vector3(150.0, 0.84, 45.0),
		Vector3(-178.0, 0.90, 95.0), Vector3(-125.0, 0.84, 118.0),
		Vector3(-70.0, 0.92, 92.0), Vector3(-8.0, 0.80, 122.0),
		Vector3(58.0, 0.90, 98.0), Vector3(118.0, 0.86, 126.0),
		Vector3(172.0, 0.94, 92.0), Vector3(-150.0, 0.80, 145.0),
		Vector3(-30.0, 0.86, 150.0), Vector3(95.0, 0.88, 150.0)
	]
	_place_tree_list(center, trees)
	_static_box("ForestCliff", Vector3(70.0, 18.0, 18.0), _ground_point(center + Vector3(92.0, 9.0, -118.0)), Color(0.18, 0.22, 0.17))
	_visual_box("ForestWaterfall", Vector3(16.0, 15.0, 0.45), center + Vector3(92.0, 8.0, -108.5), Color(0.18, 0.62, 0.88, 0.82))
	_add_disc(_ground_point(center + Vector3(92.0, 0.16, -88.0)), 18.0, Color(0.05, 0.34, 0.52), Color(0.12, 0.55, 0.75))
	_spawn_super_model(HOUSE_MODEL, _ground_point(center + Vector3(-35.0, 0.0, 12.0)), Vector3.ONE * 1.25, Vector3(0.0, 0.7, 0.0))
	_spawn_super_model(HOUSE_MODEL, _ground_point(center + Vector3(42.0, 0.0, 5.0)), Vector3.ONE * 1.18, Vector3(0.0, -0.5, 0.0))


func _decorate_super_ice(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var crystals = [
		Vector3(-165.0, 1.8, -120.0), Vector3(-120.0, 2.2, -95.0),
		Vector3(-70.0, 1.5, -135.0), Vector3(-15.0, 2.6, -108.0),
		Vector3(45.0, 1.9, -135.0), Vector3(105.0, 2.4, -95.0),
		Vector3(158.0, 1.7, -125.0), Vector3(-155.0, 2.1, -35.0),
		Vector3(-95.0, 1.6, -20.0), Vector3(-35.0, 2.5, -48.0),
		Vector3(35.0, 1.8, -25.0), Vector3(92.0, 2.3, -45.0),
		Vector3(155.0, 1.7, -18.0), Vector3(-165.0, 1.9, 55.0),
		Vector3(-105.0, 2.6, 38.0), Vector3(-45.0, 1.7, 72.0),
		Vector3(18.0, 2.2, 48.0), Vector3(75.0, 1.6, 68.0),
		Vector3(138.0, 2.5, 45.0), Vector3(-138.0, 1.8, 128.0),
		Vector3(-72.0, 2.4, 105.0), Vector3(0.0, 1.7, 135.0),
		Vector3(72.0, 2.2, 112.0), Vector3(145.0, 1.9, 128.0)
	]
	for item in crystals:
		_super_add_crystal(center + Vector3(item.x, 0.0, item.z), item.y, Color(0.48, 0.86, 1.0))
	_static_box("IceCitadelBase", Vector3(68.0, 5.0, 54.0), _ground_point(center + Vector3(0.0, 2.5, 18.0)), Color(0.58, 0.72, 0.78))
	for offset in [Vector3(-28.0, 0.0, -18.0), Vector3(28.0, 0.0, -18.0), Vector3(-28.0, 0.0, 42.0), Vector3(28.0, 0.0, 42.0)]:
		_super_add_tower(center + offset, 14.0)


func _decorate_super_desert(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var mesas = [
		Vector3(-165.0, 7.0, -118.0), Vector3(-105.0, 5.0, -138.0),
		Vector3(-35.0, 6.0, -112.0), Vector3(55.0, 8.0, -132.0),
		Vector3(135.0, 5.5, -102.0), Vector3(170.0, 7.5, -35.0),
		Vector3(-150.0, 6.5, -25.0), Vector3(-82.0, 4.5, 22.0),
		Vector3(95.0, 6.0, 15.0), Vector3(155.0, 5.0, 65.0),
		Vector3(-162.0, 7.0, 92.0), Vector3(-95.0, 5.0, 128.0),
		Vector3(-20.0, 6.5, 105.0), Vector3(75.0, 4.8, 132.0),
		Vector3(150.0, 7.0, 118.0)
	]
	for offset in mesas:
		_add_handmade_rock(center + Vector3(offset.x, 0.0, offset.z), Vector3(7.0, offset.y, 6.0), Color(0.52, 0.31, 0.14))
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(-18.0, 0.0, 18.0)), Vector3.ONE * 2.4, Vector3(0.0, -0.45, 0.0))
	_static_box("DesertTemplePlatform", Vector3(88.0, 3.0, 70.0), _ground_point(center + Vector3(-18.0, 1.5, 18.0)), Color(0.58, 0.43, 0.22))
	for offset in [Vector3(-52.0, 0.0, -10.0), Vector3(15.0, 0.0, -10.0), Vector3(-52.0, 0.0, 48.0), Vector3(15.0, 0.0, 48.0)]:
		_super_add_column(center + offset, 11.0)


func _decorate_super_marsh(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var trees = [
		Vector3(-170.0, 0.68, -125.0), Vector3(-105.0, 0.72, -138.0),
		Vector3(-35.0, 0.66, -112.0), Vector3(45.0, 0.74, -136.0),
		Vector3(122.0, 0.70, -105.0), Vector3(168.0, 0.68, -45.0),
		Vector3(-155.0, 0.74, -30.0), Vector3(-90.0, 0.68, 8.0),
		Vector3(-18.0, 0.72, -18.0), Vector3(55.0, 0.66, 25.0),
		Vector3(135.0, 0.74, 12.0), Vector3(-165.0, 0.70, 70.0),
		Vector3(-110.0, 0.66, 118.0), Vector3(-42.0, 0.74, 82.0),
		Vector3(28.0, 0.68, 128.0), Vector3(98.0, 0.72, 88.0),
		Vector3(162.0, 0.66, 132.0)
	]
	_place_tree_list(center, trees)
	_add_hand_authored_route("MarshBoardwalkA", [
		center + Vector3(-170.0, 0.0, -70.0),
		center + Vector3(-90.0, 0.0, -25.0),
		center + Vector3(0.0, 0.0, 5.0),
		center + Vector3(95.0, 0.0, 48.0),
		center + Vector3(170.0, 0.0, 92.0)
	], 5.5, Color(0.32, 0.22, 0.13), true)
	_add_hand_authored_route("MarshBoardwalkB", [
		center + Vector3(-80.0, 0.0, 140.0),
		center + Vector3(-35.0, 0.0, 65.0),
		center + Vector3(18.0, 0.0, -15.0),
		center + Vector3(62.0, 0.0, -105.0)
	], 4.5, Color(0.30, 0.21, 0.12), true)
	_spawn_super_model(HOUSE_MODEL, _ground_point(center + Vector3(78.0, 0.0, -48.0)), Vector3.ONE * 1.22, Vector3(0.0, 2.2, 0.0))


func _decorate_super_ruins(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 0.0, -28.0)), Vector3.ONE * 2.8, Vector3.ZERO)
	_static_box("RuinsPlaza", Vector3(115.0, 1.2, 90.0), _ground_point(center + Vector3(0.0, 0.6, -10.0)), Color(0.48, 0.39, 0.24))
	var columns = [
		Vector3(-70.0, 0.0, -55.0), Vector3(-35.0, 0.0, -55.0),
		Vector3(35.0, 0.0, -55.0), Vector3(70.0, 0.0, -55.0),
		Vector3(-70.0, 0.0, 15.0), Vector3(-35.0, 0.0, 15.0),
		Vector3(35.0, 0.0, 15.0), Vector3(70.0, 0.0, 15.0),
		Vector3(-95.0, 0.0, 72.0), Vector3(95.0, 0.0, 72.0)
	]
	for offset in columns:
		_super_add_column(center + offset, 9.0 if absf(offset.x) < 80.0 else 12.0)
	for offset in [Vector3(-140.0, 0.0, 120.0), Vector3(140.0, 0.0, 115.0), Vector3(-150.0, 0.0, -120.0), Vector3(145.0, 0.0, -115.0)]:
		_add_handmade_rock(center + offset, Vector3(6.0, 5.0, 6.0), Color(0.42, 0.36, 0.26))


func _decorate_super_pirate_coast(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_add_hand_authored_route("PirateMainDock", [
		Vector3(-810.0, 0.0, -48.0),
		Vector3(-875.0, 0.0, -48.0),
		Vector3(-940.0, 0.0, -48.0)
	], 8.0, Color(0.34, 0.23, 0.13), true)
	_add_hand_authored_route("PirateSideDock", [
		Vector3(-870.0, 0.0, -48.0),
		Vector3(-870.0, 0.0, 18.0)
	], 6.0, Color(0.34, 0.23, 0.13), true)
	_spawn_super_model(BOAT_MODEL, Vector3(-1000.0, WATER_SURFACE_Y + 0.48, -52.0), Vector3.ONE * 2.0, Vector3(0.0, -0.20, 0.0))
	for offset in [Vector3(-115.0, 0.0, -105.0), Vector3(-80.0, 0.0, -70.0), Vector3(-125.0, 0.0, 15.0), Vector3(-95.0, 0.0, 80.0), Vector3(-140.0, 0.0, 130.0)]:
		_add_handmade_rock(center + offset, Vector3(5.0, 6.0, 5.0), Color(0.27, 0.28, 0.26))
	_spawn_super_model(HOUSE_MODEL, _ground_point(center + Vector3(-25.0, 0.0, -70.0)), Vector3.ONE * 1.20, Vector3(0.0, 1.5, 0.0))
	_spawn_super_model(HOUSE_MODEL, _ground_point(center + Vector3(35.0, 0.0, -25.0)), Vector3.ONE * 1.15, Vector3(0.0, -0.8, 0.0))
	_spawn_super_model(HOUSE_MODEL, _ground_point(center + Vector3(-10.0, 0.0, 55.0)), Vector3.ONE * 1.18, Vector3(0.0, 2.8, 0.0))
	_super_add_tower(center + Vector3(-105.0, 0.0, -28.0), 13.0)


func _decorate_super_village(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var houses = [
		Vector3(-120.0, 0.0, -82.0), Vector3(-52.0, 0.0, -96.0),
		Vector3(30.0, 0.0, -90.0), Vector3(112.0, 0.0, -70.0),
		Vector3(-135.0, 0.0, 0.0), Vector3(-60.0, 0.0, 12.0),
		Vector3(45.0, 0.0, 8.0), Vector3(128.0, 0.0, 18.0),
		Vector3(-110.0, 0.0, 92.0), Vector3(-18.0, 0.0, 105.0),
		Vector3(88.0, 0.0, 98.0)
	]
	for index in range(houses.size()):
		var offset: Vector3 = houses[index]
		_spawn_super_model(HOUSE_MODEL, _ground_point(center + offset), Vector3.ONE * (1.08 + float(index % 3) * 0.06), Vector3(0.0, float(index) * 0.52, 0.0))
	_static_box("VillageSquare", Vector3(88.0, 0.5, 70.0), _ground_point(center + Vector3(0.0, 0.25, 5.0)), Color(0.55, 0.46, 0.30))
	_add_disc(_ground_point(center + Vector3(0.0, 0.18, 5.0)), 11.0, Color(0.12, 0.48, 0.68), Color(0.25, 0.70, 0.86))
	var trees = [
		Vector3(-175.0, 0.82, -135.0), Vector3(-90.0, 0.86, -145.0),
		Vector3(0.0, 0.84, -142.0), Vector3(90.0, 0.88, -138.0),
		Vector3(170.0, 0.82, -115.0), Vector3(-175.0, 0.86, 135.0),
		Vector3(-85.0, 0.82, 145.0), Vector3(10.0, 0.88, 150.0),
		Vector3(102.0, 0.84, 142.0), Vector3(175.0, 0.86, 118.0),
		Vector3(-178.0, 0.84, -20.0), Vector3(180.0, 0.82, 15.0)
	]
	_place_tree_list(center, trees)
	_static_box("FarmFieldA", Vector3(90.0, 0.18, 48.0), _ground_point(center + Vector3(125.0, 0.10, 78.0)), Color(0.42, 0.34, 0.12))
	_static_box("FarmFieldB", Vector3(82.0, 0.18, 46.0), _ground_point(center + Vector3(-140.0, 0.10, 78.0)), Color(0.40, 0.32, 0.11))


func _decorate_super_capital(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_static_box("CapitalPlatform", Vector3(190.0, 2.0, 150.0), _ground_point(center + Vector3(0.0, 1.0, 0.0)), Color(0.31, 0.30, 0.29))
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 2.0, -42.0)), Vector3.ONE * 3.1, Vector3.ZERO)
	for offset in [
		Vector3(-86.0, 0.0, -62.0), Vector3(86.0, 0.0, -62.0),
		Vector3(-86.0, 0.0, 62.0), Vector3(86.0, 0.0, 62.0)
	]:
		_super_add_tower(center + offset, 17.0)
	var houses = [
		Vector3(-145.0, 0.0, -108.0), Vector3(-75.0, 0.0, -118.0),
		Vector3(70.0, 0.0, -118.0), Vector3(145.0, 0.0, -105.0),
		Vector3(-155.0, 0.0, -25.0), Vector3(150.0, 0.0, -18.0),
		Vector3(-150.0, 0.0, 70.0), Vector3(-70.0, 0.0, 112.0),
		Vector3(65.0, 0.0, 112.0), Vector3(150.0, 0.0, 72.0)
	]
	for index in range(houses.size()):
		var offset: Vector3 = houses[index]
		_spawn_super_model(HOUSE_MODEL, _ground_point(center + offset), Vector3.ONE * 1.24, Vector3(0.0, float(index) * 0.60, 0.0))
	_add_hand_authored_route("CapitalAvenue", [
		center + Vector3(0.0, 0.0, -155.0),
		center + Vector3(0.0, 0.0, -60.0),
		center + Vector3(0.0, 0.0, 30.0),
		center + Vector3(0.0, 0.0, 155.0)
	], 12.0, Color(0.45, 0.42, 0.36), false)


func _decorate_super_highlands(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_static_box("HighlandsSanctuary", Vector3(110.0, 4.0, 84.0), _ground_point(center + Vector3(0.0, 2.0, -15.0)), Color(0.47, 0.56, 0.58))
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 4.0, -15.0)), Vector3.ONE * 3.0, Vector3.ZERO)
	var crystals = [
		Vector3(-160.0, 2.0, -120.0), Vector3(-105.0, 1.6, -145.0),
		Vector3(-45.0, 2.4, -125.0), Vector3(30.0, 1.8, -145.0),
		Vector3(98.0, 2.3, -118.0), Vector3(160.0, 1.7, -88.0),
		Vector3(-170.0, 2.2, -25.0), Vector3(-112.0, 1.7, 18.0),
		Vector3(-48.0, 2.5, 42.0), Vector3(38.0, 1.8, 35.0),
		Vector3(105.0, 2.2, 18.0), Vector3(168.0, 1.7, 55.0),
		Vector3(-150.0, 1.9, 115.0), Vector3(-85.0, 2.4, 138.0),
		Vector3(-10.0, 1.7, 120.0), Vector3(68.0, 2.2, 145.0),
		Vector3(145.0, 1.9, 118.0)
	]
	for item in crystals:
		_super_add_crystal(center + Vector3(item.x, 0.0, item.z), item.y, Color(0.76, 0.94, 1.0))
	for offset in [Vector3(-55.0, 0.0, -52.0), Vector3(55.0, 0.0, -52.0), Vector3(-55.0, 0.0, 22.0), Vector3(55.0, 0.0, 22.0)]:
		_super_add_column(center + offset, 13.0)


func _build_routes() -> void:
	var routes = [
		["RouteVillagePirates", [Vector3(-600.0, 0.0, 360.0), Vector3(-650.0, 0.0, 230.0), Vector3(-620.0, 0.0, 105.0), Vector3(-600.0, 0.0, 0.0)]],
		["RoutePiratesCapitale", [Vector3(-600.0, 0.0, 0.0), Vector3(-470.0, 0.0, -20.0), Vector3(-335.0, 0.0, -8.0), Vector3(-200.0, 0.0, 0.0)]],
		["RouteCapitaleMarais", [Vector3(-200.0, 0.0, 0.0), Vector3(60.0, 0.0, -12.0), Vector3(330.0, 0.0, 5.0), Vector3(600.0, 0.0, 0.0)]],
		["RouteVillageRuines", [Vector3(-600.0, 0.0, 360.0), Vector3(-465.0, 0.0, 335.0), Vector3(-330.0, 0.0, 370.0), Vector3(-200.0, 0.0, 360.0)]],
		["RouteRuinesPlateaux", [Vector3(-200.0, 0.0, 360.0), Vector3(-25.0, 0.0, 330.0), Vector3(165.0, 0.0, 370.0), Vector3(360.0, 0.0, 360.0)]],
		["RoutePiratesForet", [Vector3(-600.0, 0.0, 0.0), Vector3(-510.0, 0.0, -125.0), Vector3(-350.0, 0.0, -250.0), Vector3(-200.0, 0.0, -360.0)]],
		["RouteForetVolcan", [Vector3(-200.0, 0.0, -360.0), Vector3(-330.0, 0.0, -345.0), Vector3(-470.0, 0.0, -380.0), Vector3(-600.0, 0.0, -360.0)]],
		["RouteForetGlace", [Vector3(-200.0, 0.0, -360.0), Vector3(-60.0, 0.0, -390.0), Vector3(70.0, 0.0, -345.0), Vector3(200.0, 0.0, -360.0)]],
		["RouteGlaceDesert", [Vector3(200.0, 0.0, -360.0), Vector3(335.0, 0.0, -335.0), Vector3(470.0, 0.0, -380.0), Vector3(600.0, 0.0, -360.0)]],
		["RouteDesertMarais", [Vector3(600.0, 0.0, -360.0), Vector3(630.0, 0.0, -245.0), Vector3(575.0, 0.0, -120.0), Vector3(600.0, 0.0, 0.0)]],
		["RouteCapitalePlateaux", [Vector3(-200.0, 0.0, 0.0), Vector3(-30.0, 0.0, 105.0), Vector3(155.0, 0.0, 230.0), Vector3(360.0, 0.0, 360.0)]],
		["RouteCapitaleRuines", [Vector3(-200.0, 0.0, 0.0), Vector3(-225.0, 0.0, 120.0), Vector3(-180.0, 0.0, 245.0), Vector3(-200.0, 0.0, 360.0)]]
	]
	for route in routes:
		_add_hand_authored_route(String(route[0]), route[1], 8.5, Color(0.46, 0.34, 0.21), false)


func _add_hand_authored_route(node_name: String, points: Array, width: float, color: Color, force_bridge: bool) -> void:
	for index in range(points.size() - 1):
		var start: Vector3 = points[index]
		var finish: Vector3 = points[index + 1]
		var delta := finish - start
		var midpoint := (start + finish) * 0.5
		var ground_y := _super_height(midpoint.x, midpoint.z)
		var bridge := force_bridge or ground_y < WATER_SURFACE_Y + 0.25
		var road_y := WATER_SURFACE_Y + 0.48 if bridge else ground_y + 0.12
		var size := Vector3(width, 0.40 if bridge else 0.12, delta.length() + 1.0)
		var road: Node3D
		if bridge:
			road = _static_box(node_name, size, Vector3(midpoint.x, road_y, midpoint.z), color)
		else:
			road = _visual_box(node_name, size, Vector3(midpoint.x, road_y, midpoint.z), color)
		road.rotation.y = atan2(delta.x, delta.z)


func _place_tree_list(center: Vector3, entries: Array) -> void:
	for entry in entries:
		var x: float = center.x + float(entry.x)
		var z: float = center.z + float(entry.z)
		_spawn_super_model(TREE_MODEL, Vector3(x, _super_height(x, z), z), Vector3.ONE * entry.y, Vector3(0.0, (entry.x + entry.z) * 0.013, 0.0))


func _add_super_zone_title(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var title_z := center.z - REGION_SIZE.y * 0.40
	var anchor := Node3D.new()
	anchor.name = "SuperZoneTitle%02d" % (zone_index + 1)
	anchor.position = Vector3(center.x, _super_height(center.x, title_z) + 6.0, title_z)
	add_child(anchor)
	_add_world_label(anchor, "ZONE %d — %s" % [zone_index + 1, SUPER_ZONE_NAMES[zone_index]], Vector3.ZERO, ZONE_ACCENT_COLORS[zone_index])


func _spawn_super_model(path: String, position: Vector3, scale_value: Vector3, rotation_value: Vector3) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	if not resource is PackedScene:
		return null
	var instance := (resource as PackedScene).instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return null
	var model := instance as Node3D
	model.position = position
	model.scale = scale_value
	model.rotation = rotation_value
	add_child(model)
	return model


func _ground_point(point: Vector3) -> Vector3:
	return Vector3(point.x, _super_height(point.x, point.z) + point.y, point.z)


func _add_handmade_rock(point: Vector3, scale_value: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "HandmadeRock"
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = Vector3(point.x, _super_height(point.x, point.z) + scale_value.y * 0.42, point.z)
	body.rotation = Vector3(point.z * 0.002, point.x * 0.0025, point.x * 0.0015)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.7
	mesh.material = _material(color)
	visual.mesh = mesh
	visual.scale = scale_value
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	collision.scale = Vector3(scale_value.x, scale_value.y * 0.82, scale_value.z)
	body.add_child(collision)
	add_child(body)


func _super_add_crystal(point: Vector3, size_value: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "HandmadeCrystal"
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = Vector3(point.x, _super_height(point.x, point.z) + size_value * 1.5, point.z)
	var crystal := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(size_value, size_value * 3.0, size_value)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.7
	mesh.material = material
	crystal.mesh = mesh
	crystal.rotation = Vector3(0.0, point.x * 0.002, 0.08)
	body.add_child(crystal)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_value, size_value * 3.0, size_value)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _super_add_column(point: Vector3, height_value: float) -> void:
	var body := StaticBody3D.new()
	body.name = "HandmadeColumn"
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = Vector3(point.x, _super_height(point.x, point.z) + height_value * 0.5, point.z)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 0.95
	mesh.height = height_value
	mesh.material = _material(Color(0.68, 0.58, 0.38))
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.95
	shape.height = height_value
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _super_add_tower(point: Vector3, height_value: float) -> void:
	_static_box("HandmadeTower", Vector3(7.0, height_value, 7.0), Vector3(point.x, _super_height(point.x, point.z) + height_value * 0.5, point.z), Color(0.20, 0.19, 0.22))
