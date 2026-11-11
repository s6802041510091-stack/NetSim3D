# ตัวละครสำหรับนำเข้า Godot

ส่งออกจากไฟล์ Blender ฉบับล่าสุดใน `../../blend/` และ `../../blend/students/` โดยไม่แก้โมเดลต้นฉบับ

| กลุ่ม | GLB |
| --- | --- |
| เจ้าหน้าที่ IT Support | `it_support_male_180cm.glb` |
| หัวหน้างาน | `it_support_supervisor_male_170cm.glb` |
| ครูชาย | `teacher_male_khaki_180cm.glb` |
| ครูหญิง | `teacher_female_khaki_160cm.glb` |
| แม่บ้าน | `cleaner_female_apron_160cm.glb` |
| นักเรียนชาย 2 คน | `student_male_mullet.glb`, `student_male_two_block.glb` |
| นักเรียนหญิง 3 คน | `student_female_bob_cut.glb`, `student_female_wendy_cut.glb`, `student_female_layer_cut.glb` |

`validation.json` บันทึกผลตรวจแต่ละไฟล์: เปิด GLB กลับใน Blender แล้วพบโครงกระดูก 163 ชิ้น เมชที่ผูกกับกระดูก และชื่อ `spine05`, `upperarm01.L`, `upperarm01.R`, `lowerarm01.L`, `lowerarm01.R`, `upperleg01.L`, `upperleg01.R`, `lowerleg01.L`, `lowerleg01.R` ครบทุกตัว ครูหญิงและนักเรียนหญิงบ๊อบผ่านการนำเข้า Godot 4.7.1 และตรวจชื่อกระดูกตัวอย่างด้วย

ผมของนักเรียนหญิงบ๊อบใช้การไล่สีแบบ procedural ใน Blender ซึ่ง GLB ไม่รองรับตรง ๆ ขั้นตอนส่งออกจึงใช้สีน้ำตาลดำของวัสดุต้นฉบับแทน ตรวจภาพของ GLB ที่นำเข้ากลับแล้วว่าผมไม่กลายเป็นสีขาว

GLB ชุดนี้ไม่มีคลิปแอนิเมชันในตัว ท่านั่ง ท่าหันหน้า และท่าพิมพ์ทำด้วยสคริปต์ `net-sim-3d/scripts/npc/npc_character.gd` นักเรียนทั้ง 5 คนถูกนำเข้าและวางในฉากหลักแล้ว พร้อมกิจวัตรเดิน นั่งพัก แวะชั้นรองเท้า และคุยกัน ดู `net-sim-3d/STUDENT_LIFE.md` และ `scenes/npc/corridor_students.tscn` สำหรับรายละเอียด

ใช้ `3Dmodel/scripts/export_approved_characters.py` เพื่อส่งออกและตรวจซ้ำเมื่อแก้ต้นฉบับ
