# Corridor student life

Five approved characters are instanced in `scenes/npc/corridor_students.tscn`, which is part of `scenes/main.tscn` and therefore shared by all six levels.

| Character | Repeating routine |
| --- | --- |
| Male mullet | Walk the west side, pause, rest on BenchLeft03, visit the science shoe rack, return. |
| Male two-block | Meet Wendy, chat, rest on BenchRight01, check the computer-class shoe rack, return. |
| Female bob | Rest on BenchLeft01, visit the computer-class shoe rack, look toward the south-end windows, return. |
| Female Wendy | Meet the two-block student, chat, walk farther down the corridor, rest on BenchRight03, return. |
| Female layer | Walk toward the north-end windows, pause, rest on BenchRight04, pause opposite the stairs, return. |

## Implementation

- Approved exports copied unchanged from `D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/exports/characters/student_*.glb` to `assets/models/students/`. All five have the MakeHuman rig, 163 bones. No Blender character sources are changed.
- `scripts/npc/student_life.gd` defines individual world-space routes, activity times and the chat partner pair. Scene properties expose each student's speed and animation phase.
- `scripts/npc/student_character.gd` extends the existing `NpcCharacter` to reuse its rig and arm IK. Walking uses CharacterBody3D collisions; authored clear routes cover this school corridor. Nearby students steer to pass and yield to the player. Students are solid on the existing character collision layer.
- Individual rhythms/speeds, opposite arm/leg gait, breathing, looking around, looking down at the shoe racks, chat gestures, blended sitting/standing. Hands rest on knees when seated. Each seat is assigned to only one student.
- `student_pose_support.gd` adds world-space foot contacts during sitting/standing, scale-aware pelvis height, relaxed arm IK that preserves the shirt shoulder seams, and local corrective garment blend shapes. These are per-instance runtime mesh copies; approved Blender/GLB files are unchanged. Walking grounds the supporting sole. The two chatting students alternate speaking/listening gestures; there is no voice-synchronized lip animation.
- A temporary collision exception applies only between the sitting student and that student's bench. The physical capsule and player collision remain active. A seated student waits for a clear exit before standing.
- Routines respect game pause; entering a new level starts the ambient loops again. No changes to scoring, objectives, mission dialogue or computer apps.
- Skeletal posing runs at 20 Hz within 24m of the current camera; physics movement remains active farther away. Students use existing approved geometry and textures; this change does not include asset size reduction or a new web export.

## Checks and actual captures

Run `tools/validate_students.gd` to exercise several full loops, route clearance, five rigs, five bench activities, paired conversation, player yielding, solid NPC collision and pause/resume.

Validation passed: all five completed at least two full loops; paired chat, all five bench activities, player yield/resume, physical NPC collision and pause checks passed. Distant students also update their seated/standing posture even when regular gait posing is culled.

The subsequent animation audit found and fixed transient foot penetration and fabric/seat intersections. `tools/validate_student_pose_contacts.gd` now passes 210 sit/stand samples, 120 walking phases and a player entering the swept stand-up path. See `Preview/โถงทางเดิน/students/ANIMATION_AUDIT.md` for measurements and visual evidence.

`tools/capture_students.gd` records the actual running Godot scene in `D:/NetSim3D/Preview/โถงทางเดิน/students/`:

- `corridor-students.png`
- `bench-rest.png`
- `friends-chat.png`

Open the normal Godot project and press F5 to see the students while playing. The ambient activity does not add interaction prompts or required tasks.
