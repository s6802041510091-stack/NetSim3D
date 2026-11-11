# Desktop / NetPlan EDU v3

สถานะ: Network Designer ถูกถอดออกจากโปรเจกต์ Godot ตามคำขอแล้ว ส่วนไอคอนและเดสก์ท็อปภาพร่าง v3 รอตรวจ ยังไม่นำเข้าเกม

- desktop-mockup-v3-netplan.png — ภาพร่างล่าสุด แสดงหลังรับงานด่าน 1
- netplan-classroom-icon-v3.png — ไอคอนพื้นหลังโปร่งใส รูปห้องคอมและเราเตอร์สีส้ม
- v1/v2 เป็นแบบเก่า ไม่ใช้เป็นต้นแบบใหม่

ถอดตัวโปรแกรม Network Designer, ไอคอน, ทางเปิดจาก Start, การติดตั้งเริ่มต้น และตัวทดสอบโปรแกรมเก่าออกแล้ว ตรวจ validate_desktop_apps.gd ผ่านว่า NetPlan ซ่อนทั้ง Desktop/Start ก่อนติดตั้ง และเปิดได้หลังได้รับงาน

NetPlan EDU เป็นไอคอนรูปห้องเรียนจำลอง ไม่มีผังต้นไม้หรือกระดาษพิมพ์เขียวซ้ำแบบเดิม ต้องคงเงื่อนไขรับงานของ mission_01_controller.gd เมื่อสร้าง Desktop/Taskbar จริง

ภาพสร้างด้วยเครื่องมือ image_gen ในตัว

## Icon prompt
Create a polished Windows-11-style desktop APPLICATION ICON for "NetPlan EDU", a school computer-room network equipment planning app. One standalone icon, genuinely transparent background, NO TEXT and no label. The icon must remain recognizable at 48–64 px. Concept: a small friendly ISOMETRIC CLASSROOM FLOOR PLAN / room-layout tile, seen from above at a gentle 3/4 angle. An ivory-white floor slab with two low deep-blue walls forming an open L, TWO simple pale-blue student desks with tiny dark-blue monitor tops, and one prominent amber-orange network equipment block / router with two short upright blue antennae placed in the open right corner. A crisp tiny cyan Wi-Fi signal mark rises beside the orange router, suggesting planning wireless coverage. Use a strong clean silhouette, balanced chunky forms, soft bevels, subtle material shading and refined native OS icon quality. Blue #237DB1, deep navy, white and amber orange as accent. Icon fills about 80% of a square canvas with generous transparent margin, no cast shadow outside the object.
Important negatives: NO generic node-tree/network topology symbol, NO sheet of paper, NO blueprint grid, NO folded page corner, NO mouse pointer, NO monitor enclosing a diagram, NO abbreviation NP, NO letters, NO badges, no separate surrounding app-square plate. This is a completely new design with classroom layout and equipment, not a recolor of a network-tree icon.

## Desktop prompt
Use case: precise-object-edit / compositing. Image 1 is the previous full desktop mockup. Image 2 is the NEW approved-for-preview NetPlan EDU icon asset to insert exactly, with transparent background. Preserve image 1's wallpaper, full-width frosted taskbar, This PC, Network, Command Prompt, Recycle Bin icon art, clock and tray styling.
Remove the retired "Network Designer" application COMPLETELY from the desktop AND taskbar. Remove the old blue document/tree NetPlan EDU icon completely too.
Create a neat left column of EXACTLY FIVE desktop shortcuts at evenly spaced positions: This PC, Network, Command Prompt, NetPlan EDU, Recycle Bin. The new fourth shortcut uses image 2's isometric classroom tile with two computers and orange router, scaled to an appropriate approximately 64px OS shortcut icon size, with exact caption "NetPlan EDU" in the same clean white type as the other captions. The new icon must visibly be the classroom tile from image 2, NOT a branching tree or document. No Network Designer anywhere and no duplicate NetPlan icons.
Taskbar's centered group now has ONLY Start, Search, File Explorer, Command Prompt, and ONE small matching new classroom-tile NetPlan EDU icon. Recenter the remaining group neatly. Keep bottom-left Esc · Leave computer and bottom-right network/volume/time/date. No extra text, no preview insets, no annotations, no window border. One complete polished 16:9 desktop. This represents AFTER accepting Mission 1, so NetPlan EDU is visible.

