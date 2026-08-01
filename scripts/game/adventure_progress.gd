class_name AdventureProgress
extends Node

signal progress_changed
signal notification_requested(text: String)

const QUEST_TITLES = [
	"La lanterne du vieux quai",
	"Le cercle des chênes",
	"L'écho de la mine haute",
	"Les graines du moulin",
	"Le sanctuaire sous les cendres",
	"Les feux du marais",
	"La caravane disparue",
	"Le registre des marées",
	"La mémoire des statues",
	"La cloche du sommet"
]

const QUEST_OBJECTIVES = [
	"Découvrir le phare des Trois-Vents.",
	"Découvrir la clairière des Chênes anciens.",
	"Découvrir le belvédère de la mine haute.",
	"Découvrir le moulin des Quatre-Champs.",
	"Découvrir le sanctuaire de basalte.",
	"Découvrir l'autel des lueurs du marais.",
	"Découvrir le camp de la caravane ensevelie.",
	"Découvrir la capitainerie du grand port.",
	"Découvrir le temple de la Première Aube.",
	"Découvrir la cloche du sommet blanc."
]

const QUEST_REWARDS = [
	["Ration de poisson", "nourriture", 2],
	["Herbe médicinale", "plante", 3],
	["Minerai argenté", "minerai", 2],
	["Pain de ferme", "nourriture", 3],
	["Obsidienne vive", "minerai", 2],
	["Antidote du marais", "outil", 2],
	["Éclat de cendre", "ressource", 3],
	["Jeton marchand", "objet vendable", 4],
	["Fragment antique", "trésor", 2],
	["Cristal de givre", "objet rare", 2]
]

var zone_names: Array = []
var inventory: Dictionary = {}
var quests: Array[Dictionary] = []
var discovered_points: Dictionary = {}
var collected_objects: Dictionary = {}
var gold: int = 0
var reputation_by_region: Array[int] = []
var world_flags: Dictionary = {}


func setup(region_names: Array) -> void:
	zone_names = region_names.duplicate()
	reputation_by_region.clear()
	reputation_by_region.resize(zone_names.size())
	reputation_by_region.fill(0)
	quests.clear()
	for region_index in range(zone_names.size()):
		quests.append({
			"region": region_index,
			"titre": QUEST_TITLES[region_index],
			"description": "Un habitant de %s cherche une personne capable d'explorer les environs." % zone_names[region_index],
			"objectif": QUEST_OBJECTIVES[region_index],
			"statut": "disponible",
			"progression": 0,
			"cible": 1,
			"récompense": "%s ×%d" % [QUEST_REWARDS[region_index][0], QUEST_REWARDS[region_index][2]]
		})


func start_region_quest(region_index: int) -> String:
	if region_index < 0 or region_index >= quests.size():
		return "Je n'ai rien à te confier pour le moment."
	var quest = quests[region_index]
	var status = String(quest.get("statut", "disponible"))
	if status == "terminée":
		return "Merci encore. Cette mission est terminée et sa récompense a déjà été remise."
	if status == "active":
		return "La mission « %s » est déjà suivie : %s" % [quest.get("titre", "Mission"), quest.get("objectif", "Explore la région.")]
	quest["statut"] = "active"
	quests[region_index] = quest
	progress_changed.emit()
	notification_requested.emit("NOUVELLE QUÊTE — %s" % quest.get("titre", "Mission"))
	return "J'ai besoin de toi. %s La mission « %s » est maintenant dans ton journal." % [quest.get("objectif", "Explore la région."), quest.get("titre", "Mission")]


func discover_point(point_id: String, region_index: int, point_name: String) -> bool:
	if discovered_points.has(point_id):
		return false
	discovered_points[point_id] = {
		"region": region_index,
		"nom": point_name
	}
	notification_requested.emit("LIEU DÉCOUVERT — %s" % point_name)
	if region_index >= 0 and region_index < quests.size():
		var quest = quests[region_index]
		if String(quest.get("statut", "")) == "active":
			quest["progression"] = 1
			quest["statut"] = "terminée"
			quests[region_index] = quest
			var reward: Array = QUEST_REWARDS[region_index]
			add_item(String(reward[0]), String(reward[1]), int(reward[2]), false)
			gold += 25 + region_index * 5
			reputation_by_region[region_index] = mini(100, reputation_by_region[region_index] + 25)
			notification_requested.emit("QUÊTE TERMINÉE — %s • récompense reçue" % quest.get("titre", "Mission"))
	progress_changed.emit()
	return true


func collect_item(object_id: String, item_name: String, category: String, quantity: int = 1) -> bool:
	if collected_objects.has(object_id):
		return false
	collected_objects[object_id] = true
	add_item(item_name, category, quantity, false)
	progress_changed.emit()
	notification_requested.emit("OBJET RAMASSÉ — %s ×%d" % [item_name, quantity])
	return true


func add_item(item_name: String, category: String, quantity: int = 1, notify: bool = true) -> void:
	var entry: Dictionary = inventory.get(item_name, {"quantité": 0, "catégorie": category})
	entry["quantité"] = int(entry.get("quantité", 0)) + maxi(1, quantity)
	entry["catégorie"] = category
	inventory[item_name] = entry
	if notify:
		notification_requested.emit("INVENTAIRE — %s ×%d" % [item_name, quantity])
	progress_changed.emit()


func remove_item(item_name: String, quantity: int = 1) -> bool:
	if not inventory.has(item_name):
		return false
	var entry: Dictionary = inventory[item_name]
	var remaining = int(entry.get("quantité", 0)) - maxi(1, quantity)
	if remaining < 0:
		return false
	if remaining == 0:
		inventory.erase(item_name)
	else:
		entry["quantité"] = remaining
		inventory[item_name] = entry
	progress_changed.emit()
	return true


func sell_first_treasure() -> Dictionary:
	var names = inventory.keys()
	names.sort()
	for item_name in names:
		var entry: Dictionary = inventory[item_name]
		if String(entry.get("catégorie", "")) in ["trésor", "objet vendable", "objet rare"]:
			remove_item(String(item_name), 1)
			var value = 18 if String(entry.get("catégorie", "")) == "objet vendable" else 35
			gold += value
			progress_changed.emit()
			return {"vendu": true, "objet": String(item_name), "valeur": value}
	return {"vendu": false}


func buy_item(item_name: String, category: String, price: int, quantity: int = 1) -> bool:
	if gold < price:
		return false
	gold -= price
	add_item(item_name, category, quantity, false)
	progress_changed.emit()
	return true


func get_inventory_text() -> String:
	var result = "PIÈCES : %d\n\n" % gold
	if inventory.is_empty():
		return result + "Ton sac est vide. Explore, ouvre des coffres et accomplis des quêtes."
	var names = inventory.keys()
	names.sort()
	for item_name in names:
		var entry: Dictionary = inventory[item_name]
		result += "• %s ×%d\n  %s\n" % [item_name, int(entry.get("quantité", 0)), String(entry.get("catégorie", "objet")).capitalize()]
	return result


func get_journal_text() -> String:
	var result = ""
	for quest in quests:
		var status = String(quest.get("statut", "disponible"))
		var icon = "□"
		if status == "active":
			icon = "◆"
		elif status == "terminée":
			icon = "✓"
		var region_index = int(quest.get("region", 0))
		result += "%s %s — %s\n%s\nRécompense : %s • Réputation locale : %d / 100\n\n" % [
			icon,
			quest.get("titre", "Mission"),
			status.capitalize(),
			quest.get("objectif", ""),
			quest.get("récompense", ""),
			get_reputation(region_index)
		]
	return result


func get_reputation(region_index: int) -> int:
	if region_index < 0 or region_index >= reputation_by_region.size():
		return 0
	return reputation_by_region[region_index]


func set_world_flag(flag_name: String, enabled: bool = true) -> void:
	world_flags[flag_name] = enabled
	progress_changed.emit()


func has_world_flag(flag_name: String) -> bool:
	return bool(world_flags.get(flag_name, false))


func get_save_state() -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"quests": quests.duplicate(true),
		"discovered_points": discovered_points.duplicate(true),
		"collected_objects": collected_objects.duplicate(true),
		"gold": gold,
		"reputation": reputation_by_region.duplicate(),
		"world_flags": world_flags.duplicate(true)
	}


func load_save_state(state: Dictionary) -> void:
	var saved_inventory = state.get("inventory", {})
	if saved_inventory is Dictionary:
		inventory = saved_inventory.duplicate(true)
	var saved_quests = state.get("quests", [])
	if saved_quests is Array and saved_quests.size() == quests.size():
		quests.assign(saved_quests.duplicate(true))
	var saved_points = state.get("discovered_points", {})
	if saved_points is Dictionary:
		discovered_points = saved_points.duplicate(true)
	var saved_collected = state.get("collected_objects", {})
	if saved_collected is Dictionary:
		collected_objects = saved_collected.duplicate(true)
	gold = maxi(0, int(state.get("gold", 0)))
	var saved_reputation = state.get("reputation", [])
	if saved_reputation is Array and saved_reputation.size() == reputation_by_region.size():
		for region_index in range(reputation_by_region.size()):
			reputation_by_region[region_index] = clampi(int(saved_reputation[region_index]), 0, 100)
	var saved_flags = state.get("world_flags", {})
	if saved_flags is Dictionary:
		world_flags = saved_flags.duplicate(true)
	progress_changed.emit()
