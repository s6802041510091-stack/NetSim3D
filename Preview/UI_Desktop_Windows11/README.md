# Desktop design preview

ฉบับล่าสุด: v4 แบบเรียบ ผู้ใช้อนุมัติและนำเข้า Godot แล้ว ภาพจริง: actual/desktop-after-work-en.png และ actual/desktop-after-work-th.png

ประวัติแบบ v3: ผู้ใช้ขอลดรายละเอียดต่อเป็น v4 และสั่งถอด Network Designer ออกจากเกมแล้ว

สถานะ: v4 ผ่านและติดตั้งใน Godot แล้ว ดู IMPLEMENTATION.md

ภาพ: desktop-mockup-v1.png

เมื่อผ่านแบบ: แยก wallpaper กับตัวควบคุม taskbar/shortcut ที่ใช้งานจริง เพื่อคงการเปิดโปรแกรม สถานะ LAN เวลา และการสลับภาษาของเกม

สร้างด้วย image_gen ในตัว โดยใช้ภาพเดสก์ท็อปเกมที่ผู้ใช้แนบเป็นอ้างอิงโครงสร้าง

## Prompt

Use case: ui-mockup. Create one polished FULL-SCREEN 16:9 1920x1080 desktop design preview for the simulated computers inside NetSim3D, visually inspired by Windows 11. The attached image is ONLY a reference for the existing application's five desktop shortcut names and their left-column placement. Output ONLY the desktop surface edge to edge, not a screenshot of a debug window or an app window inside another OS. No Godot chrome, no window title bar, no Objectives game HUD.
Wallpaper: original high-quality abstract flowing folded blue ribbon / soft sculptural blue bloom on a deep sapphire and navy background, inspired by the polished 3D flowing fabric feel of Windows 11, with luminous cyan edges and gentle studio lighting. Asymmetric big graceful folded forms concentrated in the center-right, plenty of quiet darker blue space on the left for readable icons. Elegant everyday school PC desktop, restrained and realistic rather than a sci-fi game HUD.
Desktop shortcuts in a neat SINGLE column down the upper left, evenly spaced: a detailed small monitor icon labelled "This PC"; a small blue/green network computers icon labelled "Network"; a black terminal icon labelled "Command Prompt"; a blue network-tree-in-monitor icon labelled "Network Designer"; a translucent empty recycling-bin icon labelled "Recycle Bin". Icons should be believable OS desktop icons, not squares containing abbreviation text. Labels white, small crisp readable Segoe UI-like sans, subtle dark shadow, no selection boxes.
Taskbar across the FULL bottom width, 52 px tall at 1080p, translucent very pale icy-blue frosted glass with subtle top edge, Windows 11-like proportions. CENTER aligned icon group: blue four-square Start icon, a compact rounded Search field with magnifier and word "Search", yellow folder File Explorer icon, terminal icon, network designer icon. Equal padding and small subtle running indicators under terminal and network designer. No app names inside taskbar. Left end has a tiny understated desktop/monitor glyph followed by "Esc · Leave computer" in muted navy small text. Right end: upward tray caret, wired-network status glyph, speaker volume glyph, compact two-line clock "18:27" and date "10/11/2026", then a tiny notification dot. Taskbar must look native, calm, clean and functional. Keep most of the wallpaper uncluttered. No giant title, no logo watermark, no game menu panel. The final image must feel like a usable Windows-11-inspired educational desktop screenshot.

