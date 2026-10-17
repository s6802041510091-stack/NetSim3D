# Phase 4 — เฟอร์นิเจอร์และฉากประกอบ

ดำเนินงานวันที่ 16 ตุลาคม 2026 ต่อจาก Phase 3 ในไฟล์ Lookdev เท่านั้น ไม่แทนที่ GLB หรือฉากของเกมหลัก

## ไฟล์และหลักฐาน

- Blender หลังปรับ: `../working/classroom_shell_lookdev.blend`
- สำรองก่อนเริ่ม: `../working/classroom_shell_lookdev_before_phase4.blend`
- สคริปต์: `../../scripts/phase4_furniture.py`
- สำรวจวัตถุ: `audit.json`
- รายการแก้ไข: `changes.json`
- สัญญาก่อนแก้ไข: `before_snapshot.json` และ `before_bounds.json`
- ผลตรวจ Blender: `verification.json`
- ภาพก่อน–หลัง: `renders/before_*.png` และ `renders/after_*.png`
- GLB และโปรเจกต์ Godot แยก: `godot_preview/`

## สิ่งที่ปรับ

- วัสดุเฟอร์นิเจอร์และของประกอบ 240 วัตถุ ครอบคลุมห้องคอม สำนักงาน IT ห้องเก็บอุปกรณ์ ห้องพักครู Pantry ห้องวิทยาศาสตร์ และ NOC
- ปรับ geometry เบาะเก้าอี้ โซฟา และใบไม้ 59 วัตถุ โดยคงตำแหน่ง จุดหมุน และขอบเขตเดิม
- เปลี่ยนใบทรงกรวยเป็นแผ่นใบโค้ง มีปลายเรียวและก้านเชื่อมลำต้น วัสดุใบไม้แสดงสองด้าน
- เพิ่มตัวพิมพ์บนฉลากกล่อง ตู้ ลิ้นชักและสันหนังสือ โดยรวม geometry เป็น 28 กลุ่มตามวัตถุเจ้าของ ไม่สร้าง object แยกทุกตัวอักษร
- ตัดตัวพิมพ์ตกแต่งที่เพิ่มในรอบทดลอง 15 กลุ่มออกจากตู้ที่มีข้อความเดิมอยู่แล้ว ไม่ลบข้อความต้นฉบับ (รายละเอียดที่ตัดออกสร้างใหม่จากสคริปต์ได้ แต่ไม่ควรนำกลับมาซ้อนข้อความเดิม)
- Texture PBR ใหม่ 39 ชุด รวม 117 PNG ขนาด 512 × 512: Base Color, Roughness, Normal พร้อม UV ตามสเกลวัสดุ
- ใช้ไม้ ผ้า เหล็กพ่นสี พลาสติกและโลหะจาก Phase 1–3 ร่วมตามความเหมาะสม ไม่แก้วัสดุต้นแบบเหล่านั้นทั่วฉาก
- รักษามุมตัวอย่าง Phase 1 (`IT_PlayerDesk`, `Chair_IT_PlayerDesk_1`, `IT_Bookcase_North`) ไว้

Texture ใหม่ทั้งหมดเป็นลวดลาย procedural ที่สร้างในสคริปต์ ไม่มีภาพจากเว็บหรือสินทรัพย์ภายนอกเพิ่มใน Phase นี้ ฉลาก REF / FILE / PARTS เป็นรายละเอียดภาพ ไม่ใช่รหัสภารกิจใหม่

## การตรวจ

Blender ตรวจวัตถุเดิม 10,526 ชิ้น: ชื่อ transform, parent, custom properties และสถานะซ่อนต้องเหมือนก่อนเริ่ม ส่วน geometry และวัสดุเปลี่ยนได้เฉพาะรายการที่อนุญาต ตรวจ UV, ขอบเขต geometry และ hash ไฟล์ต้นฉบับ 168 ไฟล์ด้วย

ภาพตรวจ 10 มุม ใช้กล้องและแสงเท่ากันก่อน–หลัง: classroom, it_office, lounge, pantry, staff, storage, science, noc, plant และ workstation (ต้นไม้จิ๋วบนโต๊ะ)

Godot 4.7.1 Compatibility นำเข้าผ่าน: MeshInstance3D 8,784 ชิ้น, จอ 29 จุด, รายละเอียด Rack ของ Phase 3 จำนวน 20 กลุ่ม, ฉลากใหม่ 28 กลุ่ม และวัสดุ PBR ใหม่ 39 ชุดมี texture ทั้งสามช่องครบ ผลอยู่ใน `godot_preview/import_validation.json` ภาพจาก renderer จริงใช้ชื่อ `godot_*.png`

จับภาพจาก OpenGL Compatibility บน NVIDIA RTX 3060 Laptop GPU ครบ 10 มุม (1080 × 720) และตรวจด้วยตาแล้ว ไม่พบวัสดุหายหรือ geometry ที่ปรับหายระหว่างนำเข้า โปรแกรม capture จบด้วย exit code 0 และไม่มีข้อความใน capture_error.log; ดูรายละเอียด `VISUAL_QA.md`

Blender verification รอบส่งมอบผ่าน ไม่มี errors; geometry พื้นฐานที่ไม่ซ้ำกันรวม 784,404 triangles (ไม่รวมผล modifiers/จำนวน instances จึงไม่ใช่จำนวน triangles ที่วาดจริง) GLB ตัวอย่างขนาด 320,486,672 ไบต์ ประมาณ 305.6 MiB เป็นไฟล์ตรวจภาพ ยังไม่ผ่านการลดขนาดหรือวัดเวลาโหลดสำหรับเว็บ

การนับจอหรือชื่อวัตถุไม่ใช่หลักฐานว่า interaction เล่นได้ และจำนวน triangles ไม่ใช่ผลวัด FPS

## ขอบเขตที่ยังไม่รวม

- ไม่เปลี่ยนตำแหน่งห้อง ทางเดิน จุดใช้งาน จำนวนพอร์ต หรือ bindings ภารกิจ
- ไม่ append สุขภัณฑ์จาก `WC.blend` หรืออุปกรณ์ไฟล์แยกเข้าฉาก
- ไม่รื้อสร้าง props ทุกชนิดใหม่ รูปทรงพื้นฐานของเครื่องใช้ Pantry และอุปกรณ์ห้องวิทยาศาสตร์ส่วนใหญ่คงเดิม
- ยังไม่รวมเข้า `main.tscn` / GLB เกมหลัก ไม่ตรวจ collision, interaction, แสงจริงในเกม หรือ Web performance ใน Phase 4
- Phase 5 ต้องรวมแผนที่ โถงและ collision รุ่นเดียวกัน ตรวจจอ/ประตูโดยใช้งานจริง และวัด FPS, draw calls, RAM/VRAM และเวลาโหลดบนเครื่องเป้าหมาย

## เรียกซ้ำ

ใช้ Blender แบบ background พร้อม `--python-exit-code 1 --python .../phase4_furniture.py -- <mode>`

- `verify`: ตรวจไฟล์ปัจจุบันและเขียน verification.json
- `before [view]` / `after [view]`: เรนเดอร์ทั้งหมดหรือเฉพาะมุมที่ระบุ
- `export`: สร้าง GLB ทดสอบใหม่ (แทนที่เฉพาะ furniture_map.glb ในโปรเจกต์ทดสอบ)
- `refine`: สร้างเฉพาะเบาะและใบไม้ใหม่จาก mesh ในสำรองก่อน Phase 4 แล้วตรวจสัญญาก่อนบันทึก ไม่สร้างฉลากซ้ำ
- `build`: ใช้ได้เฉพาะก่อนเริ่ม Phase 4; สคริปต์จะปฏิเสธเมื่อมีสำรองแล้ว ห้ามลบสำรองเพื่อฝืนรันซ้ำ

Godot: เปิด `godot_preview/project.godot` เพื่อดูภาพ กด 1–9 และ 0 เปลี่ยนมุม / Esc ปิด; `-- --validate` ตรวจ import อย่างเดียว; `-- --capture` บันทึกภาพครบ 10 มุมและปิดโปรแกรม ต้อง import GLB ด้วย editor ก่อน และโหมด capture ต้องใช้ renderer จริง ไม่ใช้ `--headless`
