extends Camera3D

@export var capture_mouse_on_ready: bool = true
@export var mouse_sensitivity: float = 0.0025
@export_range(-89.0, 0.0, 0.1) var min_pitch_deg: float = -85.0
@export_range(0.0, 89.0, 0.1) var max_pitch_deg: float = 85.0

@export var move_speed: float = 10.0
@export var sprint_multiplier: float = 3.0
@export var accel: float = 18.0
@export var decel: float = 22.0

@export var enable_fly_vertical: bool = true
@export var toggle_mouse_key: Key = KEY_ESCAPE
@export var make_current_on_ready: bool = true

var _yaw: float = 0.0
var _pitch: float = 0.0
var _vel: Vector3 = Vector3.ZERO

func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	if make_current_on_ready:
		make_current()
	if capture_mouse_on_ready:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == toggle_mouse_key:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		rotation = Vector3(_pitch, _yaw, 0.0)

func _physics_process(delta: float) -> void:
	var wish := Vector3.ZERO

	# Prefer custom actions; fallback to ui_* if you haven't added them yet.
	var forward := _axis("move_forward", "ui_up")
	var back := _axis("move_backward", "ui_down")
	var left := _axis("move_left", "ui_left")
	var right := _axis("move_right", "ui_right")

	var x := right - left
	var z := back - forward

	wish += global_transform.basis.x * x
	wish += -global_transform.basis.z * (-z)

	if enable_fly_vertical:
		var up := _axis("move_up", "")
		var down := _axis("move_down", "")
		wish += global_transform.basis.y * (up - down)

	if wish.length() > 0.0001:
		wish = wish.normalized()

	var spd := move_speed
	var sprint_pressed := Input.is_key_pressed(KEY_SHIFT)
	if InputMap.has_action(&"move_sprint"):
		sprint_pressed = sprint_pressed or Input.is_action_pressed(&"move_sprint")

	if sprint_pressed:
		spd *= sprint_multiplier

	var target_vel := wish * spd
	var rate := accel if wish.length() > 0.0 else decel
	_vel = _vel.lerp(target_vel, 1.0 - exp(-rate * delta))

	global_position += _vel * delta

func _axis(primary: StringName, fallback: StringName) -> float:
	var v := 0.0
	if primary != "" and InputMap.has_action(primary):
		v = Input.get_action_strength(primary)
	elif fallback != "" and InputMap.has_action(fallback):
		v = Input.get_action_strength(fallback)
	return v
