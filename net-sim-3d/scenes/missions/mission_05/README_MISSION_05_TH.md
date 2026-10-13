# ภารกิจที่ 5 — Windows Security (จำลอง) ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน

โปรแกรมจำลองบนคอมพิวเตอร์ในเกม ภารกิจนี้มีโปรแกรมเดียวคือ **Windows Security (จำลองเพื่อการศึกษา)**
ไม่มีการเปิด Windows Security จริง ไม่มีการสแกนเครื่องจริง และไม่มีไฟล์อันตรายจริง ชื่อไฟล์และโปรแกรมทั้งหมดเป็นข้อมูลสมมติ
ในตัวโปรแกรมมีข้อความ "จำลองเพื่อการศึกษา" และหมายเหตุว่าไม่เกี่ยวข้องกับ Microsoft

เอกสารออกแบบภารกิจ: `D:\Project-1\ภารกิจที่5\ภารกิจที่5_ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน.docx`

## ขั้นตอนในเกม (ส่วนที่ไฟล์ชุดนี้ทำ)

1. เครื่องเป้าหมายคือ **PC-R3-L2** (ห้องคอมพิวเตอร์ แถว 3 ฝั่งซ้าย ที่นั่ง 2) จอจะเรืองแสงสีแดงจนกว่าจะแก้ไขเสร็จ ผู้เล่นจึงหาเครื่องเจอได้ง่าย
2. กด E ที่เครื่องนั้น: กล้องซูมเข้าจอ ล็อกการเดิน แสดงหน้า Set-up 2 วินาที แล้วเข้า Desktop (ระบบ DesktopOS เดิม)
3. Desktop มีไอคอน **Windows Security** และมีหน้าต่างแจ้งเตือนมุมขวาล่าง "พบปัญหาด้านความปลอดภัย — ต้องดำเนินการ"
4. หน้าแรกของโปรแกรมแสดงสถานะสีแดง **ต้องดำเนินการ**
5. **Firewall & network protection**: มีโปรแกรม `Unknown_Update.exe` ขอเชื่อมต่อ ต้องเลือก **ปิดกั้นการเชื่อมต่อ**
6. **Virus & threat protection**: กด Scan (ประมาณ 4 วินาที) พบไฟล์ `Student_Game_Crack.exe` ต้องเลือก **Quarantine**
7. ทำครบทั้งสองส่วน หน้าแรกจะเปลี่ยนเป็นสีเขียว **Security status: Protected** และปุ่ม **ส่งผลการตรวจสอบ** จะกดได้
8. กดส่งผล ระบบออกจากคอมพิวเตอร์ให้อัตโนมัติ และผู้เล่นกลับมาเดินได้ตามปกติ

เลือกผิด: ขึ้นคำใบ้ (ไม่เฉลย) หัก 10 คะแนน แล้วเลือกใหม่ได้ ภารกิจไม่ล้มเหลว
Esc: ปิดโปรแกรม แล้วกด Esc อีกครั้งเพื่อออกจากคอมพิวเตอร์

**ยังไม่ได้ทำ (ส่วนของระบบภารกิจ):** บทสนทนากับหัวหน้างาน Data Center ข้อความ "ได้รับภารกิจ" / "ภารกิจสำเร็จ" และเครื่องหมายจุดหมาย ให้ระบบภารกิจหลักฟังสัญญาณด้านล่างแล้วทำต่อ

## ไฟล์

| ไฟล์ | หน้าที่ |
|---|---|
| `scenes/missions/mission_05/windows_security.tscn` | **Scene หลัก** (ตัวโปรแกรม Windows Security จำลอง) |
| `scenes/missions/mission_05/mission_05_test.tscn` | ฉากทดสอบ (กด F6) ใช้ DesktopOS จริง ไม่ต้องโหลดแผนที่ 3D |
| `data/missions/mission_05/mission_05_data.tres` | ข้อความ ตัวเลือก คำใบ้ เหตุผล คะแนน และเวลาสแกน (แก้ใน Inspector ได้) |
| `scripts/missions/mission_05/windows_security.gd` | ตัวโปรแกรม: หน้าแรก Firewall Virus และหน้าสรุป |
| `scripts/missions/mission_05/security_choice.gd` | Resource ของปุ่มตัวเลือก 1 ปุ่ม (ข้อความ ถูก/ผิด คำใบ้) |
| `scripts/missions/mission_05/mission_05_data.gd` | Resource ข้อมูลภารกิจทั้งหมด |
| `scripts/missions/mission_05/mission_05_state.gd` | สถานะผู้เล่น (ทำส่วนไหนแล้ว คะแนน ตัวเลือกที่ผิด ส่งผลแล้วหรือยัง) |
| `scripts/missions/mission_05/mission_05_save_store.gd` | บันทึก/โหลด JSON ใน `user://netsim3d/mission_05_save.json` |
| `scripts/missions/mission_05/security_theme.gd` | สี ฟอนต์ Sarabun และไอคอนที่วาดเอง (โล่ เครื่องหมายถูก) |
| `scripts/missions/mission_05/mission_05_test_bench.gd` | ฉากทดสอบ: `open_computer()`, `open_mission()`, `exit_computer()` |
| `tools/validate_mission_05.gd` | ทดสอบอัตโนมัติทั้งภารกิจในแผนที่จริง |

ไฟล์เดิมที่แก้: `scripts/computer/desktop_os.gd` (ไอคอน หน้าต่างแจ้งเตือน `open_windows_security()`),
`scripts/computer/computer_station.gd` (จอสีแดง `set_screen_alert()`), `scripts/computer/computer_manager.gd` (เลือกเครื่องเป้าหมาย)

## สัญญาณ (Signals) สำหรับระบบภารกิจหลัก

- `DesktopOS.app_opened("windows_security", app)` — ผู้เล่นเปิดโปรแกรมแล้ว
- `WindowsSecurity.firewall_choice_made(choice_id, correct)`, `scan_started`, `scan_finished(threats_found)`, `threat_choice_made(choice_id, correct)`
- `WindowsSecurity.mistake_made(hint, penalty)`
- `WindowsSecurity.protected_reached` — สถานะเป็น Protected
- `WindowsSecurity.report_submitted(score, wrong_count)` — กดส่งผลการตรวจสอบแล้ว (ต่อไป: ไปรายงานหัวหน้างาน)
- `WindowsSecurity.computer_exit_requested`, `close_requested`, `minimize_requested`

เมื่อผู้เล่นรายงานหัวหน้างานแล้ว ให้ระบบภารกิจตั้ง `Mission05State.reported_to_supervisor = true` แล้วบันทึก

## กติกาคะแนน

- เริ่ม 100 คะแนน เลือกผิดครั้งละ 10 คะแนน (ทั้ง Firewall และ Anti-Virus) ไม่ต่ำกว่า 0
- เลือกผิดไม่ทำให้ภารกิจล้มเหลว ได้คำใบ้แล้วเลือกใหม่ได้ คำใบ้ไม่บอกคำตอบ
- ส่งผลได้เมื่อทำถูกทั้งสองส่วนเท่านั้น คะแนนไม่ขึ้นกับความเร็ว

## ข้อมูลที่บันทึก

`app_opened`, `firewall_blocked`, `scan_completed`, `threat_quarantined`, `score`, `wrong_choices`, `protected`, `report_submitted`, `reported_to_supervisor`, `reward_claimed`
ถ้ามีระบบ Save กลางในอนาคต ให้เรียก `Mission05State.to_dict()` / `from_dict()` แทน `Mission05SaveStore`

## ทดสอบ

- เปิด `scenes/missions/mission_05/mission_05_test.tscn` แล้วกด F6 (ปุ่ม "ล้างข้อมูลบันทึก" ใช้เริ่มใหม่)
- หรือรันเกมหลัก (F5) แล้วเดินไปที่เครื่อง PC-R3-L2 ในห้องคอมพิวเตอร์ (จอสีแดง)
- ทดสอบอัตโนมัติ: `godot --headless --path net-sim-3d -s res://tools/validate_mission_05.gd`

## ตั้งค่า

- เปลี่ยนเครื่องเป้าหมาย: `main.tscn` → node `Computers` → Inspector → `Windows Security Hosts` (ค่าเริ่มต้น `["PC-R3-L2"]`)
- แก้ข้อความ ตัวเลือก คำใบ้ คะแนน เวลาสแกน: เปิด `data/missions/mission_05/mission_05_data.tres` ใน Inspector
