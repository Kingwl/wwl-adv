extends Node

const POOL_SIZE := 12
const DEFAULT_WEAPON_VOLUME_DB := -7.0
const DEFAULT_WEAPON_MIN_INTERVAL := 0.08
const DEFAULT_PITCH_VARIATION := 0.035

const WEAPON_SFX_PATHS := {
	&"melee_basic": "res://assets/audio/sfx/weapons/melee_basic.wav",
	&"projectile_basic": "res://assets/audio/sfx/weapons/projectile_basic.wav",
	&"thunder": "res://assets/audio/sfx/weapons/thunder.wav",
	&"orbit": "res://assets/audio/sfx/weapons/orbit.wav",
	&"thorns": "res://assets/audio/sfx/weapons/thorns.wav",
	&"shotgun": "res://assets/audio/sfx/weapons/shotgun.wav",
	&"fire_bottle": "res://assets/audio/sfx/weapons/fire_bottle.wav",
	&"frost_ring": "res://assets/audio/sfx/weapons/frost_ring.wav",
	&"holy_prism": "res://assets/audio/sfx/weapons/holy_prism.wav",
	&"poison_vial": "res://assets/audio/sfx/weapons/poison_vial.wav",
	&"mine": "res://assets/audio/sfx/weapons/mine.wav",
	&"laser_pen": "res://assets/audio/sfx/weapons/laser_pen.wav",
	&"boomerang": "res://assets/audio/sfx/weapons/boomerang.wav",
	&"electromagnetic_chain": "res://assets/audio/sfx/weapons/electromagnetic_chain.wav",
	&"saw_blade": "res://assets/audio/sfx/weapons/saw_blade.wav",
	&"rocket_pack": "res://assets/audio/sfx/weapons/rocket_pack.wav",
	&"whirlwind": "res://assets/audio/sfx/weapons/whirlwind.wav",
	&"throwing_axe": "res://assets/audio/sfx/weapons/throwing_axe.wav",
	&"shockwave": "res://assets/audio/sfx/weapons/shockwave.wav",
	&"spark_bomb": "res://assets/audio/sfx/weapons/spark_bomb.wav",
}

const WEAPON_VOLUME_DB := {
	&"orbit": -12.0,
	&"saw_blade": -11.0,
	&"rocket_pack": -9.0,
	&"thorns": -6.0,
	&"shotgun": -5.5,
	&"mine": -5.0,
	&"shockwave": -5.5,
}

const WEAPON_MIN_INTERVAL := {
	&"orbit": 1.2,
	&"saw_blade": 1.0,
	&"rocket_pack": 0.24,
	&"thorns": 0.18,
	&"spark_bomb": 0.12,
}

var _players: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _last_play_time: Dictionary = {}
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pool()


func has_weapon_sfx(weapon_id: StringName) -> bool:
	return WEAPON_SFX_PATHS.has(weapon_id)


func get_weapon_sfx_count() -> int:
	return WEAPON_SFX_PATHS.size()


func get_weapon_sfx(weapon_id: StringName) -> AudioStream:
	if not has_weapon_sfx(weapon_id):
		return null
	if _streams.has(weapon_id):
		return _streams[weapon_id] as AudioStream
	var stream := _load_wav_stream(String(WEAPON_SFX_PATHS[weapon_id]))
	if stream == null:
		return null
	_streams[weapon_id] = stream
	return stream


func play_weapon_sfx(weapon_id: StringName, volume_offset_db: float = 0.0, min_interval: float = -1.0) -> bool:
	if not has_weapon_sfx(weapon_id):
		return false
	var interval := min_interval
	if interval < 0.0:
		interval = float(WEAPON_MIN_INTERVAL.get(weapon_id, DEFAULT_WEAPON_MIN_INTERVAL))
	if not _can_play(weapon_id, interval):
		return false
	var stream := get_weapon_sfx(weapon_id)
	if stream == null:
		return false

	var player := _next_player()
	if player == null:
		return false
	player.stop()
	player.stream = stream
	player.volume_db = float(WEAPON_VOLUME_DB.get(weapon_id, DEFAULT_WEAPON_VOLUME_DB)) + volume_offset_db
	player.pitch_scale = randf_range(1.0 - DEFAULT_PITCH_VARIATION, 1.0 + DEFAULT_PITCH_VARIATION)
	player.play()
	_last_play_time[weapon_id] = _now_seconds()
	return true


func _build_pool() -> void:
	if not _players.is_empty():
		return
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func _next_player() -> AudioStreamPlayer:
	if _players.is_empty():
		_build_pool()
	if _players.is_empty():
		return null
	var player: AudioStreamPlayer = _players[_pool_index]
	_pool_index = (_pool_index + 1) % _players.size()
	return player


func _can_play(weapon_id: StringName, min_interval: float) -> bool:
	if min_interval <= 0.0 or not _last_play_time.has(weapon_id):
		return true
	return _now_seconds() - float(_last_play_time[weapon_id]) >= min_interval


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _load_wav_stream(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("AudioManager: cannot open SFX file: %s" % path)
		return null

	var bytes := file.get_buffer(file.get_length())
	if bytes.size() < 44 or not _match_fourcc(bytes, 0, 82, 73, 70, 70) or not _match_fourcc(bytes, 8, 87, 65, 86, 69):
		push_warning("AudioManager: invalid WAV file: %s" % path)
		return null

	var audio_format := 0
	var channels := 0
	var sample_rate := 0
	var bits_per_sample := 0
	var sample_data := PackedByteArray()
	var cursor := 12

	while cursor + 8 <= bytes.size():
		var chunk_size := _u32(bytes, cursor + 4)
		var chunk_data_offset := cursor + 8
		if chunk_data_offset + chunk_size > bytes.size():
			break

		if _match_fourcc(bytes, cursor, 102, 109, 116, 32):
			if chunk_size >= 16:
				audio_format = _u16(bytes, chunk_data_offset)
				channels = _u16(bytes, chunk_data_offset + 2)
				sample_rate = _u32(bytes, chunk_data_offset + 4)
				bits_per_sample = _u16(bytes, chunk_data_offset + 14)
		elif _match_fourcc(bytes, cursor, 100, 97, 116, 97):
			sample_data = bytes.slice(chunk_data_offset, chunk_data_offset + chunk_size)

		cursor = chunk_data_offset + chunk_size + (chunk_size % 2)

	if audio_format != 1 or not (channels == 1 or channels == 2) or not (bits_per_sample == 8 or bits_per_sample == 16) or sample_data.is_empty():
		push_warning("AudioManager: unsupported WAV format: %s" % path)
		return null

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels == 2
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = sample_data
	return stream


func _match_fourcc(bytes: PackedByteArray, offset: int, a: int, b: int, c: int, d: int) -> bool:
	return offset + 4 <= bytes.size() and bytes[offset] == a and bytes[offset + 1] == b and bytes[offset + 2] == c and bytes[offset + 3] == d


func _u16(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


func _u32(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)
