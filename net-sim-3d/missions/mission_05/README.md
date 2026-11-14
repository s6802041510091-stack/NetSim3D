# ด่าน 05 — ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน (Windows Security จำลอง) — v2.1

บทภารกิจอยู่ที่ `../../../ภารกิจ/ด่าน_05/README.md` — ส่วน "v2.1 — ฉบับที่ใช้จริง" (ตกลงกับผู้พัฒนา 15 พ.ย. 2569) ซึ่งแทนที่แบบเดิมของวันที่ 13 พ.ย. และร่าง v2

โปรแกรมจำลองเพื่อการศึกษา ไม่มีการเปิด Windows Security จริง ไม่มีการสแกนเครื่องจริง และไม่มีไฟล์อันตรายจริง ชื่อไฟล์ โปรแกรม และผู้ผลิตเป็นข้อมูลสมมติทั้งหมด

ไม่มีกล่องคำถามบน Desktop (ผู้พัฒนาสั่ง 15 พ.ย. 2569): ความเข้าใจวัดจากสิ่งที่ผู้เล่นกดตรวจใน Windows Security เอง ตัวเลือกที่เหลือมีข้อเดียวคือการเลือกว่าจะรายงานผลให้ครูอย่างไร (ในห้อง ไม่ใช่บน Desktop)

- `scripts/mission_05_controller.gd` — ลำดับด่าน 8 ขั้น (แท็บติดตามมาตรฐาน `ObjectiveHUD.set_steps`): รับสาย (ครูบอกว่าคาบนี้ต้องใช้ SchoolLab Classroom) → ไปที่ PC-R3-L2 (หน้าจอขึ้นกล่องเตือน Threats found) → เปิด Windows Security → จัดการโปรแกรมที่ขอรับการเชื่อมต่อ → สแกน → จัดการไฟล์ → ตรวจสถานะแล้วส่งผล → แจ้งครู: ครูถามว่าเครื่องเป็นอย่างไร ผู้เล่น**เลือกเองว่าจะรายงานอะไร** แล้วครูตอบว่าจะดูแลและเตือนนักเรียนเรื่องการดาวน์โหลดโปรแกรมภายนอก (ครูนั่งที่ TEACHER-PC ในห้องคอม ใช้ `Mission03Controller.seat_teacher` แบบอ่านอย่างเดียว) ไม่มีขั้นรายงานหัวหน้างาน
  - การเลือกรายงานผลใช้ `DialogueBox.ask(..., stacked = true)` คำตอบ 4 ข้อเรียงแถวละข้อ สลับลำดับทุกครั้ง เลือกผิดถามซ้ำพร้อมคำใบ้ (คิดคะแนนเฉพาะครั้งแรก) เลือกถูกแล้วผู้เล่นพูดประโยคนั้น และครูตอบรับ
  - คนในห้องคอม (ผู้พัฒนาสั่ง 15 พ.ย. 2569): `ClassroomStudents.setup()` (`scripts/npc/classroom_students.gd`, เรียกจาก `GameFlow.configure_level`) ย้ายนักเรียนทั้ง 7 คนจากโถงทางเดินมานั่งที่คอมในห้องคอม (ท่านั่งพิมพ์งานแบบเดียวกับครู) โถงทางเดินเหลือแค่แม่บ้าน เจ้าของ PC-R3-L2 (`two_block`) ลุกไปยืนข้างเครื่องตอนเริ่มด่าน หันมามองผู้เล่นเมื่อเข้าใกล้ และเดินกลับไปนั่งเมื่อเข้าขั้นแจ้งผลครู (`watcher_state`) PC-R3-L2 ไม่อยู่ใน `npc_used_hosts` จนกว่าเขาจะนั่ง
  - เดินเข้าห้องคอมหลังรับสาย: ครูทักทันที "อ้าว คุณช่างมาพอดีเลย คอมที่เสียคือคอมเครื่องนี้ครับ" (`GREET`, ครั้งเดียว, `in_computer_room()`)
- `scripts/firewall_alerts.gd` — หน้าต่าง "Windows Security Alert" 2 อัน ขึ้นเมื่อเปิดหน้า Firewall & network protection: SchoolLab Classroom อยู่ด้านหน้า (ถูก = Allow access โดยติ๊ก Private; ติ๊ก Public ด้วยก็ถูก แต่ขึ้นหมายเหตุ) แล้วจึงเป็น Unknown_Update.exe (ถูก = Cancel) ช่อง Private ติ๊กไว้ก่อนตามค่าเริ่มต้นของ Windows ปุ่ม Allow access มีโล่สิทธิ์ผู้ดูแล ปิดหน้าต่างได้ แล้วเปิดใหม่ด้วย Review หรือเปิดหน้า Firewall อีกครั้ง
- `scripts/mission_05_state.gd` — สิ่งที่ผู้เล่นทำและคะแนน 30/50/20 เริ่มใหม่ทุกครั้งที่เข้าด่าน
  - ความถูกต้อง 30: SchoolLab 10 + Unknown_Update 10 + Quarantine 10 (ถูกครั้งแรก 10 ครั้งที่สอง 5 หลังจากนั้น 0)
  - กระบวนการ 50 (ถ่วงน้ำหนัก): เปิด Firewall เป็นส่วนแรก 10 · ตรวจ Allow an app through firewall หลังตอบหน้าต่างครบ 10 · หลังแก้ Firewall เปิด Virus เป็นส่วนแรก 10 · ไม่ลดระดับการป้องกัน (ปิด Firewall / ปิด Real-time protection / Add an exclusion / Allow on device) 10 · เปิด Protection history ก่อนส่ง และทุกส่วนเขียวตอนส่งครั้งแรก 5 · รายงานผลให้ครูถูก 5
  - เวลา 20: ค่าชั่วคราว เต็มเมื่อเสร็จใน 7 นาที เป็น 0 ที่ 17 นาที
- `scripts/windows_security.gd` — ตัวโปรแกรม หน้าตาและการทำงานแบบ Windows Security ของ Windows 11 เป็นภาษาอังกฤษล้วน ไอคอนวาดด้วยโค้ดทั้งหมด ไม่ใช้ภาพของ Microsoft
  - แถบซ้ายครบทุกเมนูแบบของจริง ส่วนที่ไม่เกี่ยวกับภารกิจเป็นตัวหลอก (เขียวทั้งหมด)
  - Firewall: เครือข่ายที่ใช้งานคือ `Private network (active)` (SCHOOL-LAN) แบนเนอร์ + ปุ่ม Review จนกว่าจะตอบหน้าต่างครบ สวิตช์ Microsoft Defender Firewall (ปิด = ผิด แล้วเด้งกลับเป็น On)
  - Allowed apps (ลิงก์ "Allow an app through firewall"): รายการกฎแบบอ่านอย่างเดียว แสดงผลของหน้าต่างแจ้งเตือน (SchoolLab อนุญาต, Unknown_Update.exe ไม่อนุญาต)
  - Virus: Quick scan กดได้หลังตอบหน้าต่างครบ → `HackTool:Win32/GameCrack.A` มี Affected items 2 ไฟล์ (Student_Game_Crack.exe และ Unknown_Update.exe ที่แคร็กสร้างขึ้น) เลือก Remove / Quarantine / Allow on device แล้วกด Start actions กับดักเพิ่มเติม: Real-time protection Off, Add an exclusion → File
  - Protection history: รายการ Threat quarantined (Affected items: 2) ใช้ยืนยันผลก่อนส่ง
  - คำใบ้ภาษาไทยและปุ่ม "ส่งผลการตรวจสอบ" เป็นแผงของเกม แยกจากหน้าต่าง Windows
- `data/mission_05_data.tres` + `scripts/mission_05_data.gd`, `scripts/security_choice.gd`, `scripts/security_question.gd` — ข้อความ ตัวเลือก คำใบ้ ตัวเลือกการรายงานผล ชื่อโปรแกรม (แก้ใน Inspector ได้)
- `scripts/security_theme.gd` — สี ฟอนต์ และไอคอนที่วาดเอง
- `scenes/windows_security.tscn` — scene ของโปรแกรม (กด F6 เปิดดูเดี่ยว ๆ ได้ จะใช้สถานะใหม่ของตัวเอง)
- ไฟล์ร่วมที่เกี่ยวข้อง: `scripts/computer/desktop_os.gd` (การแจ้งเตือนมุมขวาล่าง, `open_windows_security()`), `scripts/ui/dialogue_box.gd` (`ask(..., stacked)`), `scripts/computer/computer_station.gd` + `scripts/computer/security_warning_screen.gd` (ภาพกล่องเตือน Windows Security บนจอในห้อง แทนจอสีแดงเดิม — ผู้พัฒนาสั่ง 15 พ.ย. 2569; โมเดลจอไม่มี UV จึงใช้ shader คำนวณตำแหน่งภาพจากกรอบของจอ และกะพริบเบา ๆ), `scripts/computer/computer_manager.gd`, `scripts/game_flow.gd` (`configure_level` ด่าน 5)

ทดสอบ: `godot --headless --path net-sim-3d -s res://tools/validate_mission_05.gd` • ภาพ: `tools/capture_mission_05.gd` (ต้องมีหน้าต่าง)
