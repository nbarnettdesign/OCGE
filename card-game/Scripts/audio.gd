extends Node

# Drop sound files in these paths (ogg or wav). Anything missing is skipped quietly.
const SFX = {
	"click": "res://Audio/sfx/click.ogg", "hover": "res://Audio/sfx/hover.ogg",
	"draw": "res://Audio/sfx/draw.ogg", "place": "res://Audio/sfx/place.ogg",
	"hit": "res://Audio/sfx/hit.ogg", "flip": "res://Audio/sfx/flip.ogg",
	"win": "res://Audio/sfx/win.ogg", "lose": "res://Audio/sfx/lose.ogg",
	"unlock": "res://Audio/sfx/unlock.ogg",
}
const MUSIC = {
	"menu": "res://Audio/music/menu.ogg", "overworld": "res://Audio/music/overworld.ogg",
	"battle": "res://Audio/music/battle.ogg",
}

var music_player
var sfx_players = []
var cache = {}
var current_music = ""


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	for i in 8:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	GameState.apply_settings()                 # now that the buses exist


func _ensure_bus(bus_name):
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _stream(path):
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not cache.has(path):
		cache[path] = load(path)
	return cache[path]


func play(sfx_name, pitch_variation = 0.05):
	var stream = _stream(SFX.get(sfx_name, ""))
	if stream == null:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
			p.play()
			return


func play_music(music_name, fade = 0.8):
	if music_name == current_music:
		return
	current_music = music_name
	var stream = _stream(MUSIC.get(music_name, ""))
	var out = create_tween()
	if music_player.playing:
		out.tween_property(music_player, "volume_db", -40.0, fade)
		await out.finished
	if stream == null or current_music != music_name:
		music_player.stop()
		return
	if "loop" in stream:
		stream.loop = true
	music_player.stream = stream
	music_player.volume_db = -40.0
	music_player.play()
	create_tween().tween_property(music_player, "volume_db", 0.0, fade)
