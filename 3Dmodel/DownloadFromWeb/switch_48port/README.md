# Switch 48 Ports — คู่มือนำไปใช้ใน Godot 4.7

ใช้ในด่าน 1 (เลือกอุปกรณ์) และด่าน 4 (พอร์ต Switch เสีย 2 ช่อง → ย้ายสายไปช่องว่าง)

## ไฟล์
| ไฟล์ | ใช้ทำอะไร |
|---|---|
| `switch_48port.tscn` | **ใช้ไฟล์นี้วางในฉาก** (โมเดล + สคริปต์) |
| `switch_48port.gd` | สคริปต์ (`class_name Switch48`) |
| `switch_48port.glb` | โมเดล |
| `source/` | ไฟล์ Blender + สคริปต์สร้างโมเดล (มี `.gdignore`) |

## ขนาด
1U ติดตู้ Rack 19 นิ้ว: กว้าง 48.4 ซม. (รวมหูยึด) × สูง 4.4 ซม. × ลึก 23.7 ซม. · หน้าเครื่องหันไปทาง **+Z**

## โครงสร้าง node
```
Switch48
└ Switch48
  ├ Switch_Body          ตัวเครื่อง (รูพอร์ต, ตัวเลขพอร์ต, ป้าย รวมไว้แล้ว)
  ├ Ports/Port_01 … Port_48   จุดเสียบสาย (Node3D)
  ├ PortLEDs/LED_Port_01 … LED_Port_48   ไฟประจำพอร์ต
  ├ LED_Power, LED_System
  ├ Port_Console         พอร์ต Console
  └ Power_Inlet          ช่องเสียบไฟด้านหลัง
```
- **การเรียงพอร์ตเหมือนสวิตช์จริง**: แถวบน = เลขคี่ (1, 3 … 47) แถวล่าง = เลขคู่ (2, 4 … 48) แบ่งเป็น 4 กลุ่ม กลุ่มละ 12
- จุดเสียบ `Port_XX`: แกน **-Z = ทิศเสียบเข้า**, แกน **+Y = ด้านหน้าสัมผัสของหัว RJ-45** (ขาล็อกอยู่ฝั่ง -Y) — แถวบนกลับหัวให้แล้วเหมือนของจริง ถ้า snap หัวสายตามแกนนี้ หัวจะหันถูกทุกช่อง

## การใช้สคริปต์
```gdscript
@onready var sw: Switch48 = $Switch48

sw.broken_ports = [7, 18]          # ด่าน 4: กำหนดช่องเสีย (สุ่มจากชุดสถานการณ์ได้)
sw.connect_cable(7)                # → false, ไฟไม่ติด (ช่องเสีย)
sw.connect_cable(30)               # → true, ไฟเขียวกะพริบ (มี traffic)
sw.disconnect_cable(30)
sw.set_port_state(5, Switch48.LinkState.LINK)   # OFF / LINK (ติดค้าง) / ACTIVITY (กะพริบ) / FAULT (สีส้ม)
sw.port_at(hit_position)           # หาเลขพอร์ตที่ใกล้จุดที่ผู้เล่นคลิก (0 = ไม่โดนพอร์ตไหน)
sw.get_port_point(12)              # Node3D สำหรับ snap หัวสาย
sw.set_power(false)
```
| signal | เกิดเมื่อ |
|---|---|
| `port_state_changed(port, state)` | สถานะพอร์ตเปลี่ยน (ใช้บันทึกว่าผู้เล่นเสียบช่องไหน/กี่ครั้ง) |
| `power_changed(is_on)` | เปิด/ปิดเครื่อง |

Inspector: `broken_ports`, `start_powered`, `blink_interval`

## ยังต้องทำฝั่งเกม
- collision สำหรับคลิกพอร์ต: ใส่ `StaticBody3D` + BoxShape ครอบหน้าเครื่องอันเดียว แล้วใช้ `port_at()` แปลงจุดที่คลิกเป็นเลขพอร์ต (ไม่ต้องทำ 48 collision)
- ด่าน 4: ผลว่าคอมเครื่องไหนออกเน็ตได้ ให้ระบบจำลองเครือข่ายของเกมตัดสินจาก `is_port_broken()`

## ทดสอบแล้ว
Godot 4.7.1: node ครบ 48 พอร์ต + 48 ไฟ, ทิศจุดเสียบแถวบน/ล่าง, ช่องเสียไฟไม่ติด, LINK/ACTIVITY, `port_at`, ปิดเครื่องไฟดับ — ผ่าน
