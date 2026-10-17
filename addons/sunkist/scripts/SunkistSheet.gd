## Manages SunkistSheet data files and generates/updates sub-resources, including multiple [SunkistAtlasTexture] and [SunkistTexture].
@icon("res://addons/sunkist/ui/icons/SunkistTexture.svg")
@tool
class_name SunkistSheet
extends Resource

const VALID_EXTENSIONS: PackedStringArray = [
	"sun",
	"sunkist",
]

const SHEET_DIR := "sheet"
const SPRITE_DIR := "sprite"
const SUNKIST_DIR := "sunkist"


static var REMAP_ARRAY_DEFAULT: PackedStringArray = [
	&"-r-a",
	&"-l-a",
	&"-r-e",
	&"-l-e",
	&"-r-m",
	&"-l-m",
	&"-r-n",
	&"-l-n",
]

@export_tool_button("Refresh Resources")
var _refresh_resources_tool_button : Callable = refresh_resources

@export_storage
var json_path: String


func _get_remap_index(key: StringName) -> int:
	return REMAP_ARRAY_DEFAULT.find(key)


func refresh_resources() -> void:
	var base_folder := json_path.get_base_dir()
	var sheet_dir := base_folder.path_join(SHEET_DIR)
	var sunkist_dir := base_folder.path_join(SUNKIST_DIR)
	var sprite_dir := base_folder.path_join(SPRITE_DIR)

	if not DirAccess.dir_exists_absolute(sheet_dir):
		DirAccess.make_dir_recursive_absolute(sheet_dir)
	if not DirAccess.dir_exists_absolute(sprite_dir):
		DirAccess.make_dir_recursive_absolute(sprite_dir)
	if not DirAccess.dir_exists_absolute(sunkist_dir):
		DirAccess.make_dir_recursive_absolute(sunkist_dir)

	var existing_sprites := SunkistUtils.get_paths_in_folder(sprite_dir)
	var existing_sunkists := SunkistUtils.get_paths_in_folder(sunkist_dir)

	var images: Array[Texture2D]
	for i in SunkistUtils.get_paths_in_folder(sheet_dir, RegEx.create_from_string(".png$")):
		images.push_back(load(i))

	var fresh_paths: PackedStringArray = []
	var created_paths: Dictionary

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		printerr("SunkistSheet: null file at path '%s'" % json_path)
		return

	var data: Dictionary = JSON.parse_string(file.get_as_text())

	var sheet: Dictionary = data[SHEET_DIR]
	for k in sheet.keys():
		var sheet_texture: Texture2D = load(sheet_dir.path_join(k))
		for sprite_name in sheet[k].keys():
			var coord: Array = sheet[k][sprite_name]
			var source_offset := Vector2i(coord[2], coord[3])
			var target_region := Rect2i(coord[0], coord[1], coord[4], coord[5])

			var sprite_path: String = sprite_dir.path_join(sprite_name + ".res")
			var sprite: SunkistAtlasTexture
			if FileAccess.file_exists(sprite_path):
				sprite = load(sprite_path)
			else:
				sprite = SunkistAtlasTexture.new()

			sprite.name = sprite_name
			sprite.atlas = sheet_texture
			sprite.offset = Vector2i(source_offset)
			sprite.region = Rect2(target_region)
			sprite.filter_clip = true

			ResourceSaver.save(sprite, sprite_path)
			created_paths[sprite.name] = sprite_path

	fresh_paths.append_array(created_paths.values())

	var sunkist_data: Dictionary = data[SUNKIST_DIR]
	for base_name in sunkist_data.keys():
		var base: Dictionary = sunkist_data[base_name]

		var sunkist_path: String = sunkist_dir.path_join(base_name + ".res")
		var sunkist: SunkistTexture
		if FileAccess.file_exists(sunkist_path):
			sunkist = load(sunkist_path)
			sunkist.textures.fill(null)
		else:
			sunkist = SunkistTexture.new()

		var valid_size_target := Vector2.ZERO
		var valid_size : bool = true
		for k in base.keys():
			var tex : Texture2D = load(created_paths[base[k]])
			sunkist.textures[_get_remap_index(k)] = tex

			if valid_size_target:
				if tex.get_size() != valid_size_target:
					valid_size = false
			else:
				valid_size_target = tex.get_size()

		if not valid_size_target:
			printerr(
				"Sunkist '%s' does not have any subtextures. It will be invisible and may throw errors." % [
					sunkist_path,
				]
			)
		if not valid_size:
			printerr(
				"Sunkist '%s' has subtextures with differing sizes. This may lead to visual errors." % [
					sunkist_path,
			])


		ResourceSaver.save(sunkist, sunkist_path)
		fresh_paths.append(sunkist_path)

	var dir := DirAccess.open(sprite_dir)
	for path in existing_sprites: if path not in fresh_paths:
		dir.remove(path)

	dir = DirAccess.open(sunkist_dir)
	for path in existing_sunkists: if path not in fresh_paths:
		dir.remove(path)
