# NetCare WorkBook 14 — Laptop สำหรับ Day 1 Q1

โมเดล Laptop ทำงานกึ่งสมจริง สร้างใหม่ใน Blender เพื่อใช้คู่กับ Switch ในมินิเกมเชื่อม Office LAN เป็นแบบอุปกรณ์สมมติ ไม่ใช่โมเดล CAD ของผู้ผลิต และยังไม่ได้แทนที่โมเดลในฉาก Godot

## ไฟล์สำหรับเปิดดู

- `blend/office_laptop_14.blend` — ต้นฉบับ Blender พร้อมแสงและกล้อง
- `exports/office_laptop_14.glb` — เฉพาะ Laptop สำหรับนำเข้า Godot ไม่มีพื้น กล้อง และไฟ Studio
- `renders/office_laptop_14_hero.png` — มุมรวมด้านหน้าและด้านซ้าย
- `renders/office_laptop_14_front.png` — จอและคีย์บอร์ด
- `renders/office_laptop_14_ethernet_closeup.png` — รายละเอียดพอร์ต LAN
- `renders/office_laptop_14_rear.png` — ฝาหลังและพอร์ตด้านขวา
- `exports/office_laptop_14.validation.json` — ผลตรวจโครงสร้างไฟล์ส่งออก
- `exports/office_laptop_14.roundtrip.json` — ผลนำเข้า GLB กลับใน Blender และตรวจระยะปิดฝาจอ

## รายละเอียดโมเดล

- ตัวฐานขนาดประมาณ 338 × 234 × 23 มม. วัสดุโลหะสีเทา พร้อมยางรอง
- จอประมาณ 14 นิ้ว อัตราส่วน 16:9 เปิดทำมุม 102 องศากับฐาน
- คีย์บอร์ด QWERTY แยกปุ่ม Shift, Enter, Space และปุ่มลูกศร; มีทัชแพดและปุ่ม Power
- ช่อง Ethernet แบบ 8P8C หรือที่เรียกทั่วไปว่า RJ45 อยู่ด้านซ้าย มีหน้าสัมผัส 8 จุดและช่องล็อกหัวสาย
- ตัวถังมีช่องเปิดตรงพอร์ต LAN และ USB ไม่ใช่เพียงภาพวาดบนผิวตัน
- พอร์ต USB-A สองช่อง, HDMI, ช่องหูฟัง และช่องไฟ DC ใช้แยกแยะประเภทช่องเสียบได้
- กล้องและไมโครโฟนเหนือจอ บานพับ ช่องระบายอากาศ และช่องลำโพง
- ไม่มีเสาอากาศภายนอก ไม่แสดงชิป NIC อยู่ด้านนอก: NIC เป็นวงจรภายใน Laptop ส่วนที่เห็นคือช่อง Ethernet
- ภาพพรีวิวเปิดเครื่องด้วยแบตเตอรี่ ไม่มีสายไฟหรือสาย LAN ต่ออยู่; ไฟ Link/Activity จึงปิด
- หน้าจอเขียน “Not connected” เป็นภาพ UI ตัวอย่างแบบนิ่ง ไม่ใช่ระบบตรวจเครือข่ายจริง
- ใช้วัสดุ PBR สีพื้น ไม่มี Texture หรือโมเดลจากบุคคลที่สาม

## ชิ้นส่วนสำหรับพัฒนาต่อ

| ชื่อวัตถุ | การใช้งาน |
|---|---|
| `OfficeLaptop_14` | จุดรวมทั้งเครื่อง |
| `Chassis_Base` | ตัวถังล่างและชิ้นส่วนคงที่ |
| `Keyboard_Keycaps` / `Keyboard_Legends` | ปุ่มและตัวอักษร |
| `Touchpad` / `PowerButton` | ทัชแพดและปุ่มเปิดเครื่อง |
| `Display_Hinge` | จุดหมุนชุดจอ |
| `Display_Housing` | ฝาและกรอบจอ |
| `Screen_Panel` | แผงจอสำหรับเปลี่ยนวัสดุหรือใช้แสดง UI |
| `Screen_Demo_UI` | UI ตัวอย่าง แยกซ่อนหรือนำออกได้ |
| `Port_RJ45_LAN` | ช่อง LAN พร้อมหน้าสัมผัส 8 จุด |
| `Socket_RJ45_LAN` | จุดอ้างอิงสำหรับวางปลายสาย LAN |
| `LED_LAN_Link` / `LED_LAN_Activity` | ไฟสถานะเครือข่ายแยกวัสดุและวัตถุ |
| `LED_Power` | ไฟ Power |
| `USB_A_Left` / `USB_A_Right` / `Port_HDMI` | ช่องเสียบที่ไม่ใช่ LAN |

การหมุนจอใน Blender: `Display_Hinge` ใช้แกน X, ค่าเริ่มต้น −12° สำหรับเปิดจอ 102° และ +90° สำหรับปิดฝา โดยมีระยะเว้นเหนือปุ่มคีย์บอร์ด

หน่วยส่งออกเป็นเมตร glTF ใช้แกน +Y ขึ้นและด้านหน้าตัวเครื่อง +Z; Socket ของ LAN มีแกน +Z เฉพาะจุดหันออกจากพอร์ตไปด้านซ้ายของเครื่อง

จุด Socket เป็น Empty/Node3D เท่านั้น ยังไม่มี Collision, การกด E, การตรวจเสียบสาย, การเปลี่ยนไฟตามการเชื่อมต่อ หรือ UI ที่ทำงานจริง โมเดลยังต้องเชื่อมระบบเหล่านี้ในขั้นพัฒนาเกม

## การจัดเก็บและสร้างซ้ำ

ทุกไฟล์อยู่ใต้ `D:\Game Network\NetLife3D\assets\3Dmodel` ตัวรันกำหนด Temp/Cache/Blender User Files ไปที่ `temp/laptop` บนไดรฟ D ตัวโปรแกรม Blender ยังเรียกจากตำแหน่งติดตั้งเดิมบน C

- `scripts/run_build_laptop.ps1` — สร้างและเรนเดอร์ Laptop ใหม่
- `scripts/run_build_laptop.ps1 -ValidateOnly` — ทดสอบนำเข้า GLB กลับใน Blender

การสร้างซ้ำเขียนทับเฉพาะผลลัพธ์ชื่อ `office_laptop_14` หากแก้ไฟล์ด้วยมือให้บันทึกชื่อใหม่ก่อนรันซ้ำ ไม่เปลี่ยนไฟล์ Switch ที่ทำไว้ก่อนหน้า

## อ้างอิงทางเทคนิค

[Lenovo PSREF — ThinkPad E14 Gen 6](https://psref.lenovo.com/syspool/Sys/PDF/ThinkPad/ThinkPad_E14_Gen_6_Intel/ThinkPad_E14_Gen_6_Intel_Spec.pdf) ใช้ตรวจว่ารูปแบบ Laptop ทำงานพร้อม Ethernet ในตัวมีใช้งานจริงเท่านั้น ไม่ได้คัดลอกรูปทรง ตำแหน่งพอร์ต ขนาด หรือวัสดุของผลิตภัณฑ์ดังกล่าว
