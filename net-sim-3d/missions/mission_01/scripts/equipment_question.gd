class_name EquipmentQuestion
extends Resource

## One install point in Mission 1 (NetPlan EDU).
## Edit the values in missions/mission_01/data/mission_01_data.tres —
## the program reads everything (text, options, answer, score) from here.

## Point number shown on the room plan (1, 2, 3).
@export var point_id: int = 1
## Short name of the point, e.g. "การเชื่อมต่อเครือข่ายภายนอก".
@export var title: String = ""
## Where the device is installed, e.g. "ภายใน Wall Rack 9U หลังโต๊ะครู".
@export var location: String = ""
## The question shown in the pop-up.
@export_multiline var question: String = ""
## Exactly two full device names. Never shorten them
## (Shared Hub, Switched Hub, Router, Wireless Access Point).
@export var options: PackedStringArray = PackedStringArray()
## Must be one of `options`.
@export var correct_option: String = ""
## Full score of this point.
@export var max_score: int = 30
## Short hint for the side panel. It must not give the answer away.
@export_multiline var hint: String = ""
## Marker position on the room plan, in plan units (see RoomPlanView.DESIGN_SIZE).
@export var plan_position: Vector2 = Vector2.ZERO


func is_correct(option: String) -> bool:
	return option != "" and option == correct_option


func has_option(option: String) -> bool:
	return option in options
