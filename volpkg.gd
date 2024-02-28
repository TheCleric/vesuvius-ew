extends RefCounted

class_name VolPkg

var material_thickness: float
var name: String
var version: int
var base_path: String
var volumes_directory: String = "volumes"

var _cached_volumes: PackedStringArray = []

var volumes: PackedStringArray:
	get:
		if len(_cached_volumes) == 0:
			var volumes_path = base_path + "/" + volumes_directory + "/" + DirAccess.get_directories_at(base_path + "/volumes")[0]
			_cached_volumes = PackedStringArray(
				Array(DirAccess.get_files_at(volumes_path))
					.filter(func (x): return x.ends_with('.tif') or x.ends_with('.tiff'))
					.map(func (x): return volumes_path + "/" + x)
			)
		return _cached_volumes

static func load_from_file(filename: String, volumes_directory_: String = "volumes") -> VolPkg:
	if not filename.ends_with('.volpkg'):
		return null
	
	filename += "/config.json"
	
	var json_data = JSON.parse_string(FileAccess.get_file_as_string(filename))
	
	return VolPkg.new(
		json_data["name"],
		json_data["version"],
		filename.substr(0, len(filename) - len("/config.json")),
		json_data.get("materrialthickness", -1),
		volumes_directory_,
	)

func _init(name_: String, version_: int, base_path_: String, material_thickness_: float = -1.0, volumes_directory_: String = "volumes"):
	name = name_
	version = version_
	base_path = base_path_
	material_thickness = material_thickness_
	volumes_directory = volumes_directory_


