extends RefCounted

## A line of speech floating over a character's head: white bold text with a
## dark outline that always faces the camera. Used by the teachers in the staff
## room and by the students chatting in the corridor. The game's translator
## (L10n) picks up the Label3D text, so English mode shows English lines.

const OVER_HEAD := 0.32 # metres above the head bone


## A new bubble over `who`, added to `parent`; hidden until the caller shows
## it (only to a player close enough to overhear). `scale` > 1: larger text,
## for talk overheard from across a corridor.
static func create(parent: Node, who: NpcCharacter, text: String, scale := 1.0) -> Label3D:
	var bubble := Label3D.new()
	bubble.name = "SpeechBubble"
	bubble.text = text
	bubble.font = GameUI.FONT_BOLD
	bubble.font_size = 40
	bubble.pixel_size = 0.0016 * scale
	bubble.outline_size = 12
	bubble.outline_modulate = Color(0.05, 0.08, 0.14, 0.9)
	bubble.modulate = Color(1.0, 1.0, 1.0)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 560.0
	bubble.visible = false
	parent.add_child(bubble)
	bubble.global_position = head_of(who) + Vector3.UP * OVER_HEAD * scale
	return bubble


static func head_of(who: NpcCharacter) -> Vector3:
	var head := who.skeleton.find_bone("head") if who.skeleton else -1
	if head < 0:
		return who.global_position + Vector3.UP * 1.6
	return who.skeleton.global_transform * who.skeleton.get_bone_global_pose(head).origin
