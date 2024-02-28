extends Control

var main_view = preload("res://main_view.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	($ButtonBrowse as Button).pressed.connect(_browse)
	($FileDialog as FileDialog).dir_selected.connect(_file_dialog_dir_selected)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Global.volpkg_root:
		if ($ButtonBrowse as Button).visible:
			$ButtonBrowse.hide()
			$LoadingLabel.show()
		else:
			get_tree().change_scene_to_packed(main_view)

func _browse():
	$ErrorLabel.text = ""
	$FileDialog.show()

func _file_dialog_dir_selected(dir: String):
	if not FileAccess.file_exists(dir + "/config.json") or not DirAccess.dir_exists_absolute(dir + "/volumes"):
		$ErrorLabel.text = "'%s' is not a valid volpkg" % dir
		return
	Global.volpkg_root = dir
