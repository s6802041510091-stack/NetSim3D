# Desktop v4 — implementation

ผู้ใช้อนุมัติภาพ desktop-mockup-v4-simple.png และไอคอน netplan-simple-icon-v4.png แล้ว

## ไฟล์ใช้งานจริง

- ../../net-sim-3d/assets/ui/desktop/wallpaper-blue.png — วอลเปเปอร์แยกจากตัวควบคุม
- ../../net-sim-3d/assets/ui/desktop/system-icons.png — ไอคอนระบบ 4 รูปใน atlas
- ../../net-sim-3d/assets/ui/desktop/netplan-edu.png — ไอคอน NetPlan v4 ที่อนุมัติ
- ../../net-sim-3d/scripts/computer/desktop_art.gd — แสดง atlas ด้วย UV ที่วัดไว้ ใช้ภาพต้นฉบับโดยไม่มีการอ่านพิกเซลจาก GPU ขณะเล่น
- ../../net-sim-3d/scripts/computer/desktop_os.gd — Desktop, Taskbar, Start และค้นหาโปรแกรม

ภาพวอลเปเปอร์และ atlas แยกด้วย image_gen ในตัว ไอคอน NetPlan คัดลอกจากไฟล์ v4 ที่อนุมัติโดยตรง ส่วนสัญลักษณ์เล็กของ Start/Search/Folder/Volume/แอปด่าน 5–6 ใช้ SVG ภายในเกม

## การทำงาน

- Taskbar โปร่งแสงสีฟ้าอ่อน ไอคอนตรงกลาง แสดงเวลาและวันที่จากระบบจริง สถานะ LAN จาก ComputerStation
- Start และช่อง Search ค้นหาโปรแกรมที่ติดตั้งบนเครื่องนั้นได้
- File Explorer เปิด This PC; ปุ่ม CMD เปิดโปรแกรม Command Prompt เดิม
- NetPlan/Windows Security/TeamViewer ใช้ฟังก์ชันเดิม และแสดงเฉพาะเมื่อเครื่องมีแอปติดตั้ง
- กดปุ่มแอปบน Taskbar เพื่อเปิด ย่อ หรือเรียกหน้าต่างกลับมา มีเส้นบอกแอปที่ยังเปิดอยู่
- NetPlan ไม่ปรากฏบน Desktop/Start/Taskbar ก่อนรับงานด่าน 1 เงื่อนไขติดตั้งเดิมใน mission_01_controller ไม่เปลี่ยน
- ไม่มี Network Designer
- การสลับภาษาไทย/ENG แปลช่องค้นหาและข้อความควบคุม โดยชื่อซอฟต์แวร์ยังเป็นชื่อเดิม

## ผลตรวจ

- validate_desktop_shell.gd ผ่าน: เมาส์จริงเปิด CMD, hostname, ย่อ/เรียกคืน, Search, เปิด–ย่อ–เรียกคืน–ปิด NetPlan, ตรวจไอคอน/ตัวบอกสถานะ และไทย/ENG
- validate_desktop_apps.gd ผ่าน: แอปเก่าไม่อยู่และ NetPlan แสดงตามสถานะติดตั้ง
- validate_computers.gd ผ่านในหน้าต่างจริง: คอม 29 เครื่อง, นั่ง/บูต/เดสก์ท็อป, ปิดการเดินขณะใช้เครื่อง, ipconfig, ping สำเร็จ/หมดเวลา/สายไม่เสียบ และออกกลับมาเดิน
- ภาพจริงอยู่ใน actual/ ส่วนภาพร่างรุ่นเก่าเก็บเป็นประวัติ
- ยังไม่ได้ส่งออกเว็บชุดใหม่ในรอบนี้

## คำสั่งสร้างภาพสำหรับ asset

Wallpaper (image_gen): Edit the approved desktop mockup into a clean wallpaper asset. Remove all shortcuts, captions and the entire taskbar. Reconstruct the same blue folded-ribbon wallpaper behind them to the bottom edge; preserve its lighting, colors, composition and dark left area. No new UI or text.

System icon atlas (image_gen): Transparent square PNG, 2×2 equal cells with a blue monitor top-left, two blue monitors and a green wired connector top-right, black terminal with >_ bottom-left, clear recycling bin bottom-right. Match the approved desktop's OS icon styling, generous transparent margins, no captions or separators.

ไอคอน NetPlan v4 และคำสั่งฉบับเต็มอยู่ใน NETPLAN_V4.md
