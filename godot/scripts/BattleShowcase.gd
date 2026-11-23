extends RefCounted

# Phase 20.6: a fixed battle picture for the CI screenshots and for checking
# the battle view by eye (godot_battle_closeup.png). Only display data, in
# the shape of getBattleState(): nothing here touches the battle rules.
# Ottomans (left) against Hungary (right) on plains with a hill, a wood and
# a stream: melee in the centre, archers and handgunners shooting, guns
# firing, horse charging on the flank and one regiment running.

static func _unit(i: int, side: int, cat: String, glyph: String, x: float, y: float, men: int, stance: String, extra := {}) -> Dictionary:
	var att := side == 0
	var u := {
		"index": i, "side": side, "name": "Regiment %d" % (i + 1), "key": "", "glyph": glyph,
		"category": cat, "men": men, "initialMen": 1000, "maxMen": 1000,
		"morale": 2.2, "maxMorale": 3.0, "fatigue": 0.2,
		"ammo": 0, "maxAmmo": 0,
		"x": x, "y": y, "w": 24.0 if cat != "cavalry" else 30.0, "h": 60.0 if cat != "artillery" else 40.0,
		"facing": 0.0 if att else PI, "formation": "line", "stance": stance,
		"hasMoveOrder": false, "targetX": x, "targetY": y, "targetUnit": -1, "targetStructure": -1,
		"siegeEquipment": "none", "waypoints": [], "isRouting": false, "isOnWall": false, "inMelee": false,
		"colorR": 178 if att else 70, "colorG": 40 if att else 120, "colorB": 34 if att else 60,
	}
	u.merge(extra, true)
	# footprint as in BattleUnitTable.footprint (the rules' rectangle)
	var k := 0.65 + 0.35 * clampf(float(u["men"]) / 1000.0, 0.2, 1.0)
	var dims := Vector2(36.0, 34.0) if u["formation"] == "wedge" else Vector2(22.0, 48.0)
	u["w"] = dims.x * k
	u["h"] = dims.y * k
	return u

static func state() -> Dictionary:
	var units := [
		_unit(0, 0, "infantry", "J", 560, 330, 900, "charge", {"inMelee": true, "key": "janissaries"}),
		_unit(1, 0, "infantry", "I", 560, 420, 1000, "advance", {"inMelee": true}),
		_unit(2, 0, "ranged", "A", 470, 250, 800, "volley", {"ammo": 14, "maxAmmo": 20}),
		_unit(3, 0, "ranged", "H", 470, 510, 700, "volley", {"ammo": 9, "maxAmmo": 16, "key": "handgunners"}),
		_unit(4, 0, "artillery", "C", 360, 380, 600, "volley", {"ammo": 30, "maxAmmo": 40}),
		_unit(5, 0, "cavalry", "S", 600, 640, 700, "charge", {"hasMoveOrder": true, "targetX": 700.0, "targetY": 620.0, "formation": "wedge"}),
		_unit(6, 0, "cavalry", "HA", 430, 150, 500, "hold"),
		_unit(7, 1, "infantry", "P", 600, 330, 950, "hold", {"inMelee": true, "key": "pikemen"}),
		_unit(8, 1, "infantry", "I", 600, 420, 600, "hold", {"inMelee": true, "morale": 0.8}),
		_unit(9, 1, "ranged", "A", 700, 250, 800, "volley", {"ammo": 6, "maxAmmo": 20}),
		_unit(10, 1, "infantry", "I", 760, 560, 300, "retreat", {"isRouting": true, "morale": 0.0}),
		_unit(11, 1, "cavalry", "G", 780, 400, 600, "hold", {"key": "gendarmes"}),
		_unit(12, 1, "ranged", "H", 700, 500, 0, "volley"),
	]
	return {
		"active": true, "phase": "active", "provinceName": "Mohács", "terrainKey": "plains", "terrainName": "Plains",
		"isAssault": false, "isRiverCrossing": false, "attackerAmbushed": false,
		"speedIndex": 2, "speedLabel": "1x", "tickCount": 240, "elapsedSeconds": 96.0,
		"playerSide": "attacker", "winner": "",
		"fieldW": 1200.0, "fieldH": 800.0,
		"attDeployX": 50.0, "attDeployY": 50.0, "attDeployW": 350.0, "attDeployH": 700.0,
		"defDeployX": 800.0, "defDeployY": 50.0, "defDeployW": 350.0, "defDeployH": 700.0,
		"attackerName": "Ottoman Empire", "attackerTag": "TUR", "attackerColorR": 178, "attackerColorG": 40, "attackerColorB": 34,
		"attackerMen": 5200, "attackerInitialMen": 6000, "attackerAvgMorale": 2.1, "attackerCommander": "Mahmud Pasha", "attackerMartial": 7,
		"defenderName": "Hungary", "defenderTag": "HUN", "defenderColorR": 70, "defenderColorG": 120, "defenderColorB": 60,
		"defenderMen": 3250, "defenderInitialMen": 5000, "defenderAvgMorale": 1.2, "defenderCommander": "János Hunyadi", "defenderMartial": 9,
		"hills": [{"x": 820.0, "y": 300.0, "rx": 140.0, "ry": 110.0, "angle": 0.3, "height": 18.0}],
		"forests": [{"x": 300.0, "y": 620.0, "rx": 90.0, "ry": 60.0, "density": 0.7}],
		"hasRiver": true, "riverHalfWidth": 14.0,
		"riverPoints": [{"x": 980.0, "y": 0.0}, {"x": 940.0, "y": 300.0}, {"x": 1000.0, "y": 560.0}, {"x": 960.0, "y": 800.0}],
		"fords": [], "structures": [], "keepZone": {}, "keepCaptureProgress": 0.0, "resultPreview": {},
		"siteStyle": 1, "attackerStyle": 1, "defenderStyle": 0,
		"units": units,
	}
