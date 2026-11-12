# ด่าน 03 — ตรวจรับการเชื่อมต่อเครือข่าย

บทภารกิจอยู่ที่ `../../../ภารกิจ/ด่าน_03/README.md`

- `scripts/mission_03_controller.gd` — ลำดับด่าน: รับภารกิจจากหัวหน้างาน → ตรวจ 3 เครื่องในห้องคอม → ยืนยันรายงาน → ส่งรายงาน → สรุปคะแนน และคุมคำสั่งต้องห้าม (`DesktopOS.command_guard`)
- `scripts/mission_03_state.gd` — สิ่งที่ผู้เล่นทำและคะแนน 30/50/20
- `scripts/inspection_checklist.gd` — ใบตรวจด้านขวาขณะนั่งที่เครื่อง (พิมพ์ค่าเอง แนบได้ครั้งเดียว)
- `scripts/inspection_report.gd` — Network Inspection Report ก่อนส่ง

ความผิดปกติของเครื่อง `PC-R5-R2` (`ComputerStation.link_fault`) มีเฉพาะในด่านนี้
ทดสอบ: `godot --headless --path net-sim-3d -s res://tools/validate_mission_03.gd` (ตั้งภาษาเป็นไทย)
