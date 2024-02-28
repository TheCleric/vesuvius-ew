extends Node3D

var texture_z: float = 0.0
var texture: ImageTexture
var x_angle: float = 0.0
var y_angle: float = PI / 4
var distance: float = 28.0
var look_at_offset: Vector3 = Vector3.ZERO
var black_under: float = 0.0

signal mouse_moved
signal mouse_button

func fmod(value: float, mod: float) -> float:
	while value > mod:
		value -= mod
	while  value < mod:
		value += mod
	return value

# Called when the node enters the scene tree for the first time.
func _ready():
	mouse_moved.connect(mouse_move_event)
	mouse_button.connect(mouse_button_event)
	var flipped_mesh = $SubViewport/CSGMesh3D/MeshInstance3D.duplicate()
	flipped_mesh.position = $SubViewport/CSGMesh3D/MeshInstance3D.position
	flipped_mesh.mesh = PlaneMesh.new()
	flipped_mesh.mesh.flip_faces = true
	$SubViewport/CSGMesh3D.add_child(flipped_mesh)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	look_at_offset.y = $SubViewport/CSGMesh3D/MeshInstance3D.global_position.y
	$SubViewport/Camera3D.position.x = sin(x_angle) * distance + look_at_offset.x
	$SubViewport/Camera3D.position.y = sin(y_angle) * distance + look_at_offset.y
	$SubViewport/Camera3D.position.z = cos(x_angle) * distance + look_at_offset.z
	$SubViewport/Camera3D.look_at(look_at_offset)
	for mesh in $SubViewport/CSGMesh3D.get_children().filter(func (x): return x is MeshInstance3D):
		mesh = (mesh as MeshInstance3D)
		mesh.scale.x = $SubViewport/CSGMesh3D.scale.x / 2.0
		mesh.scale.z = $SubViewport/CSGMesh3D.scale.z / 2.0
		mesh.position.y = $SubViewport/CSGMesh3D.scale.y * (texture_z - 0.5)
		if texture:
			var material = mesh.get_surface_override_material(0)
			if not material:
				material = mesh.mesh.material
			if not material:
				material = StandardMaterial3D.new()
			material.albedo_texture = texture
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.set_surface_override_material(0, material)
			mesh.mesh.material = material

func mouse_move_event(event: InputEventMouseMotion):
	if not event.button_mask:
		return
	if event.button_mask == 1:
		x_angle += fmod(event.relative.x / 100.0, TAU)
		y_angle += fmod(event.relative.y / 100.0, TAU)
	#if event.button_mask == 2:
		#var scaled_adjustment = event.relative * distance / 250.0
		#look_at_offset += Vector3(scaled_adjustment.x, -scaled_adjustment.y, 0)

func mouse_button_event(event: InputEventMouseButton):
	if event.button_mask == 8:
		distance = max(distance - 0.5, 1)
	if event.button_mask == 16:
		distance += 0.5
