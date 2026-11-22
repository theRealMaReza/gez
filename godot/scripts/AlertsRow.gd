extends HBoxContainer

# Phase 20 part 5: the alerts row. Glowing gold medallions just under the
# top bar (unhappy estate, siege, plague, peace offer, new technology...).
# The glow's colour tells how urgent it is; the name and advice show on
# hover, a click jumps to the matter (Main._on_alert_pressed).

const SEVERITY := {
	# red: act now
	"underSiege": "danger", "breach": "danger", "coalition": "danger", "bankrupt": "danger",
	"plague": "danger", "famine": "danger", "earthquake": "danger", "blockadedPort": "danger",
	# amber: needs attention
	"peaceOffer": "attention", "lowStability": "attention", "disloyalEstate": "attention",
	"refusingVassal": "attention", "highInflation": "attention", "rebels": "attention", "event": "attention",
	# blue: at sea
	"navalBattle": "sea",
	# green: good news
	"techLevel": "good", "institution": "good",
}
const GLOW := {
	"danger": Color(1.0, 0.25, 0.15),
	"attention": Color(1.0, 0.72, 0.20),
	"sea": Color(0.35, 0.70, 1.0),
	"good": Color(0.45, 0.95, 0.45),
}
const ADVICE := {
	"peaceOffer": "An enemy offers peace. Click to read the terms.",
	"breach": "The walls of a besieged fortress are breached: it may fall to an assault.",
	"underSiege": "One of your provinces is under siege. Click to go there.",
	"coalition": "Neighbours have formed a coalition against you.",
	"lowStability": "Stability is low: unrest grows and estates lose patience. Raise it in Government.",
	"disloyalEstate": "An estate is disloyal and may seize privileges. See Government.",
	"refusingVassal": "A vassal refuses your demands. See the Court.",
	"bankrupt": "The treasury is empty: armies desert and buildings decay.",
	"highInflation": "Inflation makes everything dearer. See the Budget.",
	"navalBattle": "Your fleet is in battle. Click to go there.",
	"blockadedPort": "An enemy fleet blockades one of your ports.",
	"plague": "Plague has broken out in your lands.",
	"famine": "Famine strikes: food is short.",
	"earthquake": "An earthquake has struck one of your provinces.",
	"rebels": "Rebels are gathering or have risen. See Unrest & Rebels.",
	"techLevel": "A new technology level can be reached. See Technology.",
	"institution": "A new institution is spreading. See Technology & Institutions.",
	"event": "Something has happened that needs your decision.",
}
const SIZE := 40.0

var main_view: Control = null
var _glows: Array[TextureRect] = []
var _t := 0.0

func setup(host: Control) -> void:
	main_view = host
	name = "AlertsRow"
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## Rebuild from the bridge's alerts: [{kind, label, tooltip, ...}].
func show_alerts(alerts: Array) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_glows.clear()
	for a_v in alerts:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		var kind := str(a.get("kind", ""))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(SIZE + 10.0, SIZE + 10.0)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		var glow := TextureRect.new()
		glow.texture = GezStyle.tex("res://assets/ui/glow.png")
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# the halo is wider than the medallion (64 px around a 40 px medallion)
		glow.position = Vector2(-7.0, -7.0)
		glow.size = Vector2(SIZE + 24.0, SIZE + 24.0)
		glow.modulate = GLOW.get(SEVERITY.get(kind, "attention"), GLOW["attention"])
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(glow)
		_glows.append(glow)
		var key := "alert_" + kind
		if GezStyle.medallion(key) == null:
			key = "alert_event"
		var b := GezStyle.medallion_button(key, SIZE)
		b.position = Vector2(5.0, 5.0)
		holder.add_child(b)
		var tip := str(a.get("tooltip", ""))
		if tip.is_empty():
			tip = ADVICE.get(kind, "Click to inspect and respond.")
		if main_view != null:
			main_view.call("bind_tip", b, str(a.get("label", "Alert")), tip)
		var copy := a.duplicate()
		b.pressed.connect(func() -> void:
			if main_view != null:
				main_view.call("_on_alert_pressed", copy)
		)
	visible = not _glows.is_empty()
	set_process(visible)

func _process(delta: float) -> void:
	# a slow, soft pulse; one sine for the whole row keeps it cheap
	_t += delta
	var k := 0.62 + 0.38 * (0.5 + 0.5 * sin(_t * 2.4))
	for g in _glows:
		g.self_modulate.a = k
