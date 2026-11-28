extends Node
## Sound effects (autoload: Sfx). Plays the placeholder sounds in audio/sfx/.
## Sound is reacted to from EventBus where possible, and called directly for gunfire.
## Missing files are skipped quietly, so deleting a sound never crashes the game.

const SOUNDS := {
	"rifle": "res://audio/sfx/rifle.wav",
	"turret": "res://audio/sfx/turret.wav",
	"alien_bolt": "res://audio/sfx/alien_bolt.wav",
	"hit": "res://audio/sfx/hit.wav",
	"die": "res://audio/sfx/die.wav",
	"cannon": "res://audio/sfx/cannon.wav",
	"alert": "res://audio/sfx/alert.wav",
	"radio": "res://audio/sfx/radio.wav",
	"click": "res://audio/sfx/click.wav",
	"promote": "res://audio/sfx/promote.wav",
}
const HUM_PATH := "res://audio/sfx/hum.wav"
const POOL_SIZE := 12
## The same sound will not start again within this many seconds.
const MIN_GAP := 0.05

var enabled := true

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _hum: AudioStreamPlayer
var _hum_users := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		if ResourceLoader.exists(SOUNDS[key]):
			_streams[key] = load(SOUNDS[key])
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	if ResourceLoader.exists(HUM_PATH):
		var hum_stream := load(HUM_PATH) as AudioStreamWAV
		if hum_stream != null:
			hum_stream = hum_stream.duplicate() as AudioStreamWAV
			hum_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			hum_stream.loop_begin = 0
			hum_stream.loop_end = hum_stream.data.size() / 2
			_hum = AudioStreamPlayer.new()
			_hum.stream = hum_stream
			_hum.volume_db = -14.0
			add_child(_hum)

	EventBus.enemy_killed.connect(func(_type): play("die", -6.0))
	EventBus.radio_message.connect(func(_title): play("radio", -4.0))
	EventBus.base_attacked.connect(func(_strength): play("alert", -4.0))
	EventBus.item_purchased.connect(func(_id, _price): play("click"))
	EventBus.item_sold.connect(func(_id, _price): play("click"))
	EventBus.rank_changed.connect(_on_rank_changed)


## Play a sound once. `volume_db` of 0 is full volume, -10 is quieter.
func play(sound: String, volume_db: float = 0.0) -> void:
	if not enabled or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < MIN_GAP:
		return
	_last_played[sound] = now
	var chosen: AudioStreamPlayer = _players[0]
	for player in _players:
		if not player.playing:
			chosen = player
			break
	chosen.stream = _streams[sound]
	chosen.volume_db = volume_db
	chosen.pitch_scale = randf_range(0.94, 1.06)
	chosen.play()


## The low base hum while a level is running. Counted, so scenes can overlap safely.
func start_ambience() -> void:
	_hum_users += 1
	if _hum != null and enabled and not _hum.playing:
		_hum.play()


func stop_ambience() -> void:
	_hum_users = maxi(0, _hum_users - 1)
	if _hum != null and _hum_users == 0:
		_hum.stop()


func _on_rank_changed(new_index: int, old_index: int) -> void:
	if new_index > old_index:
		play("promote", -2.0)
