extends "_node_with_animation_player.gd"

const ANIMATION_STRATEGIES_NAMES: PackedStringArray = [
	"Animate single atlas texture's region and margin",
	"Animate multiple atlas textures instances",
]
enum AnimationStrategy {
	SINGLE_ATLAS_TEXTURE_REGION_AND_MARGIN = 1,
	MULTIPLE_ATLAS_TEXTURES_INSTANCES = 2
}

func _init() -> void:
	super("TextureRect with AnimationPlayer", "PackedScene", "scn", [
		_Options.create_option(_Options.ANIMATION_STRATEGY, AnimationStrategy.SINGLE_ATLAS_TEXTURE_REGION_AND_MARGIN,
		PROPERTY_HINT_ENUM, ",".join(ANIMATION_STRATEGIES_NAMES), PROPERTY_USAGE_DEFAULT),
	])

func import(
	res_source_file_path: String,
	export_result: _Common.ExportResult,
	options: Dictionary,
	save_path: String
	) -> _Common.ImportResult:
	var result: _Common.ImportResult = _Common.ImportResult.new()

	var texture_rect: TextureRect = TextureRect.new()
	var node_name: String = options[_Options.ROOT_NODE_NAME].strip_edges()
	texture_rect.name = res_source_file_path.get_file().get_basename() \
		if node_name.is_empty() else node_name
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var sprite_size: Vector2i = export_result.sprite_sheet.source_image_size
	texture_rect.size = sprite_size

	var animation_player: AnimationPlayer
	match options[_Options.ANIMATION_STRATEGY]:

		AnimationStrategy.SINGLE_ATLAS_TEXTURE_REGION_AND_MARGIN:
			var atlas_texture: AtlasTexture = AtlasTexture.new()
			atlas_texture.atlas = export_result.sprite_sheet.atlas
			atlas_texture.filter_clip = options[_Options.ATLAS_TEXTURES_REGION_FILTER_CLIP_ENABLED]
			atlas_texture.resource_local_to_scene = true
			atlas_texture.region = Rect2(0, 0, 1, 1)
			atlas_texture.margin = Rect2(2, 2, 0, 0)
			texture_rect.texture = atlas_texture

			animation_player = _create_animation_player(export_result.animation_library, {
				".:texture:margin": func(frame: _Common.FrameInfo) -> Rect2:
					return \
						Rect2(frame.sprite.offset,
							sprite_size - frame.sprite.region.size) \
						if frame.sprite.region.has_area() else \
						Rect2(2, 2, 0, 0),
				".:texture:region" : func(frame: _Common.FrameInfo) -> Rect2:
					return \
						Rect2(frame.sprite.region) \
						if frame.sprite.region.has_area() else \
						Rect2(0, 0, 1, 1) })

		AnimationStrategy.MULTIPLE_ATLAS_TEXTURES_INSTANCES:
			var atlas_texture_cache: Array[AtlasTexture]
			animation_player = _create_animation_player(export_result.animation_library, {
				".:texture": func(frame: _Common.FrameInfo) -> Texture2D:
					var region: Rect2 = \
						Rect2(frame.sprite.region) \
						if frame.sprite.region.has_area() else \
						Rect2(0, 0, 1, 1)
					var margin: Rect2 = \
						Rect2(frame.sprite.offset,
							sprite_size - frame.sprite.region.size) \
						if frame.sprite.region.has_area() else \
						Rect2(2, 2, 0, 0)
					var cached_result = atlas_texture_cache.filter(func(t: AtlasTexture) -> bool: return t.margin == margin and t.region == region)
					var atlas_texture: AtlasTexture
					if not cached_result.is_empty():
						return cached_result.front()
					atlas_texture = AtlasTexture.new()
					atlas_texture.atlas = export_result.sprite_sheet.atlas
					atlas_texture.filter_clip = true
					atlas_texture.region = region
					atlas_texture.margin = margin
					atlas_texture_cache.append(atlas_texture)
					return atlas_texture})

	texture_rect.add_child(animation_player)
	animation_player.owner = texture_rect

	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(texture_rect)
	result.success(packed_scene,
		ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	return result
