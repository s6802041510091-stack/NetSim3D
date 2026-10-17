# Phase 3 — อุปกรณ์ทำภารกิจ

ดำเนินงานวันที่ 16 ตุลาคม 2026 ต่อจาก Phase 2 โดยรักษาชื่อ ตำแหน่ง parent, transform, geometry, custom properties และจุดอ้างอิงของอุปกรณ์เดิม

## ไฟล์หลัก

- ไฟล์ Blender หลังปรับ: `../working/classroom_shell_lookdev.blend`
- สำรองก่อน Phase 3: `../working/classroom_shell_lookdev_before_phase3.blend`
- สคริปต์สร้างและตรวจ: `../../../3Dmodel/scripts/phase3_equipment.py`
- รายงานสำรวจ: `audit.json`
- รายการเปลี่ยนแปลง: `changes.json` และ `asset_changes.json`
- ผลตรวจ Blender: `verification.json`
- ผลตรวจ Godot: `godot_preview/import_validation.json`

## งานที่ทำ

- ปรับผิววัสดุของคอมพิวเตอร์ จอ แป้นพิมพ์ เมาส์ สายไฟ อะแดปเตอร์ อุปกรณ์เครือข่าย ตู้ Rack, UPS และ Battery Cabinet
- สร้าง Texture PBR 10 ชุด ชุดละ Base Color, Roughness และ Normal รวม 30 ภาพ ขนาด 512 × 512 พิกเซล
- เพิ่มรายละเอียดอุปกรณ์หน้าตู้ Rack 20 ชุด โดยมีช่อง 8P8C ขอบโลหะ ช่องลึก และหน้าสัมผัสแยกกัน
- รักษาพื้นผิวจอ 29 จุดไว้ ไม่แทนที่วัสดุจอหรือเปลี่ยน geometry ของอุปกรณ์เดิม
- สร้างไฟล์ Lookdev แยกสำหรับ Cable Tester, Crimper, CAT6, Router/ONT, Switch 8 พอร์ต และ Server โดยรักษารูปทรง จุดหมุน และพอร์ตเดิม

## ผลตรวจ

Blender verification ผ่าน:

- ตรวจวัตถุเดิม 10,506 ชิ้น
- วัตถุที่เปลี่ยนวัสดุ 6,720 ชิ้น ใช้ Mesh ผิวที่ไม่ซ้ำกัน 639 ชุด
- รายละเอียด Rack ที่เพิ่มแบบใช้ข้อมูลร่วมกัน 20 ชุด
- หน้าจอเดิมครบ 29 จุด
- ไฟล์ต้นฉบับที่บันทึก hash ไว้ครบ 168 ไฟล์
- ไม่พบชื่อ ตำแหน่ง parent, transform, geometry, custom properties หรือสถานะซ่อนของวัตถุเดิมเปลี่ยนผิดขอบเขต

Godot 4.7.1 Compatibility นำเข้า `godot_preview/equipment_map.glb` ผ่าน:

- MeshInstance3D 8,756 ชิ้น
- หน้าจอ 29 จุด
- รายละเอียด Rack 20 ชุด
- วัสดุ PBR ของ Phase 3 มี Base Color, Roughness และ Normal ครบ
- ตัวตรวจอยู่ใน `godot_preview/validate_import.gd`

ภาพก่อน–หลังอยู่ใน `renders/` จำนวน 4 มุม: student, computer_rear, power และ server

## ขอบเขตที่ยังไม่รวม

Phase 3 นี้เป็นการปรับโมเดลและตรวจ Visual Import แยก ยังไม่ได้แทนที่ GLB หรือ `main.tscn` ของเกมหลัก การทดสอบการกดใช้งานจริง Collision แสงเกมจริง และประสิทธิภาพ Web ต้องทำพร้อมการรวมรุ่นแผนที่ใน Phase 5

## คำสั่งทำซ้ำ

เรียก Blender แบบ background ด้วย `phase3_equipment.py` และโหมดต่อไปนี้:

- `assets` — สร้างอุปกรณ์ Lookdev แยก
- `before` / `after` — เรนเดอร์ภาพตรวจ
- `export` — ส่งออก `equipment_map.glb`
- `verify` — ตรวจสัญญาไฟล์ Blender

ห้ามรัน `map` ซ้ำบนไฟล์ที่มี `phase3_revision` แล้ว ให้ใช้ไฟล์สำรองหากต้องสร้าง Phase 3 ใหม่ทั้งหมด
