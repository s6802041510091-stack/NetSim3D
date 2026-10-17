# หน้าจอ Software จำลอง (ด่าน 5–6) — คู่มือนำไปใช้ใน Godot 4.7

ทุกหน้าจอสร้างด้วยโค้ด GDScript (ไม่มีรูปภาพ/ฟอนต์ภายนอก) และ **ใช้ข้อมูลเครือข่ายชุดเดียวกัน** ผ่าน `NetSim`
ผลของ `ping`, Advanced IP Scanner, Veyon จึงตรงกันเสมอ — ถ้าเครื่องไหนออฟไลน์ ทุกโปรแกรมก็เห็นตรงกัน

## ติดตั้ง (ทำครั้งเดียว)
1. คัดลอกโฟลเดอร์ `ui/` ไปไว้ที่ `res://ui/`
2. **Project → Project Settings → Globals → Autoload** เพิ่ม `res://ui/core/net_sim.gd` ชื่อ **`NetSim`** (ต้องชื่อนี้)
3. ลองเปิด `res://ui/demo/ui_demo.tscn` แล้วกด F6 — จะเห็นหน้า Desktop ดับเบิลคลิกเปิดโปรแกรมได้เลย

## โครงสร้าง
```
ui/
  core/net_sim.gd          ข้อมูลเครือข่ายจำลอง + บันทึกการกระทำ (Autoload "NetSim")
  core/ui_kit.gd           ธีม/สี/ปุ่ม ที่ทุกหน้าจอใช้ร่วมกัน
  core/app_window.gd       กรอบหน้าต่างแบบ Windows (ลาก, ขยาย, ปิด)
  desktop/sim_desktop.gd   หน้า Desktop + Taskbar + ไอคอนโปรแกรม (class SimDesktop)
  desktop/computer_screen.gd  เอา Desktop ไปแสดงบนจอคอม 3D / เปิดเต็มจอ (class ComputerScreen)
  apps/command_prompt.gd   Command Prompt
  apps/ip_scanner.gd       Advanced IP Scanner
  apps/veyon_configurator.gd  Veyon Configurator
  apps/veyon_master.gd     Veyon Master (+ Remote control เข้าไปที่ Desktop ของเครื่องนักเรียน)
  apps/windows_security.gd Windows Security → Firewall → Allow an app
  apps/notepad.gd, placeholder_app.gd   โปรแกรมอื่น (ตัวหลอก / โปรแกรมบนเครื่องนักเรียน)
  demo/ui_demo.tscn        ฉากทดลอง
  screenshots/             ภาพหน้าจอทุกโปรแกรม
```

## ข้อมูลเครือข่ายจำลอง (`NetSim`)
| อุปกรณ์ | ชื่อ | IP |
|---|---|---|
| Router | ROUTER-LAB | 192.168.10.1 (Gateway) |
| Printer | PRINTER-LAB | 192.168.10.50 |
| คอมครู | TEACHER-PC | 192.168.10.100 |
| คอมนักเรียน 30 เครื่อง | PC-01 … PC-30 | 192.168.10.101 … .130 |
| มือถือ (ตัวหลอก) | Android-Phone | 192.168.10.182 |

Subnet 255.255.255.0 · DNS 8.8.8.8 · MAC สุ่มจาก seed (seed เดิม = MAC เดิม)

```gdscript
NetSim.reset(2569, [7, 22])      # เริ่มด่านใหม่: PC-07 กับ PC-22 ปิดเครื่อง (สุ่มสถานการณ์ได้)
NetSim.require_auth_keys = true  # ด่าน 6: ต้องตั้ง Key file auth ก่อน Veyon Master จึงจะต่อได้
NetSim.require_firewall_rule = false   # เปิดเป็น true ถ้าอยากให้ต้องเปิด Firewall ด้วย
NetSim.help_request = {"pc": "PC-15", "app": "notepad", "message": "Please open Notepad for me"}
NetSim.inventory                  # ผลด่าน 5 (รายการที่ผู้เล่นบันทึก) → ด่าน 6 ดึงไปใช้
```
> ถ้าต้องการเชื่อมกับระบบจำลองเครือข่ายของเกม (เช่นสายหลุด/พอร์ต Switch เสีย) ให้แก้ค่า `device.online` ใน `NetSim.devices` แล้ว `NetSim.state_changed.emit()`

## การคิดคะแนน — signal `NetSim.action_logged(action, data)`
ทุกการกระทำสำคัญถูกบันทึกใน `NetSim.action_log` (มีเวลา `t` เป็นวินาที) และส่ง signal:
```gdscript
NetSim.action_logged.connect(func(action, data): print(action, data))
```
| action | data | ใช้ประเมินอะไร |
|---|---|---|
| `app_opened` | app, machine | เลือกโปรแกรมถูกไหม (ด่าน 5 ข้อ 1, ด่าน 6 ข้อ 1) |
| `cmd` / `ping_result` | command / target, ok | ใช้คำสั่งตรวจสอบ |
| `scan_invalid_range` / `scan_started` | text, covers_subnet | กรอกช่วง IP ถูกไหม (ด่าน 5 ข้อ 2) |
| `scan_finished` | found, scanned | สแกนแล้ว (ข้อ 3) |
| `device_classified` | ip, as, correct | จำแนกอุปกรณ์ (ข้อ 4) |
| `inventory_saved` | saved, correct, wrong, missing, expected | บันทึกครบ/ถูก 30 เครื่องไหม (ข้อ 5) |
| `veyon_service_checked` | running, total | ตรวจ Veyon Service (ด่าน 6 ข้อ 2) |
| `veyon_location_created` | name, correct | สร้าง "Computer Lab 1" (ข้อ 3) |
| `veyon_computers_added` | added, mismatched, source | เพิ่มเครื่องจาก Inventory + จับคู่ชื่อ-IP ถูก (ข้อ 4) |
| `veyon_auth_method` / `veyon_key_created` / `veyon_key_distributed` | … | ตั้งค่าความปลอดภัย (ข้อ 5) |
| `firewall_rule_changed` / `veyon_firewall_exception` | rule, allowed | ตั้ง Firewall |
| `veyon_master_location` | location, correct | เลือกห้องถูก (ข้อ 5) |
| `remote_control_failed` | reason | ต่อไม่ได้เพราะยังตั้งค่าไม่ครบ |
| `remote_control_started` | pc, correct | เลือกเครื่อง PC-15 ถูกไหม (ข้อ 6) |
| `remote_task_done` | pc, app | ทำตามคำขอสำเร็จ |
| `remote_control_ended` | task_done | สิ้นสุดการควบคุม |

## นำไปแสดงในเกม (`ComputerScreen`)
ใส่ node `ComputerScreen` ไว้ที่โต๊ะคอมครู แล้วกำหนด `screen_mesh` = MeshInstance3D ที่เป็นกระจกจอ (QuadMesh)
```gdscript
@onready var screen: ComputerScreen = $TeacherPC/ComputerScreen

# แบบ A (แนะนำ): กด E ที่คอม → เปิดเต็มจอ, กด Esc → กลับเกม 3D
screen.open_fullscreen()
# แบบ B: คลิกบนจอ 3D โดยตรง (ส่งตำแหน่งที่ raycast โดนมาให้)
screen.push_click(hit_position, mouse_event)
# สั่งจากโค้ด
screen.desktop.open_app("ipscanner")
```
- `apps` กำหนดว่าเครื่องนี้มีโปรแกรมอะไร (มีตัวหลอก Notepad/Paint/Web Browser ให้ผู้เล่นต้องเลือกเอง)
- เครื่องนักเรียน: `apps = SimDesktop.STUDENT_APPS`, `user_name = "Student"`, `machine_name = "PC-15"`

## Command Prompt รองรับ
`ipconfig`, `ipconfig /all`, `ping <IP หรือชื่อเครื่อง> [-n จำนวน]`, `hostname`, `cls`, `help`, `exit`
คำสั่งอื่นขึ้น "is not recognized..." เหมือน Windows จริง · ลูกศรขึ้น/ลง เรียกคำสั่งเก่า

## หมายเหตุ
- หน้าตาเลียนแบบเลย์เอาต์/ชื่อเมนูของโปรแกรมจริงเพื่อให้นักเรียนนำทักษะไปใช้ได้ แต่ไอคอนวาดใหม่ทั้งหมด ไม่ใช้โลโก้จริง
- ข้อความในโปรแกรมเป็นภาษาอังกฤษเหมือนของจริง
- คอลัมน์ "Type (classify)" ใน IP Scanner และปุ่ม "Save to Network Inventory" / "Import from Network Inventory" / "Distribute public key" เป็นส่วนที่เพิ่มเพื่อเกม (ของจริงทำผ่านไฟล์/ขั้นตอนอื่น)

## ทดสอบแล้ว
Godot 4.7.1: เล่นด่าน 5–6 ครบด้วยโค้ด (สแกน → จำแนก → บันทึก 30 เครื่อง → สร้าง Computer Lab 1 → นำเข้า → ต่อไม่ได้เพราะยังไม่ตั้ง key → ตั้ง key → Remote control PC-15 → เปิด Notepad → จบ) และถ่ายภาพหน้าจอทุกโปรแกรม (โฟลเดอร์ `screenshots/`) รวมถึงภาพบนจอ 3D
