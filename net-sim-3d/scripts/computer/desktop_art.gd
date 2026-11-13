class_name DesktopArt
extends RefCounted

const WALLPAPER := preload("res://assets/ui/desktop/wallpaper-blue.png")
const SYSTEM_ICONS := preload("res://assets/ui/desktop/system-icons.png")
const NETPLAN := preload("res://assets/ui/desktop/netplan-edu.png")
static var _cache := {}

static func icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var texture: Texture2D
	if id == "netplan_edu":
		texture = _atlas(NETPLAN, Rect2(249, 281, 765, 714))
	elif id in ["this_pc", "network", "cmd", "bin"]:
		var index: int = ["this_pc", "network", "cmd", "bin"].find(id)
		var regions := [Rect2(130, 155, 384, 357), Rect2(723, 154, 416, 336), Rect2(122, 780, 388, 312), Rect2(778, 750, 324, 367)]
		texture = _atlas(SYSTEM_ICONS, regions[index])
	else:
		var svg := _svg(id)
		var image := Image.new()
		image.load_svg_from_string(svg)
		texture = ImageTexture.create_from_image(image)
	_cache[id] = texture
	return texture

static func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	# Pre-measured opaque bounds: no source edits or GPU pixel readback at runtime.
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas

static func _svg(id: String) -> String:
	var paths := ""
	match id:
		"start": paths = '<path fill="#078be4" d="M5 5h24v24H5zm30 0h24v24H35zM5 35h24v24H5zm30 0h24v24H35z"/>'
		"folder": paths = '<path fill="#e5a116" d="M4 12h23l6 7h27v36H4z"/><path fill="#ffcf45" d="M4 22h56v33H4z"/><path fill="#f1b623" d="M4 38h56v17H4z"/><path fill="#2799d9" d="M19 40h25v15H19z"/>'
		"search": paths = '<circle cx="27" cy="26" r="16" fill="none" stroke="#20364c" stroke-width="4"/><path d="m39 39 15 15" stroke="#20364c" stroke-width="5" stroke-linecap="round"/>'
		"ethernet": paths = '<g fill="none" stroke="#20364c" stroke-width="4" stroke-linejoin="round"><rect x="9" y="8" width="46" height="32" rx="3"/><path d="M32 40v9m-12 5h24M3 50h9m-4-4v8"/></g>'
		"volume": paths = '<path d="M7 25h11l15-12v38L18 39H7z" fill="#20364c"/><path d="M41 22q13 10 0 20m8-29q23 19 0 38" fill="none" stroke="#20364c" stroke-width="4" stroke-linecap="round"/>'
		"windows_security": paths = '<path d="M32 4 56 14v18c0 14-16 24-24 29C24 56 8 46 8 32V14z" fill="#168be4"/><path d="M32 10v45c12-8 18-15 18-23V18z" fill="#0a59a9"/><path d="m21 32 8 8 16-18" stroke="white" stroke-width="5" fill="none" stroke-linecap="round"/>'
		"teamviewer": paths = '<rect x="4" y="4" width="56" height="56" rx="12" fill="#087cdb"/><circle cx="32" cy="32" r="22" fill="white"/><path d="m12 32 12-10v7h16v-7l12 10-12 10v-7H24v7z" fill="#087cdb"/>'
		"browser": paths = '<circle cx="32" cy="32" r="26" fill="#1a8ae6"/><g fill="none" stroke="white" stroke-width="3"><circle cx="32" cy="32" r="22"/><ellipse cx="32" cy="32" rx="10" ry="22"/><path d="M10 32h44M14 21h36M14 43h36"/></g>'
		_: paths = '<circle cx="32" cy="32" r="24" fill="#237db1"/>'
	return '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">' + paths + '</svg>'
