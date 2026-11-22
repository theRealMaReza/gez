extends Node

# Phase 20 part 7: small motions that make the interface feel made of
# parchment and gold, kept quick and cheap (one short tween at a time, no
# per-frame work while nothing moves; fine on an M1 with 8 GB).
#
# - Windows unroll like a scroll when they open (any window: the theme's
#   PanelContainer whose parent is not itself a panel), 0.16 s.
# - Medallion buttons light up and swell a little on hover and press in
#   when clicked (GezStyle.medallion_button).
# Set the meta "no_motion" on a panel to keep it still (tooltips do).

const UNROLL_TIME := 0.16

## Off for the CI screenshots, so windows are caught fully open.
var enabled := true

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n is PanelContainer:
		var p := n as PanelContainer
		if p.theme_type_variation == "" and not p.has_meta("no_motion"):
			p.visibility_changed.connect(_on_panel_visibility.bind(p))

func _on_panel_visibility(p: PanelContainer) -> void:
	if not enabled or not is_instance_valid(p) or not p.is_visible_in_tree():
		return
	var parent := p.get_parent()
	if parent is PanelContainer or p.has_meta("no_motion"):
		return
	unroll(p)

## Unroll `c` from its top edge like a scroll (also used by new screens).
static func unroll(c: Control) -> void:
	if c.has_meta("gez_unrolling"):
		return
	c.set_meta("gez_unrolling", true)
	c.pivot_offset = Vector2(c.size.x * 0.5, 0.0)
	c.scale = Vector2(1.0, 0.04)
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, UNROLL_TIME)
	t.tween_property(c, "modulate:a", 1.0, UNROLL_TIME * 0.7)
	t.chain().tween_callback(func() -> void:
		if is_instance_valid(c):
			c.remove_meta("gez_unrolling")
	)
