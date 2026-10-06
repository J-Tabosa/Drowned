class_name EnemyAnimation
extends Sprite2D
## Atlas 6×5: repouso, corrida, ataque, dano e morte.

const COLUMNS := 6
var _clip := 0
var _elapsed := 0.0
var _duration := 0.8
var _one_shot := false
var _dead := false


func configure(sheet: Texture2D) -> void:
	texture = sheet
	hframes = COLUMNS
	vframes = 5
	frame = 0
	_dead = false
	_one_shot = false
	_clip = 0
	_elapsed = 0.0


func set_locomotion(moving: bool, fast := false) -> void:
	if _dead or _one_shot:
		return
	var next := 1 if moving else 0
	if next != _clip:
		_elapsed = 0.0
	_clip = next
	_duration = (0.42 if fast else 0.62) if moving else 1.1


func play_attack(duration: float) -> void:
	_play_once(2, duration)


func play_hurt() -> void:
	_play_once(3, 0.24)


func cancel_attack() -> void:
	if _clip == 2 and not _dead:
		_one_shot = false
		_clip = 0
		_elapsed = 0.0
		_duration = 1.1
		frame = 0


func play_death(duration: float) -> void:
	_play_once(4, duration)
	_dead = true


func _play_once(row: int, duration: float) -> void:
	if _dead:
		return
	_clip = row
	_duration = maxf(duration, 0.01)
	_elapsed = 0.0
	_one_shot = true
	frame = row * COLUMNS


func _process(delta: float) -> void:
	_elapsed += delta
	var pose := mini(int(_elapsed / _duration * COLUMNS), COLUMNS - 1)
	if _one_shot:
		frame = _clip * COLUMNS + pose
		if _elapsed >= _duration and not _dead:
			_one_shot = false
			_clip = 0
			_duration = 1.1
			_elapsed = 0.0
	else:
		_elapsed = fmod(_elapsed, _duration)
		frame = _clip * COLUMNS + int(_elapsed / _duration * COLUMNS)
