extends Control

# Phase 20 part 8: decorations of the painted-chart look, shown as the map
# is zoomed out (sea creatures, ships and a compass rose in the open seas).
# Positions are latitude/longitude, turned into map pixels by the bridge.

const DECOR := [
	# picture, latitude, longitude, width in map pixels
	["compass", 30.0, -22.0, 150.0],
	["ship", 45.0, -14.0, 95.0],
	["whale", 9.0, -18.0, 125.0],
	["serpent", 66.0, 2.0, 110.0],
	["serpent", 12.0, 63.0, 125.0],
	["whale", -6.0, 73.0, 120.0],
	["ship", 9.0, 86.0, 85.0],
]

var chart: float = 0.0
var projector: RefCounted = null
var _items: Array = []      # [texture, map position (centre), width]

func setup(bridge: Object) -> void:
	_items.clear()
	if bridge == null or not bridge.has_method("getFocusPoint"):
		return
	for d in DECOR:
		var t := GezStyle.tex("res://assets/ui/chart/%s.png" % d[0])
		if t == null:
			continue
		var p: Vector2 = bridge.call("getFocusPoint", float(d[1]), float(d[2]))
		_items.append([t, p, float(d[3])])
	queue_redraw()

func update_view(chart_amount: float, proj: RefCounted) -> void:
	projector = proj
	var was := chart
	chart = chart_amount
	visible = chart > 0.02
	if visible or was > 0.02:
		queue_redraw()

func _draw() -> void:
	if chart <= 0.02 or projector == null:
		return
	var tint := Color(1, 1, 1, clampf(chart * 1.1, 0.0, 1.0) * 0.92)
	for it in _items:
		var t: Texture2D = it[0]
		var c: Vector2 = it[1]
		var w: float = it[2]
		var h := w * float(t.get_height()) / float(t.get_width())
		var a: Vector2 = projector.call("to_screen", c - Vector2(w, h) * 0.5)
		var b: Vector2 = projector.call("to_screen", c + Vector2(w, h) * 0.5)
		draw_texture_rect(t, Rect2(a, b - a), false, tint)
