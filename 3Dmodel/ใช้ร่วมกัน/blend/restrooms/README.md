# สุขภัณฑ์สำหรับโรงเรียน

- `school_toilet.blend`: ปรับจาก `../WC.blend` เป็นขนาดจริง สูงประมาณ 0.82m วัสดุเซรามิกสีขาว พร้อมปุ่มกดและสายฉีดชำระ ไม่แก้ WC.blend ต้นฉบับ
- `school_basin.blend`: อ่างวงรีเว้าจริง ขอบมน มีรูระบายและก๊อกโค้ง
- `school_urinal.blend`: โถปัสสาวะติดผนัง มีส่วนเว้าด้านหน้า ท่อและปุ่มกด

แกน Z ชี้ขึ้น พื้นอยู่ที่ Z=0 ด้านหน้าหัน -Y; เมื่อส่งออก GLB เข้า Godot ด้านหน้าคือ +Z อ่างวางบนเคาน์เตอร์ ส่วนโถปัสสาวะมีระดับติดผนังรวมในโมเดลแล้ว

ส่งออกไปที่ `../../exports/restrooms/` และ `D:/NetSim3D/net-sim-3d/assets/models/restrooms/` ด้วย `D:/NetSim3D/3Dmodel/scripts/build_school_restroom_fixtures.py`

ผังห้องและประตูคอกอยู่ใน Godot ที่ `D:/NetSim3D/net-sim-3d/scripts/props/restrooms.gd` ดูรายละเอียดและผลทดสอบใน `D:/NetSim3D/net-sim-3d/RESTROOMS.md`
