# ภาพร่างหน้าเลือกด่านและตัวเลือกภาษา

สถานะ: ผู้ใช้อนุมัติแล้ว นำเข้า Godot พร้อมระบบไทย / ENG และตัวควบคุมจริงเรียบร้อย ภาพที่จับจาก Godot อยู่ใน actual/

## ภาพสำหรับตรวจ
- select-level-th-draft.png — ภาษาไทย แสดงชื่อด่านหลักเพียงชื่อเดียว
- select-level-en-draft.png — ภาษาอังกฤษ แสดงชื่อด่านเพียงชื่อเดียว
- settings-language-th-draft.png — เพิ่มตัวเลือก ไทย / ENG ในหน้าตั้งค่า

ไอคอนทั้ง 6 แสดงครบในแบบร่างเพื่อให้ตรวจความหมายได้ การแสดงสถานะล็อก/กำลังพัฒนาในเกมต้องยึดสถานะด่านจริงเมื่อทำใน Godot

## ชื่อด่านตามภาษา
| ด่าน | ไทย | English |
|---|---|---|
| 1 | เลือกอุปกรณ์เครือข่าย | Choose Devices |
| 2 | เข้าหัวสาย LAN | Crimp LAN Cables |
| 3 | ตรวจเครือข่ายด้วย ping | Ping Test |
| 4 | เปลี่ยนการ์ดเครือข่าย | Replace the NIC |
| 5 | ป้องกันภัยคอมพิวเตอร์ | Firewall & Antivirus |
| 6 | ช่วยเหลือระยะไกล | Remote Help |

## เมื่อนำไปทำจริงหลังอนุมัติ
เลือกภาษาใน Settings และบันทึกตัวเลือกให้ใช้ในการเปิดเกมครั้งถัดไป หน้าเลือกด่านแสดงชื่อภาษาเดียวตามค่าที่เลือก การแปลข้อความในเกมและภารกิจเป็นงานดำเนินการหลังอนุมัติภาพร่าง ยังไม่ได้แก้ Godot ในรอบนี้

## เครื่องมือและคำสั่งสร้างภาพ
สร้างด้วยเครื่องมือ image_gen ในตัว ใช้ภาพอ้างอิงของผู้ใช้และภาพหน้าตั้งค่าที่อนุมัติแล้ว

### Thai level selection
Use case: ui-mockup / precise-object-edit. Edit the supplied NetSim3D level-selection screen as a polished full-screen 16:9 Thai-language UI mockup. Preserve the EXACT illustrated school/cherry-blossom background, translucent glass panel, logo NetSim3D and SCHOOL NETWORK LAB, card positions, blue-white palette, soft shadows, 3 by 2 card grid and overall composition of the reference. Only update the screen heading, all six card icons and labels and back button. All SIX cards have the same white face with bright blue outlined border; no padlocks, no greyed out cards, no IN DEVELOPMENT labels for this design preview.
Heading in blue pill: "เลือกด่าน". Card headings top: "ด่าน 1", "ด่าน 2", "ด่าน 3", "ด่าน 4", "ด่าน 5", "ด่าน 6". Beneath each icon use ONLY ONE main title in Thai, NO English subtitles and NO descriptive text. Exact Thai titles:
1 "เลือกอุปกรณ์เครือข่าย"
2 "เข้าหัวสาย LAN"
3 "ตรวจเครือข่ายด้วย ping"
4 "เปลี่ยนการ์ดเครือข่าย"
5 "ป้องกันภัยคอมพิวเตอร์"
6 "ช่วยเหลือระยะไกล"
Bottom-left blue button "กลับ".
Typography clean bold Anuphan-like Thai sans, clear Thai marks, navy ink, same title size consistently, ample spacing so titles never touch borders.
Icons centered, same visual size and consistent flat vector rounded thick outline, blue #237DB1, navy outline, clean white field, no drop shadow inside icons, simple readable shapes. 1: a router at the top branching down in a tree to a switch and a Wi-Fi symbol, exactly three devices/symbols, with orange mouse pointer clicking one device. 2: a large transparent RJ45 connector with EIGHT colored wires visible (orange/white-orange, green/white-green, blue/white-blue, brown/white-brown) and the jaws of an orange/blue crimping tool closing around its sides; not just a cable loop. 3: dark terminal window displaying ">_ ping" and beneath TWO green checkmarks and ONE red X. 4: green PCI network circuit board with silver RJ45 port on edge and blue/orange opposing curved swap arrows. 5: a shield divided vertically, left half brick firewall pattern, right half orange bug crossed out by a slash; NO padlock. 6: TWO computer monitors connected by a dotted line with bidirectional orange arrows, right monitor has speaker emitting orange sound waves; NO headset operator. Keep illustration quality as crisp and finished as the reference. Do not add language selector on this level screen. Render one full screen, not a comparison board.

### English level selection
Use case: text-localization. Edit this exact supplied Thai level-selection mockup into an ENGLISH version. Preserve every visual element: cherry-blossom school background, NetSim3D logo, translucent panel, blue pill, 3x2 grid, ALL SIX existing detailed icons and card borders, positions and sizes. Change ONLY these texts. Heading "SELECT LEVEL". Top card headings "LEVEL 1", "LEVEL 2", "LEVEL 3", "LEVEL 4", "LEVEL 5", "LEVEL 6". Each card has exactly ONE title at bottom and NO subtitle, using bold navy sans serif consistent with reference. Exact titles: 1 "Choose Devices"; 2 "Crimp LAN Cables"; 3 "Ping Test"; 4 "Replace the NIC"; 5 "Firewall & Antivirus"; 6 "Remote Help". Back button "BACK". Do not add Thai text, secondary titles, padlocks or development badges. Keep all six icons exactly recognizable as in reference. In level 2 ensure RJ45 has EIGHT visible wire conductors, arranged white-orange/orange/white-green/blue/white-blue/green/white-brown/brown; preserve crimping jaws. Render one finished 16:9 screen.

### Settings with language choice
Use case: ui-mockup / precise-object-edit. Edit the supplied approved Godot settings screen into a THAI language setting design preview. Preserve the exact cherry blossom school background and the approved simple translucent white rounded glass panel, navy typography, thin dividers, coral audio sliders, white percentage values area and blue Back button style. Do not replace with a different settings aesthetic. Fit an additional language row ABOVE the AUDIO section, retaining THREE audio sliders below it. Keep clean spacing and readable labels. Brand at top "NetSim3D / SCHOOL NETWORK LAB". Main heading "ตั้งค่า". Small subtitle "ปรับภาษาและเสียง • บันทึกอัตโนมัติ". New row: left label "ภาษา"; right two-segment rounded selector with labels "ไทย" and "ENG", ไทย selected filled bright blue with white text, ENG unselected cream with navy text. Section heading "เสียงในเกม". Three audio rows with small existing music, speaker, leaf outline icons respectively, exact Thai labels "เพลงประกอบ", "เอฟเฟกต์เสียง", "เสียงบรรยากาศ". Each row has a coral slider at 80% and navy "80%" at right. Bottom blue button with white left arrow and text "กลับ". Anuphan-style clean Thai headings and Sarabun-style body, natural restrained approved UI styling. No bilingual duplicate headings, no extra descriptions, no additional controls. Render one full-screen 16:9 preview, no desktop window border.

