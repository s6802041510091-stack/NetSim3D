# Cable Tester — คู่มือนำไปใช้ใน Godot 4.7

ใช้ในด่าน 3 (ทดสอบสาย 3 เส้น เส้นที่ 3 ไฟกะพริบ) และด่าน 4 (ทดสอบสายที่ Switch)

## ไฟล์
| ไฟล์ | ใช้ทำอะไร |
|---|---|
| `cable_tester.glb` | โมเดล (นำเข้า Godot ได้เลย) |
| `cable_tester.tscn` | ซีนพร้อมสคริปต์ — **ให้ใช้ไฟล์นี้วางในฉาก** |
| `cable_tester.gd` | สคริปต์ควบคุมไฟ/ปุ่ม (`class_name CableTester`) |
| `source/` | ไฟล์ Blender + สคริปต์สร้างโมเดล (มี `.gdignore` แล้ว Godot จะไม่ import) |

วางทั้งโฟลเดอร์ไว้ที่ `res://models/cable_tester/` (ถ้าย้ายที่ ให้แก้ path ใน `.tscn`)
> ⚠️ อย่าวางไฟล์ `.blend` ในโปรเจกต์ Godot นอกโฟลเดอร์ที่มี `.gdignore` — Godot จะพยายามเรียก Blender มา import

## ขนาดและแกน
- หน่วยเมตร ขนาดจริง: กว้าง 6.8 × สูง 2.9 × ยาว 11.5 ซม. (ตัวแม่ + ตัวลูกต่อกัน)
- จุด origin อยู่ที่พื้นใต้ตัวแม่ ด้านบนของเครื่องคือแกน +Y

## โครงสร้าง node
```
CableTester            (สคริปต์ CableTester)
└ CableTester
  ├ Main               ตัวแม่
  │ ├ Main_Body        ตัวเครื่อง (รวมป้าย/ตัวอักษรไว้แล้ว)
  │ ├ Button_Power     ปุ่มเปิดเครื่อง (สีแดง)
  │ ├ Button_Test      ปุ่ม TEST (สีเหลือง)
  │ ├ LED_Power        ไฟ ON สีแดง
  │ ├ LED_Main_1 … LED_Main_8, LED_Main_G
  │ └ Main_PlugPoint   จุดเสียบหัว RJ-45
  └ Remote             ตัวลูก (แยกออกไปวางที่ปลายสายอีกด้านได้)
    ├ Remote_Body
    ├ LED_Remote_1 … LED_Remote_8, LED_Remote_G
    └ Remote_PlugPoint
```

**จุดเสียบ (`*_PlugPoint`)**: ให้วางหัว RJ-45 ที่ตำแหน่งนี้ โดยแกน **-Z ของ node ชี้เข้าไปในรู** (ทิศที่หัวสายเคลื่อนตอนเสียบ)
แนะนำให้ปลายหัว RJ-45 ในโมเดลสายมี node ชื่อ `Plug_Tip` ที่แกน -Z ชี้ออกจากปลายหัว จะได้ snap ตรงกันพอดี

**การชนกับเมาส์/การคลิก**: ยังไม่มี collision ให้เพิ่ม `Area3D` + `CollisionShape3D` (BoxShape) ใต้ `Button_Power`, `Button_Test` และตัวเครื่องเอง ตามระบบ interact ของเกม

## การใช้สคริปต์
```gdscript
@onready var tester: CableTester = $CableTester

tester.press_power()                          # เปิด/ปิด (ไฟ ON ติด)
tester.press_test(CableTester.STRAIGHT)       # สายดี: ไฟ 1→8→G วิ่งตรงกันทั้งสองฝั่ง
tester.press_test(CableTester.STRAIGHT, true) # สายหลวม/เข้าหัวไม่แน่น: ไฟตัวลูกกะพริบ
tester.press_test([1,2,3,4,5,6,7,0,9])        # สาย 8 ขาด: ไฟตัวลูกช่อง 8 ไม่ติด
tester.press_test([2,1,3,4,5,6,7,8,9])        # เรียงสายผิด (1-2 สลับกัน)
tester.stop_test()
```
- `mapping` คือ array 9 ช่อง: ช่องที่ i = เลขไฟตัวลูกที่ติดพร้อมไฟตัวแม่ดวงที่ i+1 (1–9, 9 = G, **0 = สายขาด**)
- ถ้ายังไม่เปิดเครื่อง กด Test จะไม่มีอะไรเกิดขึ้น (เหมือนเครื่องจริง) — ใช้วัด "ลำดับขั้นตอน" ได้
- **เกมเป็นคนตัดสินว่าสายเป็นแบบไหน** (จากผลด่านเข้าหัวสาย) แล้วส่ง mapping มา สคริปต์แค่แสดงผล

### Signals (ไว้บันทึกการกระทำเพื่อคิดคะแนน)
| signal | เกิดเมื่อ |
|---|---|
| `power_changed(is_on)` | กดเปิด/ปิด |
| `test_started(mapping, loose)` | เริ่มทดสอบ (เฉพาะตอนเครื่องเปิด) |
| `test_stopped` | หยุดทดสอบ / ปิดเครื่อง |

ตัวแปรอ่านค่าได้: `is_on`, `is_testing` · ปรับความเร็วไฟวิ่งที่ `step_time` (Inspector)

## ทดสอบแล้ว
นำเข้าและรันใน Godot 4.7.1: โครงสร้าง node, ตำแหน่ง/ทิศ PlugPoint, กด Test ตอนปิดเครื่อง, ไฟวิ่งสายปกติ, ไฟกะพริบสายหลวม, ปิดเครื่องแล้วหยุดทดสอบ — ผ่านทั้งหมด
