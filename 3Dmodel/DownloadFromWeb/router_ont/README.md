# Router + ONT — คู่มือนำไปใช้ใน Godot 4.7

ทั้งสองตัวใช้สคริปต์เดียวกัน `network_device.gd` (`class_name NetworkDevice`)

## ไฟล์
| ไฟล์ | ใช้ทำอะไร |
|---|---|
| `router.tscn` | Wi-Fi Router — **วางไฟล์นี้ในฉาก** |
| `ont.tscn` | ONT ไฟเบอร์ (GPON) — **วางไฟล์นี้ในฉาก** |
| `network_device.gd` | สคริปต์ควบคุมไฟ/พอร์ต |
| `router.glb`, `ont.glb` | โมเดล |
| `source/` | ไฟล์ Blender + สคริปต์สร้างโมเดล (มี `.gdignore`) |

## Router (23 × 15 ซม., เสาสูง 15 ซม.)
- พอร์ตด้านหลัง: `Port_WAN` (กรอบสีน้ำเงิน), `Port_LAN1`–`Port_LAN4` (กรอบสีเหลือง), `Power_Inlet`, ปุ่ม `Button_Power`
- ไฟด้านบน: `LED_Power`, `LED_Internet`, `LED_WiFi24`, `LED_WiFi5`, `LED_LAN1`–`LED_LAN4`, `LED_WPS`
- เสาอากาศ `Antenna_1`–`Antenna_4` (จุดหมุนอยู่ที่ข้อพับ) → `set_antenna_angle(i, องศา)`

## ONT (16.5 × 11.5 ซม.)
- พอร์ตด้านหลัง: `Port_PON` (หัวไฟเบอร์ SC/APC สีเขียว), `Port_LAN1`, `Port_LAN2`, `Power_Inlet`
- ไฟด้านบน: `LED_Power`, `LED_PON`, `LED_LOS` (แดง = สัญญาณไฟเบอร์ขาด), `LED_LAN1`, `LED_LAN2`

ด้านหน้าเครื่อง (ฝั่งไฟ LED) หันไปทาง **+Z**, ด้านพอร์ตหันไปทาง **-Z**

## การใช้สคริปต์
```gdscript
@onready var router: NetworkDevice = $Router
@onready var ont: NetworkDevice = $ONT

router.set_power(true)                          # Power + WiFi24 + WiFi5 ติด (ตั้งใน leds_on_at_power)
router.set_led("Internet", NetworkDevice.Led.ON)
router.set_led("LAN2", NetworkDevice.Led.BLINK) # มีสายเสียบ + มี traffic
ont.set_led("LOS", NetworkDevice.Led.BLINK)     # จำลองสายไฟเบอร์มีปัญหา
router.get_port("WAN")                          # จุด snap หัวสาย (-Z = ทิศเสียบเข้า, +Y = ด้านหน้าสัมผัส)
router.list_ports()                             # ["LAN1","LAN2","LAN3","LAN4","WAN"]
```
| signal | เกิดเมื่อ |
|---|---|
| `power_changed(is_on)` | เปิด/ปิด |
| `led_changed(name, mode)` | สั่งเปลี่ยนไฟ |

Inspector: `led_colors` (สีไฟตามชื่อ), `leds_on_at_power`, `start_powered`, `blink_interval`

## ทดสอบแล้ว
Godot 4.7.1: รายชื่อไฟ/พอร์ตครบ, ทิศจุดเสียบ, เปิด-ปิด, ไฟ LAN, หมุนเสา — ผ่าน
