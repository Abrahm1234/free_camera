extends Node

@export var skeleton_path: NodePath
@export var look_target_path: NodePath

@export var head_bone_name: StringName = &"Head"
@export var spine_bone_name: StringName = &"Spine"
@export var chest_bone_name: StringName = &"Chest"

@export_range(0.0, 1.0, 0.01) var look_weight: float = 0.65
@export var breathe_amp: float = 0.015
@export var breathe_speed: float = 1.4
@export var lean_max_deg: float = 12.0
@export var lean_smooth: float = 10.0

var _skeleton: Skeleton3D
var _head_idx: int = -1
var _spine_idx: int = -1
var _chest_idx: int = -1
var _lean: float = 0.0


func _ready() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		push_warning("ProceduralAnimator: Skeleton3D not found. Assign skeleton_path to a rigged character skeleton.")
		return

	_head_idx = _skeleton.find_bone(head_bone_name)
	_spine_idx = _skeleton.find_bone(spine_bone_name)
	_chest_idx = _skeleton.find_bone(chest_bone_name)


func _process(delta: float) -> void:
	if _skeleton == null:
		return

	var time_seconds := Time.get_ticks_msec() * 0.001
	_apply_breathing(time_seconds)
	_apply_look_at()
	_apply_lean(delta)


func _apply_breathing(time_seconds: float) -> void:
	if _chest_idx == -1:
		return

	var rest := _skeleton.get_bone_global_rest(_chest_idx)
	var pose := rest
	var z_offset := sin(time_seconds * breathe_speed) * breathe_amp
	pose.origin += pose.basis.z * z_offset
	_skeleton.set_bone_global_pose_override(_chest_idx, pose, 0.35, true)


func _apply_look_at() -> void:
	if _head_idx == -1 or look_target_path == NodePath():
		return

	var target := get_node_or_null(look_target_path) as Node3D
	if target == null:
		return

	var head_rest := _skeleton.get_bone_global_rest(_head_idx)
	var to_target := target.global_position - head_rest.origin
	if to_target.length_squared() < 0.000001:
		return

	var look_basis := Basis.looking_at(to_target.normalized(), Vector3.UP)
	var head_pose := head_rest
	head_pose.basis = look_basis
	_skeleton.set_bone_global_pose_override(_head_idx, head_pose, look_weight, true)

	if _spine_idx == -1:
		return

	var spine_rest := _skeleton.get_bone_global_rest(_spine_idx)
	var spine_pose := spine_rest
	spine_pose.basis = spine_pose.basis.slerp(look_basis, 0.25)
	_skeleton.set_bone_global_pose_override(_spine_idx, spine_pose, look_weight * 0.35, true)


func _apply_lean(delta: float) -> void:
	if _spine_idx == -1:
		return

	var body := get_parent() as CharacterBody3D
	if body == null:
		return

	var world_velocity := body.velocity
	var local_velocity := body.global_transform.basis.inverse() * world_velocity
	var speed := max(world_velocity.length(), 0.01)
	var normalized_sideways := clamp(-local_velocity.x / speed, -1.0, 1.0)
	var target_lean := normalized_sideways * deg_to_rad(lean_max_deg)

	_lean = lerpf(_lean, target_lean, 1.0 - exp(-lean_smooth * delta))

	var spine_rest := _skeleton.get_bone_global_rest(_spine_idx)
	var spine_pose := spine_rest
	spine_pose.basis = spine_pose.basis * Basis(Vector3.FORWARD, _lean)
	_skeleton.set_bone_global_pose_override(_spine_idx, spine_pose, 0.35, true)
