extends Node2D

signal layer_index_changed
var layer_index: int = 0
var volpkg: VolPkg
var black_under = 0.0
var texture_zoom_center: Vector2i = Vector2i.ZERO
var texture_zoom_scale: float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready():
	TIFFImageFormatLoaderExtension.new().add_format_loader()
	if Global.volpkg_root:
		volpkg = VolPkg.load_from_file(Global.volpkg_root, "volumes")
	layer_index_changed.connect(layer_index_changed_handler)
	layer_index_changed.emit()

func _input(event):
	var lt_collision_rect = Rect2($LayerTextureRect.global_position, $LayerTextureRect.size)
	var lct_collision_rect = Rect2($LayerCubeTextureRect.global_position, $LayerCubeTextureRect.size)
	if Input.is_action_pressed("LAYER_DOWN"):
		layer_index -= 1
		layer_index_changed.emit()
	elif Input.is_action_pressed("LAYER_UP"):
		layer_index += 1
		layer_index_changed.emit()
	elif Input.is_action_pressed("LAYER_DOWN_10"):
		layer_index -= 10
		layer_index_changed.emit()
	elif Input.is_action_pressed("LAYER_UP_10"):
		layer_index += 10
		layer_index_changed.emit()
	elif event is InputEventMouseMotion:
		if lct_collision_rect.has_point(event.global_position):
			$LayerCube.mouse_moved.emit(event)
	elif event is InputEventMouseButton:
		if lct_collision_rect.has_point(event.global_position):
			$LayerCube.mouse_button.emit(event)
		if lt_collision_rect.has_point(event.global_position) and event.pressed:
			var layer_texture: ImageTexture = $LayerCube.texture
			var layer_image = layer_texture.get_image()
			var uv_pos = (event.global_position - $LayerTextureRect.global_position) / $LayerTextureRect.size
			var pixel_pos = Vector2i(floori(uv_pos.x * layer_image.get_width()), floori(uv_pos.y * layer_image.get_height()))
			if event.button_index == 1:
				return
				#var pixel = layer_image.get_pixelv(pixel_pos)
				#black_under = max(black_under, pixel.r)
				#$LayerCube.black_under = black_under
				#layer_index_changed.emit()
			elif event.button_index in [4, 5]:
				texture_zoom_scale += 0.05 if event.button_index == 4 else -0.05
				if texture_zoom_scale > 1.0:
					var sub_width = roundi(layer_image.get_width() / texture_zoom_scale)
					var sub_height = roundi(layer_image.get_height() / texture_zoom_scale)
					@warning_ignore("integer_division")
					texture_zoom_center = Vector2i(
						clampi(pixel_pos.x, sub_width / 2, layer_image.get_width() - (sub_width / 2)),
						clampi(pixel_pos.y, sub_height / 2, layer_image.get_height() - (sub_height / 2)),
					)
					@warning_ignore("integer_division")
					var sub_rect = Rect2i(
						texture_zoom_center.x - sub_width / 2,
						texture_zoom_center.y - sub_height / 2,
						sub_width,
						sub_height
					)
					var zoomed_image = $LayerCube.texture.get_image().get_region(sub_rect)
					$LayerTextureRect.texture = ImageTexture.create_from_image(zoomed_image)
				else:
					$LayerTextureRect.texture = $LayerCube.texture
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var vp = get_viewport_rect()
	var texture_size = min(vp.size.x / 2.0, vp.size.y - 200)
	$LayerCubeTextureRect.position.x = vp.position.x
	$LayerCubeTextureRect.position.y = vp.position.y + 100
	$LayerCubeTextureRect.size.x = texture_size
	$LayerCubeTextureRect.size.y = texture_size
	$LayerTextureRect.position.x = vp.size.x / 2.0
	$LayerTextureRect.position.y = 100
	$LayerTextureRect.size.x = texture_size
	$LayerTextureRect.size.y = texture_size
	$LayerLabel.position.x = vp.size.x / 2.0
	$LayerLabel.position.y = 10
	$RightInstructionLabel.position.x = $LayerLabel.position.x

func set_blacks(data: PackedByteArray) -> PackedByteArray:
	if not black_under:
		return data
	var threshhold = floori(black_under * 256)
	for i in range(len(data)):
		if data[i] <= threshhold:
			data[i] = 0
	return data

#func make_transparent(image: Image) -> Image:
	#image.convert(Image.FORMAT_LA8)
	#var new_data = image.get_data()
	#@warning_ignore("integer_division")
	#for i in range(len(new_data) / 2):
		#if new_data[i * 2] == 0:
			#new_data[i * 2 + 1] = 0
	#image.set_data(image.get_width(), image.get_height(), false, image.get_format(), new_data)
	#return image

func layer_index_changed_handler():
	if not volpkg:
		return
	layer_index = clampi(layer_index, 0, len(volpkg.volumes) - 1)
	$LayerLabel.text = "%d/%d" % [layer_index, len(volpkg.volumes) - 1]
	var layer_image = Image.load_from_file(volpkg.volumes[layer_index])
	if black_under:
		layer_image.set_data(
			layer_image.get_width(),
			layer_image.get_height(),
			false,
			layer_image.get_format(),
			set_blacks(layer_image.get_data()),
		)
		#layer_image = make_transparent(layer_image)
	$LayerTextureRect.texture = ImageTexture.create_from_image(layer_image)
	$LayerCube.texture_z = layer_index / (1.0 * len(volpkg.volumes))
	$LayerCube.texture = $LayerTextureRect.texture
	@warning_ignore("integer_division")
	texture_zoom_center = Vector2i(layer_image.get_width() / 2, layer_image.get_height() / 2)
	texture_zoom_scale = 1.0
