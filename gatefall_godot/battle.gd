extends Node2D

const VIEW := Vector2(1280.0, 720.0)
const GROUND_Y := 505.0
const MAX_WAVES := 5
const FAELEN_TEXTURE := preload("res://assets/faelen.png")

var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var wave := 0
var defeated := 0
var state := "playing"
var paused := false
var speed_scale := 1.0
var next_wave_delay := 0.5
var skill_cooldown := 0.0
var elapsed := 0.0

var pause_rect := Rect2(1130, 24, 58, 46)
var speed_rect := Rect2(1196, 24, 60, 46)
var skill_rect := Rect2(1080, 586, 150, 108)
var restart_rect := Rect2(510, 420, 260, 64)

func _ready() -> void:
	restart_battle()

func restart_battle() -> void:
	heroes = [
		make_hero("Faelen", Vector2(260, GROUND_Y), 560.0, 74.0, 92.0, 0.72, Color("7bd7ff"), true),
		make_hero("Kess", Vector2(170, GROUND_Y + 24), 430.0, 48.0, 300.0, 0.92, Color("f3a6ff")),
		make_hero("Dana", Vector2(105, GROUND_Y - 58), 390.0, 42.0, 360.0, 0.78, Color("ffd36d")),
		make_hero("Thora", Vector2(195, GROUND_Y - 78), 510.0, 58.0, 115.0, 1.02, Color("8af0aa")),
	]
	enemies.clear()
	floaters.clear()
	effects.clear()
	wave = 0
	defeated = 0
	state = "playing"
	paused = false
	speed_scale = 1.0
	skill_cooldown = 0.0
	next_wave_delay = 0.4
	start_next_wave()
	queue_redraw()

func make_hero(hero_name: String, hero_pos: Vector2, hp: float, damage: float, attack_range: float, interval: float, color: Color, is_faelen := false) -> Dictionary:
	return {
		"name": hero_name, "pos": hero_pos, "home": hero_pos, "hp": hp, "max_hp": hp,
		"damage": damage, "range": attack_range, "interval": interval, "timer": 0.2,
		"color": color, "faelen": is_faelen, "hit": 0.0
	}

func start_next_wave() -> void:
	if wave >= MAX_WAVES:
		state = "victory"
		return
	wave += 1
	var count := 2 + wave
	for i in count:
		var is_boss := wave == MAX_WAVES and i == count - 1
		var hp := (520.0 + wave * 95.0) if is_boss else (115.0 + wave * 34.0)
		enemies.append({
			"name": "Rift Guardian" if is_boss else "Riftling",
			"pos": Vector2(900.0 + i * 92.0, GROUND_Y + (i % 2) * 30.0 - 15.0),
			"hp": hp, "max_hp": hp, "damage": 34.0 + wave * 6.0,
			"interval": 1.15 if is_boss else 1.5, "timer": 0.5 + i * 0.12,
			"speed": 34.0 if is_boss else 49.0, "boss": is_boss, "hit": 0.0
		})
	next_wave_delay = 1.0

func _process(delta: float) -> void:
	if paused or state != "playing":
		queue_redraw()
		return
	var dt := delta * speed_scale
	elapsed += dt
	skill_cooldown = maxf(0.0, skill_cooldown - dt)
	update_heroes(dt)
	update_enemies(dt)
	update_feedback(dt)
	remove_defeated()
	if alive_heroes().is_empty():
		state = "defeat"
	elif enemies.is_empty():
		next_wave_delay -= dt
		if next_wave_delay <= 0.0:
			start_next_wave()
	queue_redraw()

func update_heroes(dt: float) -> void:
	for hero in heroes:
		if hero.hp <= 0.0:
			continue
		hero.timer -= dt
		hero.hit = maxf(0.0, hero.hit - dt)
		var target := nearest_enemy(hero.pos)
		if target.is_empty():
			continue
		var distance: float = absf(target.pos.x - hero.pos.x)
		if distance > hero.range:
			hero.pos.x = minf(hero.pos.x + 72.0 * dt, target.pos.x - hero.range)
		elif hero.timer <= 0.0:
			hero.timer = hero.interval
			var dealt: float = hero.damage * randf_range(0.9, 1.12)
			if randf() < 0.14:
				dealt *= 1.75
			target.hp -= dealt
			target.hit = 0.1
			spawn_hit(target.pos + Vector2(0, -65), dealt, hero.color)
			effects.append({"from": hero.pos + Vector2(35, -72), "to": target.pos + Vector2(-20, -65), "life": 0.12, "color": hero.color})

func update_enemies(dt: float) -> void:
	for enemy in enemies:
		if enemy.hp <= 0.0:
			continue
		enemy.timer -= dt
		enemy.hit = maxf(0.0, enemy.hit - dt)
		var target := nearest_hero(enemy.pos)
		if target.is_empty():
			continue
		var reach := 95.0 if enemy.boss else 62.0
		if enemy.pos.x - target.pos.x > reach:
			enemy.pos.x -= enemy.speed * dt
		elif enemy.timer <= 0.0:
			enemy.timer = enemy.interval
			var dealt: float = enemy.damage * randf_range(0.88, 1.08)
			target.hp -= dealt
			target.hit = 0.12
			spawn_hit(target.pos + Vector2(0, -80), dealt, Color("ff806f"))

func update_feedback(dt: float) -> void:
	for floater in floaters:
		floater.life -= dt
		floater.pos.y -= 34.0 * dt
	floaters = floaters.filter(func(item: Dictionary) -> bool: return item.life > 0.0)
	for effect in effects:
		effect.life -= dt
	effects = effects.filter(func(item: Dictionary) -> bool: return item.life > 0.0)

func remove_defeated() -> void:
	var before := enemies.size()
	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0.0)
	defeated += before - enemies.size()

func nearest_enemy(from: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for enemy in enemies:
		if enemy.hp > 0.0:
			var candidate: float = absf(enemy.pos.x - from.x)
			if candidate < distance:
				distance = candidate
				best = enemy
	return best

func nearest_hero(from: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for hero in heroes:
		if hero.hp > 0.0:
			var candidate: float = absf(from.x - hero.pos.x)
			if candidate < distance:
				distance = candidate
				best = hero
	return best

func alive_heroes() -> Array:
	return heroes.filter(func(hero: Dictionary) -> bool: return hero.hp > 0.0)

func spawn_hit(at: Vector2, amount: float, color: Color) -> void:
	floaters.append({"pos": at, "text": str(roundi(amount)), "life": 0.75, "color": color})

func cast_warden_oath() -> void:
	if skill_cooldown > 0.0 or paused or state != "playing":
		return
	var faelen: Dictionary = heroes[0]
	if faelen.hp <= 0.0:
		return
	skill_cooldown = 8.0
	faelen.hp = minf(faelen.max_hp, faelen.hp + 125.0)
	for hero in alive_heroes():
		hero.hp = minf(hero.max_hp, hero.hp + 45.0)
	for enemy in enemies:
		var dealt := 135.0 if enemy.boss else 185.0
		enemy.hp -= dealt
		enemy.hit = 0.22
		spawn_hit(enemy.pos + Vector2(0, -100), dealt, Color("7fe8ff"))
	effects.append({"from": Vector2(150, GROUND_Y - 80), "to": Vector2(1110, GROUND_Y - 80), "life": 0.32, "color": Color("7fe8ff")})

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		handle_press(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		handle_press(event.position)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			cast_warden_oath()
		elif event.keycode == KEY_P:
			paused = not paused

func handle_press(position: Vector2) -> void:
	if state != "playing" and restart_rect.has_point(position):
		restart_battle()
	elif pause_rect.has_point(position):
		paused = not paused
	elif speed_rect.has_point(position):
		speed_scale = 2.0 if speed_scale == 1.0 else 1.0
	elif skill_rect.has_point(position):
		cast_warden_oath()

func _draw() -> void:
	draw_background()
	draw_units()
	draw_feedback()
	draw_hud()
	if paused:
		draw_center_panel("PAUSED", "Tap the pause button to continue")
	elif state == "victory":
		draw_center_panel("GATE SEALED", "Faelen's party defeated the Rift Guardian")
	elif state == "defeat":
		draw_center_panel("PARTY DEFEATED", "Strengthen the party and try again")

func draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("11162c"))
	for i in 9:
		var x := float(i * 170) - fmod(elapsed * 7.0, 170.0)
		draw_circle(Vector2(x, 150 + (i % 3) * 35), 110, Color(0.13, 0.18, 0.35, 0.45))
	draw_circle(Vector2(1060, 166), 74, Color("7b4bb7"))
	draw_circle(Vector2(1060, 166), 54, Color("241b45"))
	draw_rect(Rect2(0, GROUND_Y + 45, 1280, 170), Color("161b27"))
	draw_rect(Rect2(0, GROUND_Y + 37, 1280, 10), Color("34405c"))
	for i in 18:
		draw_line(Vector2(i * 85.0, GROUND_Y + 47), Vector2(i * 85.0 - 38.0, 720), Color("222b3d"), 2)

func draw_units() -> void:
	for hero in heroes:
		draw_hero(hero)
	for enemy in enemies:
		draw_enemy(enemy)

func draw_hero(hero: Dictionary) -> void:
	var pos: Vector2 = hero.pos
	var alive: bool = hero.hp > 0.0
	var tint: Color = Color.WHITE if hero.hit <= 0.0 else Color("ffb3a7")
	if not alive:
		tint = Color(0.25, 0.25, 0.3, 0.75)
	draw_ellipse_shadow(pos)
	if hero.faelen:
		var frame := Rect2(pos.x - 60, pos.y - 160, 120, 160)
		draw_texture_rect(FAELEN_TEXTURE, frame, false, tint)
	else:
		draw_circle(pos + Vector2(0, -86), 31, hero.color * tint)
		draw_rect(Rect2(pos.x - 25, pos.y - 56, 50, 58), hero.color.darkened(0.38) * tint)
		draw_line(pos + Vector2(15, -55), pos + Vector2(45, -92), Color("e8edf8"), 7)
	draw_bar(Rect2(pos.x - 45, pos.y - 181, 90, 8), hero.hp / hero.max_hp, Color("43dc82"))
	draw_label(Vector2(pos.x - 34, pos.y + 22), hero.name, 16, Color("eef5ff"))

func draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy.pos
	var boss: bool = enemy.boss
	var body := Color("78376f") if boss else Color("5b3b68")
	if enemy.hit > 0.0:
		body = Color("fff1e5")
	draw_ellipse_shadow(pos)
	draw_circle(pos + Vector2(0, -58), 52 if boss else 36, body)
	draw_circle(pos + Vector2(-16, -65), 6, Color("ff504f"))
	draw_circle(pos + Vector2(16, -65), 6, Color("ff504f"))
	if boss:
		draw_line(pos + Vector2(-35, -95), pos + Vector2(-58, -130), Color("bf77df"), 10)
		draw_line(pos + Vector2(35, -95), pos + Vector2(58, -130), Color("bf77df"), 10)
	draw_bar(Rect2(pos.x - (62 if boss else 43), pos.y - (137 if boss else 112), 124 if boss else 86, 9), enemy.hp / enemy.max_hp, Color("ff5e69"))
	if boss:
		draw_label(Vector2(pos.x - 58, pos.y + 25), "GUARDIAN", 16, Color("ffc0ff"))

func draw_ellipse_shadow(pos: Vector2) -> void:
	draw_set_transform(pos, 0.0, Vector2(1.7, 0.45))
	draw_circle(Vector2.ZERO, 40, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_feedback() -> void:
	for effect in effects:
		draw_line(effect.from, effect.to, effect.color, 7.0)
	for floater in floaters:
		var alpha: float = clampf(floater.life / 0.75, 0.0, 1.0)
		var color: Color = floater.color
		color.a = alpha
		draw_label(floater.pos, floater.text, 24, color)

func draw_hud() -> void:
	draw_rect(Rect2(0, 0, 1280, 92), Color(0.035, 0.045, 0.1, 0.94))
	draw_label(Vector2(30, 38), "GATEFALL", 28, Color("80e3ff"))
	draw_label(Vector2(30, 68), "Rift approach", 17, Color("aeb9d7"))
	draw_label(Vector2(510, 42), "WAVE %d / %d" % [wave, MAX_WAVES], 24, Color("ffffff"))
	draw_label(Vector2(522, 69), "%d enemies defeated" % defeated, 16, Color("aeb9d7"))
	draw_button(pause_rect, "▶" if paused else "Ⅱ", Color("324166"))
	draw_button(speed_rect, "%d×" % int(speed_scale), Color("324166"))
	draw_rect(Rect2(0, 575, 1280, 145), Color(0.035, 0.045, 0.09, 0.96))
	for i in heroes.size():
		var hero: Dictionary = heroes[i]
		var card := Rect2(26 + i * 205, 594, 186, 98)
		draw_rect(card, Color("1d2944"), true)
		draw_rect(card, hero.color, false, 3)
		draw_circle(card.position + Vector2(37, 39), 24, hero.color.darkened(0.28))
		draw_label(card.position + Vector2(70, 31), hero.name, 18, Color.WHITE)
		draw_bar(Rect2(card.position + Vector2(70, 48), Vector2(96, 9)), hero.hp / hero.max_hp, Color("43dc82"))
		draw_label(card.position + Vector2(70, 79), "%d / %d" % [maxi(0, roundi(hero.hp)), roundi(hero.max_hp)], 13, Color("b9c6df"))
	var ready: bool = skill_cooldown <= 0.0 and heroes[0].hp > 0.0
	draw_rect(skill_rect, Color("245a78") if ready else Color("273145"), true)
	draw_rect(skill_rect, Color("78e8ff") if ready else Color("607087"), false, 4)
	draw_label(skill_rect.position + Vector2(18, 31), "WARDEN'S", 18, Color.WHITE)
	draw_label(skill_rect.position + Vector2(38, 55), "OATH", 18, Color.WHITE)
	draw_label(skill_rect.position + Vector2(51, 86), "READY" if ready else "%.1fs" % skill_cooldown, 16, Color("91f3ff") if ready else Color("a6afbf"))

func draw_center_panel(title: String, subtitle: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.62))
	draw_rect(Rect2(350, 230, 580, 290), Color("151e36"), true)
	draw_rect(Rect2(350, 230, 580, 290), Color("78dff4"), false, 4)
	draw_label(Vector2(474, 310), title, 38, Color("ffffff"))
	draw_label(Vector2(433, 365), subtitle, 18, Color("bcc9de"))
	draw_button(restart_rect, "PLAY AGAIN", Color("315c79"))

func draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color("101522"), true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color, true)
	draw_rect(rect, Color("d3ddf2"), false, 1)

func draw_button(rect: Rect2, text: String, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, Color("8295ba"), false, 2)
	var size := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_label(rect.position + Vector2((rect.size.x - size.x) / 2.0, (rect.size.y + size.y) / 2.0 - 2.0), text, 20, Color.WHITE)

func draw_label(position: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
