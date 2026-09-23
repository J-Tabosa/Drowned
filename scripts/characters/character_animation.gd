class_name CharacterAnimation
extends Sprite2D

const FRAMES_PER_ROW := 6
const IDLE_SEQUENCE := [0, 1, 2, 3, 4, 5, 4, 3, 2, 1]
const IDLE_STEP := 0.16
const WALK_CYCLE := 0.54
const SPRINT_CYCLE := 0.38
const HURT_DURATION := 0.42

var _moving := false
var _sprinting := false
var _one_shot := ""
var _one_shot_duration := 0.0
var _elapsed := 0.0
var _last_clip := ""
var _dead := false
var _walk_pose := 0


func configure(sheet: Texture2D) -> void:
	texture = sheet
	hframes = FRAMES_PER_ROW if sheet != null else 1
	vframes = 4 if sheet != null else 1
	frame = 0
	_elapsed = 0.0
	_one_shot = ""
	_last_clip = "idle"
	_dead = false
	_walk_pose = 0


func set_locomotion(moving: bool, sprinting: bool) -> void:
	_moving = moving
	_sprinting = sprinting


func is_action_playing() -> bool:
	return _one_shot == "attack"


func play_action(duration: float) -> void:
	if _dead or texture == null:
		return
	_one_shot = "attack"
	_one_shot_duration = duration
	_elapsed = 0.0
	frame = 2 * FRAMES_PER_ROW


func jump_to_action_frame(frame_index: int) -> void:
	if _one_shot != "attack":
		return
	_elapsed = maxf(_elapsed, _one_shot_duration * float(frame_index) / FRAMES_PER_ROW)
	frame = 2 * FRAMES_PER_ROW + clampi(frame_index, 0, FRAMES_PER_ROW - 1)


func play_hurt() -> void:
	if _dead or texture == null:
		return
	_one_shot = "hurt"
	_one_shot_duration = HURT_DURATION
	_elapsed = 0.0
	frame = 3 * FRAMES_PER_ROW


func play_death() -> void:
	_dead = true
	_one_shot = ""
	frame = 3 * FRAMES_PER_ROW + 3 if texture != null else 0


func _process(delta: float) -> void:
	if _dead or texture == null or hframes != FRAMES_PER_ROW:
		return
	if _one_shot != "":
		_elapsed += delta
		if _elapsed < _one_shot_duration:
			var row := 2 if _one_shot == "attack" else 3
			var pose := mini(int(_elapsed / _one_shot_duration * FRAMES_PER_ROW), FRAMES_PER_ROW - 1)
			frame = row * FRAMES_PER_ROW + pose
			return
		_one_shot = ""
		_elapsed = 0.0
		_last_clip = ""
	var clip := "walk" if _moving else "idle"
	if clip != _last_clip:
		_elapsed = 0.0
		_walk_pose = 0
		_last_clip = clip
	_elapsed += delta
	if _moving:
		var duration := SPRINT_CYCLE if _sprinting else WALK_CYCLE
		var step := duration / float(FRAMES_PER_ROW)
		if _elapsed >= step:
			_elapsed = fmod(_elapsed, step)
			_walk_pose = (_walk_pose + 1) % FRAMES_PER_ROW
		frame = FRAMES_PER_ROW + _walk_pose
	else:
		frame = IDLE_SEQUENCE[int(_elapsed / IDLE_STEP) % IDLE_SEQUENCE.size()]
