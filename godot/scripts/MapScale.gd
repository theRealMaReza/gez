class_name MapScale
extends RefCounted

## Phase 20.7: how fine the map is. Zoom thresholds (when names, towns and
## armies appear), model sizes and terrain relief were tuned on the old map
## at 32 pixels per degree. `k` is pixels per degree / 32 (1.5 on the Old
## World map at 48). The camera's zoom counts screen pixels per map pixel,
## so the same view of the world has a zoom k times smaller now; `look(z)`
## turns a camera zoom back into the zoom those thresholds were tuned for.
## Main.gd sets `k` from the loaded map.

static var k: float = 1.5

static func look(z: float) -> float:
	return z * k

## Set k from a pixels-per-degree value (ignored if not sensible).
static func set_pixels_per_degree(ppd: float) -> void:
	if ppd > 0.0:
		k = ppd / 32.0
