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
| `missions/mission_01/scenes/netplan_edu.tscn` | **Scene หลักของภารกิจ** (ตัวโปรแกรม NetPlan EDU) |
| `missions/mission_01/scenes/equipment_point.tscn` | ปุ่มจุดติดตั้ง 1–3 บนผังห้อง |
| `missions/mission_01/scenes/equipment_popup.tscn` | Popup เลือกอุปกรณ์ |
| `missions/mission_01/scenes/mission_01_test.tscn` | ฉากทดสอบ (กด F6) ใช้ DesktopOS จริง ไม่ต้องโหลดแผนที่ 3D |
| `missions/mission_01/data/mission_01_data.tres` | คำถาม ตัวเลือก คำตอบ คะแนน คำใบ้ ข้อกำหนด (แก้ใน Inspector ได้) |
| `missions/mission_01/scripts/equipment_question.gd` | Resource ของจุดติดตั้ง 1 จุด |
| `missions/mission_01/scripts/mission_01_data.gd` | Resource ข้อมูลภารกิจทั้งหมด |
| `missions/mission_01/scripts/mission_01_state.gd` | สถานะผู้เล่น (คำตอบ คะแนน จำนวนครั้งที่ตรวจ ฯลฯ) |
| `missions/mission_01/scripts/mission_01_validator.gd` | ตรวจแบบและคิดคะแนน |
| `missions/mission_01/scripts/mission_01_save_store.gd` | บันทึก/โหลดไฟล์ JSON ใน `mission_01_save.json` (โฟลเดอร์จาก `SavePaths`: Editor = `net-sim-3d/.saves/`, เว็บ = `user://netsim3d/`) |
| `missions/mission_01/scripts/room_plan_view.gd` | วาดผังห้อง เส้นสาย LAN (ดูได้อย่างเดียว) |
| `missions/mission_01/scripts/netplan_edu.gd` | เชื่อม UI ทั้งหมดเข้าด้วยกัน |
| `missions/mission_01/scripts/netplan_theme.gd` | สี ฟอนต์ และ Theme |
| `missions/mission_01/scripts/mission_01_test_bench.gd` | ฉากทดสอบ: `open_computer()`, `open_mission()`, `close_mission()`, `exit_computer()` |
| `tools/validate_mission_01.gd` | ทดสอบอัตโนมัติ 19 ข้อ |
| `assets/fonts/Sarabun-*.ttf` | ฟอนต์ไทย (SIL OFL) ให้ภาษาไทยแสดงผลบน Web Export |

## สัญญาณ (Signals)

- `EquipmentPoint.equipment_point_opened(point_id)`
- `EquipmentPopup.equipment_selected(point_id, option)`, `answer_confirmed(point_id, option)`
- `NetPlanEdu.validation_requested`, `mission_completed(final_score, check_count, ever_wrong_count)`, `computer_exit_requested`, `close_requested`
- `NetPlanEdu` ส่งต่อ `equipment_point_opened`, `equipment_selected`, `answer_confirmed` ให้ระบบภายนอกฟังได้จากที่เดียว
- `DesktopOS.app_opened("netplan_edu", app)` ใช้ต่อระบบภารกิจหลัก/รางวัลในอนาคต

## ลำดับในด่าน (Mission01Controller)

1. คุยกับหัวหน้างาน Data Center (มอง + กด F) → "ได้รับภารกิจ" เริ่มจับเวลา และ NetPlan EDU ปรากฏบน IT-PC-01
2. แต่ละจุดมีอุปกรณ์ 4 ชนิด (ถูก 1 ลวง 3 สลับลำดับ) เป็นการ์ดมีรูป (`assets/ui/devices/*.svg`) และชื่อ
   คลิกการ์ด = เลือกอุปกรณ์ → "เลือก ... เพราะ…" 4 ตัวเลือก (`data/mission_01_reasons.json`) → "ยืนยันจุดนี้"
3. "ตรวจสอบแบบ" จนผ่าน → ออกจากคอม → รายงานหัวหน้างาน → หน้าสรุปผล (เล่นอีกครั้ง / เมนูหลัก / ด่านถัดไป)

ทุกครั้งที่เริ่มด่าน 1 เป็นการเล่นใหม่ ระบบล้างไฟล์บันทึกของด่าน 1

## กติกาคะแนน (MissionScore 30/50/20)

- **ความถูกต้อง 30**: จุดละ 10 จุดจะถูกเมื่อเลือกอุปกรณ์ถูก ตรวจแล้วผิดหักจุดละ 5 ทุกครั้งที่ยังผิด ไม่ต่ำกว่า 0
- **กระบวนการ 50**: 50 × (คำตอบที่ถูก ÷ ทั้งหมด) นับอุปกรณ์+เหตุผลที่ยืนยันครั้งแรกของแต่ละอุปกรณ์
  (ถูกเมื่ออุปกรณ์ถูกและเหตุผลถูก)
- **เวลา 20**: เต็มเมื่อไม่เกิน 5 นาที ลดลงจนเป็น 0 ที่ 15 นาที (ค่าชั่วคราวใน `mission_01_data.tres`)
- ผ่านที่ 50 ดาว 1/2/3/รุ้ง ที่ 50/60/70/80 ผลบันทึกใน `progress.json` (GameProgress) เพื่อปลดล็อกด่าน
- ต้องเลือกครบ 3 จุดก่อนตรวจ เปลี่ยนคำตอบก่อนตรวจไม่เสียคะแนน จุดที่ตรวจแล้วถูกจะล็อกไว้

## ข้อมูลที่บันทึก

`answers`, `reasons`, `scored_reasons` (รวมความเข้าใจผิดที่เลือก),
`point_scores`, `point_results`, `current_score`, `check_count`, `ever_wrong`, `passed`, `final_score`
ถ้าในอนาคตมีระบบ Save กลาง ให้เรียก `Mission01State.to_dict()` / `from_dict()` แทน `Mission01SaveStore`

## ทดสอบ

- เปิด `missions/mission_01/scenes/mission_01_test.tscn` แล้วกด F6 (ปุ่ม "ล้างข้อมูลบันทึก" ใช้เริ่มใหม่)
- หรือรันเกมหลัก (F5) แล้วเดินไปที่ IT-PC-01
- ทดสอบอัตโนมัติ: `godot --headless --path net-sim-3d -s res://tools/validate_mission_01.gd`

## ตั้งค่าเครื่องที่ติดตั้งโปรแกรม

`main.tscn` → node `Computers` → Inspector → `Netplan Edu Hosts` (ค่าเริ่มต้น `["IT-PC-01"]`)
