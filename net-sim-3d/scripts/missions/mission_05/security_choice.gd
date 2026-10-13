class_name SecurityChoice
extends Resource

## One answer button in Windows Security (Mission 5), e.g. "ปิดกั้นการเชื่อมต่อ".
## Edit the texts in data/missions/mission_05/mission_05_data.tres.

@export var choice_id: String = ""
@export var label: String = ""
## Small grey line under the label.
@export var description: String = ""
@export var is_correct: bool = false
## Shown when this wrong choice is picked. It must not give the answer away.
@export_multiline var hint: String = ""
