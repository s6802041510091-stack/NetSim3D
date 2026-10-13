# ภารกิจที่ 1 — NetPlan EDU (เลือกอุปกรณ์เครือข่ายห้องคอม)

โปรแกรมจำลองบนคอมพิวเตอร์ในเกม ผู้เล่นเลือกอุปกรณ์ให้จุดติดตั้ง 3 จุดบนผังห้องคอมที่ล็อกไว้ แล้วกด "ตรวจสอบแบบ"

## ขั้นตอนในเกม

1. เดินไปที่คอมพิวเตอร์ของผู้เล่น (IT-PC-01 ห้อง IT Support) จะขึ้นข้อความ `กด E เพื่อใช้งานคอมพิวเตอร์ (IT-PC-01)`
2. กด E: ระบบล็อกการเดิน การวิ่ง และกล้อง กล้องเลื่อนเข้าหน้าจอ แล้วแสดงหน้า Set-up ประมาณ 2 วินาที (DesktopOS เดิม)
3. หน้า Desktop มีไอคอน **NetPlan EDU**
4. เปิดโปรแกรมแล้วจะเห็นไฟล์ Project `ภารกิจที่ 1 — เลือกอุปกรณ์เครือข่ายห้องคอม`
5. ทำภารกิจสำเร็จแล้วกด `กลับสู่ Desktop` หรือ `ออกจากคอมพิวเตอร์`
6. ออกจากคอมพิวเตอร์แล้ว Mouse Mode กลับเป็น Captured ผู้เล่นเดินและหันกล้องได้ตามเดิม

ปุ่ม Esc ทำงานตามลำดับ: ปิด Popup → ปิดหน้าข้อมูล (ถ้าเปิดอยู่) → ปิดโปรแกรม → ออกจากคอมพิวเตอร์

## ไฟล์

| ไฟล์ | หน้าที่ |
|---|---|
| `scenes/missions/mission_01/netplan_edu.tscn` | **Scene หลักของภารกิจ** (ตัวโปรแกรม NetPlan EDU) |
| `scenes/missions/mission_01/equipment_point.tscn` | ปุ่มจุดติดตั้ง 1–3 บนผังห้อง |
| `scenes/missions/mission_01/equipment_popup.tscn` | Popup เลือกอุปกรณ์ |
| `scenes/missions/mission_01/mission_01_test.tscn` | ฉากทดสอบ (กด F6) ใช้ DesktopOS จริง ไม่ต้องโหลดแผนที่ 3D |
| `data/missions/mission_01/mission_01_data.tres` | คำถาม ตัวเลือก คำตอบ คะแนน คำใบ้ ข้อกำหนด (แก้ใน Inspector ได้) |
| `scripts/missions/mission_01/equipment_question.gd` | Resource ของจุดติดตั้ง 1 จุด |
| `scripts/missions/mission_01/mission_01_data.gd` | Resource ข้อมูลภารกิจทั้งหมด |
| `scripts/missions/mission_01/mission_01_state.gd` | สถานะผู้เล่น (คำตอบ คะแนน จำนวนครั้งที่ตรวจ ฯลฯ) |
| `scripts/missions/mission_01/mission_01_validator.gd` | ตรวจแบบและคิดคะแนน |
| `scripts/missions/mission_01/mission_01_save_store.gd` | บันทึก/โหลดไฟล์ JSON ใน `user://netsim3d/mission_01_save.json` |
| `scripts/missions/mission_01/room_plan_view.gd` | วาดผังห้อง เส้นสาย LAN (ดูได้อย่างเดียว) |
| `scripts/missions/mission_01/netplan_edu.gd` | เชื่อม UI ทั้งหมดเข้าด้วยกัน |
| `scripts/missions/mission_01/netplan_theme.gd` | สี ฟอนต์ และ Theme |
| `scripts/missions/mission_01/mission_01_test_bench.gd` | ฉากทดสอบ: `open_computer()`, `open_mission()`, `close_mission()`, `exit_computer()` |
| `tools/validate_mission_01.gd` | ทดสอบอัตโนมัติ 19 ข้อ |
| `assets/fonts/Sarabun-*.ttf` | ฟอนต์ไทย (SIL OFL) ให้ภาษาไทยแสดงผลบน Web Export |

## สัญญาณ (Signals)

- `EquipmentPoint.equipment_point_opened(point_id)`
- `EquipmentPopup.equipment_selected(point_id, option)`, `answer_confirmed(point_id, option)`
- `NetPlanEdu.validation_requested`, `mission_completed(final_score, check_count, ever_wrong_count)`, `computer_exit_requested`, `close_requested`
- `NetPlanEdu` ส่งต่อ `equipment_point_opened`, `equipment_selected`, `answer_confirmed` ให้ระบบภายนอกฟังได้จากที่เดียว
- `DesktopOS.app_opened("netplan_edu", app)` ใช้ต่อระบบภารกิจหลัก/รางวัลในอนาคต

## กติกาคะแนน

- เริ่ม 100 คะแนน: จุดที่ 1 = 30, จุดที่ 2 = 40, จุดที่ 3 = 30
- ต้องเลือกครบ 3 จุดก่อนตรวจ (ถ้าไม่ครบจะแจ้งเลขจุดที่ยังไม่เลือก และไม่นับเป็นการตรวจ)
- ตรวจแล้วจุดที่ผิดถูกหัก 5 คะแนน และหักซ้ำทุกครั้งที่ตรวจถ้ายังผิด คะแนนไม่ต่ำกว่า 0
- เปลี่ยนคำตอบก่อนตรวจไม่เสียคะแนน จุดที่ตรวจแล้วถูกจะล็อกไว้
- ผ่านแล้วเปิดใหม่จะเห็นหน้าผลลัพธ์ ทำซ้ำเพื่อเพิ่มคะแนนไม่ได้

## ข้อมูลที่บันทึก

`answers`, `point_scores`, `point_results`, `current_score`, `check_count`, `ever_wrong`, `passed`, `final_score`, `reward_claimed`
ถ้าในอนาคตมีระบบ Save กลาง ให้เรียก `Mission01State.to_dict()` / `from_dict()` แทน `Mission01SaveStore`

## ทดสอบ

- เปิด `scenes/missions/mission_01/mission_01_test.tscn` แล้วกด F6 (ปุ่ม "ล้างข้อมูลบันทึก" ใช้เริ่มใหม่)
- หรือรันเกมหลัก (F5) แล้วเดินไปที่ IT-PC-01
- ทดสอบอัตโนมัติ: `godot --headless --path net-sim-3d -s res://tools/validate_mission_01.gd`

## ตั้งค่าเครื่องที่ติดตั้งโปรแกรม

`main.tscn` → node `Computers` → Inspector → `Netplan Edu Hosts` (ค่าเริ่มต้น `["IT-PC-01"]`)
