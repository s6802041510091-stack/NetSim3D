# ภารกิจที่ 6 — TeamViewer (จำลอง) ช่วยเหลือผู้ใช้ด้วยซอฟต์แวร์ควบคุมเครื่องระยะไกล

โปรแกรม TeamViewer ในเกมเป็น **ซอฟต์แวร์จำลองเพื่อการศึกษา** ไม่เรียกใช้ TeamViewer จริง ไม่เชื่อมต่อคอมพิวเตอร์จริง และไม่ส่งข้อมูลออกจากเกม
TeamViewer ID `482 731 965` และ Password `N7q4P2` เป็นข้อมูลสมมติ

เอกสารออกแบบภารกิจ: `D:\Project-1\ภารกิจที่6\ภารกิจที่6_ช่วยเหลือผู้ใช้ด้วยซอฟต์แวร์ควบคุมเครื่องระยะไกล.docx`

## ขั้นตอนในเกม

1. **ห้อง Data Center = ห้อง IT Support** โทรศัพท์วางอยู่บนโต๊ะผู้เล่น ข้างคอมพิวเตอร์ **IT-PC-01** (ฉาก `desk_phone.tscn`)
2. โทรศัพท์ดัง (ไฟแดงกระพริบ) มองที่โทรศัพท์แล้วกด **E** เพื่อรับสาย
3. ครูสาวพูดตามบทในเอกสาร และบอก TeamViewer ID กับ Password กด E / Space หรือคลิกเพื่อไปต่อ จบสายแล้วขึ้น "ได้รับภารกิจ: ..."
4. กด E ที่ IT-PC-01 เพื่อเข้า Desktop แล้วเปิดไอคอน **TeamViewer**
5. หน้าหลักมีรายการตรวจสอบก่อนเชื่อมต่อ 5 ข้อ พิมพ์ **Partner ID** แล้วกด **Connect** (มีหรือไม่มีช่องว่างก็ได้)
6. หน้าต่าง **Authentication** พิมพ์ **Password** (แยกตัวพิมพ์เล็ก-ใหญ่) แล้วกด **Log On** จะขึ้น "Connection established" แล้วเปิด Desktop ของครูสาว
7. แถบด้านบนแสดง `Remote Session | Connected to: TEACHER-PC | Session status: Active | [End Session]`
8. คลิกไอคอนลำโพงบน Taskbar ของเครื่องครูสาว กดปุ่มลำโพงเพื่อยกเลิก Mute ปรับเสียงเป็น 50–70% แล้วกด **ทดสอบเสียง** ครูสาวจะยืนยัน
9. กด **End Session** → **Disconnect** สถานะเปลี่ยนเป็น `Session ended`
10. ปิดโปรแกรม TeamViewer แล้วปิดคอมพิวเตอร์ (เริ่ม → ปิดเครื่อง หรือ Esc) ระบบจะแสดง **หน้าสรุปความรู้** (TeamViewer / AnyDesk / ซอฟต์แวร์ควบคุมระยะไกล) และ "ภารกิจสำเร็จ"

- ถ้ากด Connect ก่อนรับสาย จะขึ้นว่าเครื่องปลายทางยังไม่พร้อม และไม่หักคะแนน
- ถ้าพยายามปิดโปรแกรมหรือปิดคอมพิวเตอร์ระหว่าง Remote Session จะไม่ยอมให้ปิด และหักคะแนน
- ถ้าปิดคอมพิวเตอร์ตอนที่ TeamViewer ยังเปิดอยู่ (แม้จบ Session แล้ว) ระบบจะเตือนให้ปิดโปรแกรมก่อน โดยไม่หักคะแนน

## กติกาคะแนน

| กรณี | หัก |
|---|---|
| กรอก TeamViewer ID ผิด | 5 ต่อครั้ง |
| กรอก Password ผิด | 5 ต่อครั้ง |
| ปิดโปรแกรมหรือปิดเครื่องระหว่าง Remote Session (ไม่กด End Session) | 10 ต่อครั้ง |
| ปรับเสียงผิดช่วง หรือยังไม่ได้ยกเลิก Mute | ไม่หัก (ให้คำแนะนำทุกครั้ง) |
| ช่องว่าง หรือกด Connect ก่อนรับสาย | ไม่หัก |

คะแนนเริ่มที่ 100 และไม่ต่ำกว่า 0

## ไฟล์

| ไฟล์ | หน้าที่ |
|---|---|
| `scenes/missions/mission_06/teamviewer.tscn` | **Scene หลัก** (โปรแกรม TeamViewer จำลอง) |
| `scenes/missions/mission_06/desk_phone.tscn` | โทรศัพท์บนโต๊ะผู้เล่นในห้อง IT Support (Data Center) |
| `scenes/missions/mission_06/mission_06_test.tscn` | ฉากทดสอบ (กด F6) ไม่ต้องโหลดแผนที่ 3D |
| `data/missions/mission_06/mission_06_data.tres` | ID, Password, ข้อความทั้งหมด, บทโทรศัพท์, ช่วงเสียง, คะแนน, หน้าสรุป (แก้ใน Inspector) |
| `scripts/missions/mission_06/teamviewer_sim.gd` | ตัวโปรแกรม: หน้าหลัก, Authentication, Remote Session, ลำโพง, End Session |
| `scripts/missions/mission_06/mission_06_controller.gd` | โทรศัพท์ → บทสนทนา → "ได้รับภารกิจ" และปิดเครื่อง → หน้าสรุป → "ภารกิจสำเร็จ" |
| `scripts/missions/mission_06/desk_phone.gd` | โทรศัพท์บนโต๊ะ (ดัง/รับสาย) |
| `scripts/missions/mission_06/call_dialog.gd` | กล่องบทสนทนาทางโทรศัพท์ |
| `scripts/missions/mission_06/mission_06_state.gd` | สถานะผู้เล่น |
| `scripts/missions/mission_06/mission_06_save_store.gd` | บันทึก/โหลด JSON ใน `user://netsim3d/mission_06_save.json` |
| `scripts/missions/mission_06/remote_theme.gd` | สี ฟอนต์ Sarabun และไอคอนที่วาดเอง |
| `scripts/missions/mission_06/mission_06_test_bench.gd` | ฉากทดสอบ |
| `tools/validate_mission_06.gd` | ทดสอบอัตโนมัติทั้งภารกิจในแผนที่จริง |

ไฟล์เดิมที่แก้:
- `scenes/main.tscn`: เพิ่ม `DeskPhone` (บนโต๊ะ IT_PlayerDesk) และ `Mission06`
- `scripts/computer/computer_manager.gd`: `teamviewer_hosts = ["IT-PC-01"]`
- `scripts/computer/desktop_os.gd`: ไอคอน `open_teamviewer()` และ `request_shutdown()`
- `scripts/player_controller.gd`: กด E กับวัตถุทั่วไปที่มี meta `interactable` เช่น โทรศัพท์
- `tools/validate_computers.gd`: จำนวนคอมเป็น 29 เครื่อง (รวมคอมห้องพักครู 5 เครื่อง)

## สัญญาณ (Signals)

- `Mission06Controller.call_answered`, `mission_completed(score, wrong_id, wrong_password, close_without_end)`
- `TeamViewerSim.connect_attempted(accepted)`, `login_attempted(accepted)`, `session_started`, `sound_tested(result)`, `teacher_confirmed`, `session_ended`, `mistake_made(reason, penalty)`
- `DesktopOS.app_opened("teamviewer", app)`

## ตั้งค่า

- ไม่ให้โทรศัพท์ดังตอนเริ่มเกม: node `Mission06` → `Ring On Start` = ปิด แล้วให้ระบบภารกิจหลักเรียก `start_ringing()`
- ย้ายโทรศัพท์: node `DeskPhone` ใน `main.tscn`
- เปลี่ยนเครื่องที่มี TeamViewer: node `Computers` → `Teamviewer Hosts` และ node `Mission06` → `Player Computer`
- เปลี่ยน ID, Password, ข้อความ, ช่วงเสียง, คะแนน: `data/missions/mission_06/mission_06_data.tres`

## ยังไม่ได้ทำ

- ประวัติบทสนทนา (เปิดดู ID และ Password ซ้ำ) ตอนนี้ทำแค่รับสายตามที่ตกลงไว้
- ตัวละครครูสาวและหัวหน้างานใน 3D

## ทดสอบ

- `scenes/missions/mission_06/mission_06_test.tscn` แล้วกด F6
- หรือเล่นเกมหลัก (F5) ผู้เล่นเริ่มในห้อง IT Support ข้างโต๊ะของตัวเอง โทรศัพท์ดังอยู่บนโต๊ะ
- อัตโนมัติ: `godot --headless --path net-sim-3d -s res://tools/validate_mission_06.gd`
