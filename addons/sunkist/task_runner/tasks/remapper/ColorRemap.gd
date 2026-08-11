@tool
class_name ColorRemap
extends Resource

@export var source: ColorPalette:
	set(value):
		if source == value: return

		if source:
			source.changed.disconnect(emit_changed)

		source = value

		if source:
			source.changed.connect(emit_changed)

		emit_changed()


@export var target: ColorPalette:
	set(value):
		if target == value: return

		if target:
			target.changed.disconnect(emit_changed)

		target = value

		if target:
			target.changed.connect(emit_changed)

		emit_changed()


func validate() -> PackedStringArray:
	var result: PackedStringArray

	if source.colors.size() != target.colors.size():
		result.push_back("Source and target palettes must be the same size!")

	else:
		var seen_source_colors: PackedColorArray
		for color in source.colors:
			if color in seen_source_colors: continue

			seen_source_colors.push_back(color)
			if source.colors.count(color) > 1:
				result.push_back("The color #%s exists in the source palette multiple times." % color.to_html())


	return result


func serialize() -> String:
	if not validate().is_empty():
		return ""

	var result := ""
	for i in source.colors.size():
		result += source.colors[i].to_html()
		result += target.colors[i].to_html()

	return result


func deserialize(data: String) -> void:
	var source_colors := PackedColorArray()
	source_colors.resize(data.length() / 16)

	var target_colors := PackedColorArray()
	target_colors.resize(source_colors.size())

	for i in source_colors.size():
		source_colors[i] = Color.html(data.substr(i * 16, 8))
		target_colors[i] = Color.html(data.substr(i * 16 + 8, 8))

	source = ColorPalette.new()
	source.colors = source_colors

	target = ColorPalette.new()
	target.colors = target_colors
