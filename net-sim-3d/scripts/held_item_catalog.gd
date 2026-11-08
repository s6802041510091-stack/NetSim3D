extends RefCounted

## Original project models; transforms only, no substitute geometry.
## Handle coordinates refer to each source GLB's local space.
const TOOLS := {
	"crimping_tool": {
		"title": "คีมย้ำสาย LAN",
		"scene": preload("res://assets/models/tools/crimping_tool.glb"),
		"hand_scene": preload("res://assets/models/tools/hand_crimping_tool.glb"),
		"fit_offset": Vector3(0.015, -0.040, 0.019),
		"rotation": Vector3(0, -15, 105),
		"scale": 1.15,
		"handle": Vector3(-0.11, 0, 0),
	},
	"cable_stripper": {
		"title": "คีมปอกสาย",
		"scene": preload("res://assets/models/tools/cable_stripper.glb"),
		"hand_scene": preload("res://assets/models/tools/hand_cable_stripper.glb"),
		"fit_offset": Vector3(0.020, -0.060, -0.020),
		"rotation": Vector3(0, -15, 105),
		"scale": 1.5,
		"handle": Vector3(-0.035, 0.011, 0),
	},
	"cable_tester": {
		"title": "เครื่องทดสอบสาย LAN",
		"scene": preload("res://assets/models/tools/cable_tester.glb"),
		"hand_scene": preload("res://assets/models/tools/hand_cable_tester.glb"),
		"fit_offset": Vector3(-0.020, -0.040, 0.020),
		"rotation": Vector3(85, -15, 15),
		"scale": 1.5,
		"handle": Vector3(0, 0.005, 0.025),
		"offset": Vector3(-0.045, 0.025, 0),
	},
}
