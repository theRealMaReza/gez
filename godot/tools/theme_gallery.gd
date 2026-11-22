extends SceneTree

# Renders every themed control on one screen (a check of the Phase 20
# style kit that needs no game data). Saves theme_gallery.png into
# $GEZ_GODOT_SNAPSHOT_DIR (or res://snapshots).
#   xvfb-run godot --rendering-driver opengl3 --path godot --script res://tools/theme_gallery.gd

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var bg := ColorRect.new()
	bg.color = Color(0.20, 0.33, 0.42)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# Top bar
	var bar := PanelContainer.new()
	bar.theme_type_variation = "TopBar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 56)
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	bar.add_child(hb)
	var name_l := Label.new(); name_l.text = "OTTOMAN EMPIRE"; name_l.theme_type_variation = "BarTitle"
	hb.add_child(name_l)
	for pair in [["treasury", "417", "+14.0"], ["stability", "+2", ""], ["faith", "0/1", ""], ["manpower", "24k", "39k"], ["sailors", "18.7k", ""]]:
		hb.add_child(GezStyle.medallion_button(pair[0], 36))
		var v := Label.new(); v.text = pair[1]; v.theme_type_variation = "BarLabel"; hb.add_child(v)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(sp)
	var date := Label.new(); date.text = "30 May 1453"; date.theme_type_variation = "BarTitle"; hb.add_child(date)
	hb.add_child(GezStyle.medallion_button("pause", 36))

	# Side column
	var side := PanelContainer.new()
	side.theme_type_variation = "SideBar"
	side.position = Vector2(0, 52)
	side.custom_minimum_size = Vector2(68, 840)
	root.add_child(side)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	side.add_child(vb)
	for k in ["budget", "trade", "court", "government", "religion", "rebels", "technology", "diplomacy", "wars", "armies", "fleets", "chronicle", "ledger", "timelapse"]:
		var mb := GezStyle.medallion_button(k, 46)
		if k == "court":
			GezStyle.set_medallion_on(mb, true)
		vb.add_child(mb)

	# A window
	var win := PanelContainer.new()
	win.position = Vector2(84, 70)
	win.custom_minimum_size = Vector2(470, 0)
	root.add_child(win)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	win.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(GezStyle.title("The Court"))
	head.add_child(GezStyle.close_button(func() -> void: pass))
	var who := Label.new(); who.text = "Mehmed II"; who.theme_type_variation = "Heading"; col.add_child(who)
	var l1 := Label.new(); l1.text = "Sultan of the Ottomans · Age 21 · Osmanoğlu · Sunni"; col.add_child(l1)
	var seals := HBoxContainer.new(); col.add_child(seals)
	for t in ["ambitious", "brave", "scholar", "cruel", "strategist", "sickly"]:
		var tr := TextureRect.new(); tr.texture = GezStyle.trait_seal(t); tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; seals.add_child(tr)
		var tl := Label.new(); tl.text = t.capitalize(); seals.add_child(tl)
	col.add_child(HSeparator.new())
	var tabs := HBoxContainer.new(); col.add_child(tabs)
	for i in range(3):
		var tb := Button.new(); tb.text = ["Overview", "Economy", "People"][i]; tb.theme_type_variation = "Tab"
		tb.toggle_mode = true; tb.button_pressed = i == 0; tabs.add_child(tb)
	var card := PanelContainer.new(); card.theme_type_variation = "Card"; col.add_child(card)
	var cv := VBoxContainer.new(); card.add_child(cv)
	for kv in [["Heir", "Bayezid (5)"], ["Spouses", "Gülbahar, Gülşah, Sitti Şah"], ["Old colour, remapped", "Stability +2"]]:
		var row := HBoxContainer.new(); cv.add_child(row)
		var k := Label.new(); k.text = kv[0]; k.custom_minimum_size = Vector2(170, 0)
		k.add_theme_color_override("font_color", GezStyle.ink(Color(0.72, 0.68, 0.60))); row.add_child(k)
		var v := Label.new(); v.text = kv[1]
		v.add_theme_color_override("font_color", GezStyle.ink(Color(0.55, 0.92, 0.55) if kv[0].begins_with("Old") else Color(0.95, 0.92, 0.85))); row.add_child(v)
	var btns := HBoxContainer.new(); col.add_child(btns)
	for t in ["Inspect Heir", "Arrange Marriage", "Disabled"]:
		var b := Button.new(); b.text = t; b.disabled = t == "Disabled"; btns.add_child(b)
	var cb := CheckBox.new(); cb.text = "Pause on events"; cb.button_pressed = true; col.add_child(cb)
	var cb2 := CheckBox.new(); cb2.text = "Mute all sound"; col.add_child(cb2)
	var sl := HSlider.new(); sl.value = 60; col.add_child(sl)
	var le := LineEdit.new(); le.placeholder_text = "Save name…"; col.add_child(le)
	var pb := ProgressBar.new(); pb.value = 42; pb.custom_minimum_size = Vector2(0, 20); col.add_child(pb)
	var ob := OptionButton.new(); ob.add_item("Historical AI"); ob.add_item("Free AI"); col.add_child(ob)
	var rt := RichTextLabel.new(); rt.bbcode_enabled = true; rt.fit_content = true
	rt.text = "The [b]Janissaries[/b] demand their [i]accession bonus[/i]. Treasury 417 ducats."
	col.add_child(rt)

	# A second window with a long scroll list
	var win2 := PanelContainer.new()
	win2.position = Vector2(580, 70)
	win2.custom_minimum_size = Vector2(380, 0)
	root.add_child(win2)
	var c2 := VBoxContainer.new(); win2.add_child(c2)
	c2.add_child(GezStyle.title("Constantinople Market"))
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(0, 300); c2.add_child(sc)
	var lst := VBoxContainer.new(); lst.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(lst)
	for g in ["Grain", "Fish", "Livestock", "Olive Oil", "Wine", "Dates", "Fruit", "Sugar", "Salt", "Spices", "Silk", "Cloth", "Iron", "Copper", "Gold", "Furs"]:
		var r := HBoxContainer.new(); lst.add_child(r)
		var a := Label.new(); a.text = g; a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r.add_child(a)
		var b2 := Label.new(); b2.text = "1.0"; r.add_child(b2)

	# A tooltip card, made by the real TooltipManager (Phase 20 part 6)
	var tm: CanvasLayer = load("res://scripts/TooltipManager.gd").new()
	root.add_child(tm)
	tm.set_meta("gallery_sample", true)

	# Map mode medallions
	var mm := HBoxContainer.new(); mm.position = Vector2(990, 200); root.add_child(mm)
	for k in ["map_political", "map_diplomatic", "map_states", "map_terrain", "map_religion", "map_culture", "map_development", "map_goods", "map_markets", "map_plague", "map_unrest", "map_institutions"]:
		var b3 := GezStyle.medallion_button(k, 34)
		if k == "map_political":
			GezStyle.set_medallion_on(b3, true)
		mm.add_child(b3)
	# Alerts row (Phase 20 part 5)
	var row: HBoxContainer = load("res://scripts/AlertsRow.gd").new()
	row.call("setup", null)
	row.position = Vector2(990, 260)
	root.add_child(row)
	row.call("show_alerts", [{"kind": "underSiege"}, {"kind": "peaceOffer"}, {"kind": "plague"}, {"kind": "navalBattle"}, {"kind": "techLevel"}, {"kind": "rebels"}])
	call_deferred("_shoot")

func _shoot() -> void:
	var tm: Node = null
	for c in root.get_children():
		if c.has_meta("gallery_sample"):
			tm = c
	if tm != null:
		tm.set_process(false)   # keep the sample card shown (no mouse here)
		tm.call("_populate_panel", {"title": "Treasury & Monthly Net", "summary": "Ducats in, ducats out, each month.",
			"entries": [{"label": "Tax from peasants", "valueText": "+18.7"}, {"label": "Tax from burghers", "valueText": "+1.6"},
				{"label": "Merchants", "valueText": "−13.7"}, {"label": "Army upkeep", "valueText": "−6.4"}],
			"totalText": "+14.0", "notes": ["Taxes are collected on the 1st of each month."]})
		(tm.get("tooltip_panel") as Control).position = Vector2(990, 330)
	for _i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("GEZ_GODOT_SNAPSHOT_DIR")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://snapshots")
	DirAccess.make_dir_recursive_absolute(out)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join("theme_gallery.png"))
	print("snapshot: theme_gallery.png")
	quit(0)
