# ด่าน 05 — ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน (Windows Security จำลอง)

บทภารกิจอยู่ที่ `../../../ภารกิจ/ด่าน_05/README.md` (ตกลงรายละเอียดกับผู้พัฒนา 13 พ.ย. 2569)

โปรแกรมจำลองเพื่อการศึกษา ไม่มีการเปิด Windows Security จริง ไม่มีการสแกนเครื่องจริง และไม่มีไฟล์อันตรายจริง ชื่อไฟล์และโปรแกรมเป็นข้อมูลสมมติทั้งหมด

- `scripts/mission_05_controller.gd` — ลำดับด่าน 8 ขั้น (แท็บติดตามมาตรฐาน `ObjectiveHUD.set_steps`): รับสายครูผู้ชาย → ไปที่ PC-R3-L2 (จอสีแดง) → เปิด Windows Security → จัดการการเชื่อมต่อ → สแกน → จัดการไฟล์ → ตรวจสถานะแล้วส่งผล → แจ้งครู (ครูนั่งที่ TEACHER-PC ในห้องคอม ใช้ `Mission03Controller.seat_teacher` แบบอ่านอย่างเดียว) ไม่มีขั้นรายงานหัวหน้างาน
- `scripts/mission_05_state.gd` — สิ่งที่ผู้เล่นทำและคะแนน 30/50/20 เริ่มใหม่ทุกครั้งที่เข้าด่าน (ไม่เก็บความคืบหน้าข้ามรอบ)
  - ความถูกต้อง 30: Firewall 15 + Quarantine 15 (ถูกครั้งแรกเต็ม ครั้งที่สอง 8 หลังจากนั้น 0)
  - กระบวนการ 50 = 5 จุด × 10: (ก) เปิด Firewall & network protection เป็นส่วนแรก (ข) ไม่เคยปิด Firewall (ค) หลังแก้ Firewall เปิด Virus & threat protection เป็นส่วนแรก (ง) เลือก Quarantine ตั้งแต่ครั้งแรก (ไม่เคย Remove / Allow on device / Add an exclusion / ปิด Real-time protection) (จ) ทุกส่วนเป็นสีเขียวตอนกดส่งผลครั้งแรก
  - เวลา 20: ค่าชั่วคราว เต็มเมื่อเสร็จใน 5 นาที เป็น 0 ที่ 15 นาที
- `scripts/windows_security.gd` — ตัวโปรแกรม หน้าตาและการทำงานแบบ Windows Security ของ Windows 11 เป็นภาษาอังกฤษล้วน (ผู้พัฒนาสั่ง 13 พ.ย. 2569) ไอคอนวาดด้วยโค้ดทั้งหมด ไม่ใช้ภาพของ Microsoft
  - แถบซ้ายมี Home, Virus & threat protection, Account protection, Firewall & network protection, App & browser control, Device security, Device performance & health, Family options, Protection history และ Settings ส่วนที่ไม่เกี่ยวกับภารกิจเป็นตัวหลอก (เขียวทั้งหมด)
  - Home "Security at a glance": การ์ด Firewall และ Virus ขึ้น "Actions recommended" ทั้งคู่ — ส่วนแรกที่เปิดก่อนแก้ Firewall = จุดตัดสินใจ (ก), ส่วนแรกที่เปิดหลังแก้ Firewall = (ค)
  - Firewall: หน้าต่าง "Windows Security Alert" ของ `Unknown_Update.exe` ปุ่ม Allow access (ผิด) / Cancel (ถูก ปิดกั้นไว้) และสวิตช์ Microsoft Defender Firewall ในหน้า Domain/Private/Public network (ปิด = ผิด แล้วเด้งกลับเป็น On)
  - Virus: Quick scan (กดได้หลังตอบหน้าต่าง Firewall แล้ว) → พบ `HackTool:Win32/GameCrack.A` คลิกดูรายละเอียด เลือก Remove / Quarantine / Allow on device แล้วกด Start actions (ถูก = Quarantine) กับดักเพิ่มเติม: Manage settings → Real-time protection Off, Exclusions → Add an exclusion → File
  - คำใบ้ภาษาไทยและปุ่ม "ส่งผลการตรวจสอบ" เป็นแผงของเกม (สีเข้ม) แยกจากหน้าต่าง Windows คำตอบที่ผิดจะไม่ถูกนำไปใช้ ปุ่มส่งผลกดได้ตลอด ถ้ายังไม่เขียวทุกส่วนจะขึ้นคำใบ้และไม่รับผล ความคืบหน้าอยู่ใน `WindowsSecurity.shared_state` ซึ่งตัวควบคุมด่านเป็นผู้ตั้งค่า (ปิดแล้วเปิดโปรแกรมใหม่ได้)
- `data/mission_05_data.tres` + `scripts/mission_05_data.gd`, `scripts/security_choice.gd` — ข้อความ ตัวเลือก คำใบ้ เหตุผล เวลาสแกน (แก้ใน Inspector ได้)
- `scripts/security_theme.gd` — สี ฟอนต์ และไอคอนที่วาดเอง
- `scenes/windows_security.tscn` — scene ของโปรแกรม (กด F6 เปิดดูเดี่ยว ๆ ได้ จะใช้สถานะใหม่ของตัวเอง)
- ไฟล์ร่วมที่เกี่ยวข้อง: `scripts/computer/desktop_os.gd` (ไอคอน การแจ้งเตือนมุมขวาล่างแบบ Windows 11 `_build_security_toast()`, `open_windows_security()`), `scripts/computer/computer_station.gd` (จอสีแดง), `scripts/computer/computer_manager.gd` (ติดตั้งโปรแกรมและจอสีแดงที่เครื่องเป้าหมาย), `scripts/game_flow.gd` (`configure_level` ด่าน 5)

ทดสอบ: `godot --headless --path net-sim-3d -s res://tools/validate_mission_05.gd` • ภาพ: `tools/capture_mission_05.gd` (ต้องมีหน้าต่าง)
