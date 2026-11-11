# Desktop with NetPlan EDU — v2

ภาพสำหรับตรวจ: desktop-mockup-v2-netplan.png

เพิ่ม NetPlan EDU เป็นไอคอนเอกสาร blueprint พร้อมผังเครือข่ายและลูกศรเมาส์สีส้ม ให้แยกจาก Network Designer ซึ่งใช้จอคอมพร้อมผังเครือข่าย

ภาพนี้เป็นสถานะหลังคุยรับงานด่าน 1 จากหัวหน้าแล้ว เมื่อทำใน Godot ต้องยึด station.has_app("netplan_edu") ของระบบเดิม ทั้ง Desktop, Start และ Taskbar ก่อนรับงานต้องไม่แสดงไอคอนนี้ ภาพร่างไม่ใช่การเปลี่ยนเงื่อนไขภารกิจ

สร้างด้วย image_gen ในตัว โดยอ้างอิงภาพร่าง v1 และภาพหน้าจอจากผู้ใช้ ยังไม่แก้ Godot

## Prompt

Use case: precise-object-edit / ui-mockup. Image 1 is the EXISTING desktop design mockup to edit. Image 2 is ONLY a supporting screenshot showing the newly available app named NetPlan EDU; do not copy its plain wallpaper, debug window frame or Objectives overlay.
Preserve image 1's entire polished Windows-11-inspired blue folded-ribbon wallpaper, frosted full-width taskbar, center Start/Search/File Explorer/terminal/Network Designer group, tray and clock, and left desktop icon style and spacing.
Add the MISSING Mission 1 application as a desktop shortcut labelled exactly "NetPlan EDU". The SINGLE left column must now have SIX shortcuts, in this exact top-to-bottom order: This PC, Network, Command Prompt, Network Designer, NetPlan EDU, Recycle Bin. Keep the first four icons in their current positions. Place NetPlan EDU in the former Recycle Bin slot; move Recycle Bin one equal step lower. Everything must fit with comfortable margin above the taskbar. No duplicate shortcuts.
Design NetPlan EDU's icon as a distinctive professional small Windows-style app icon: a blue blueprint/document sheet with a folded white corner, a faint white room-plan grid and a clear small three-device branching network diagram with a tiny orange selection cursor. It should communicate educational room network planning. It MUST look different from Network Designer, which keeps its original monitor-and-network-tree icon. Match the crisp subtly dimensional OS icon quality of the other shortcuts; no plain square with NP letters.
Also add a matching small NetPlan EDU blueprint icon to the centered taskbar beside Network Designer, with no running underline for NetPlan because it has not been opened yet. Keep all taskbar icons properly spaced and their group visually centered.
This image represents the desktop AFTER the player accepts Mission 1 from the Data Center supervisor. Do not write this explanation on the desktop. NetPlan is meant to be hidden before mission acceptance; do not add a permanent menu or mission instructions. No other design changes. Output one full-screen 16:9 finished desktop preview, no surrounding app window or watermark.

