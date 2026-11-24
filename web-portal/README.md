# NetSim เว็บหลัก (web-portal)

เว็บหลักที่รวมทุกส่วนไว้ที่เดียว: ล็อกอิน เลือกบทบาท ข้อมูลนักเรียน คลาส และทางเข้า Simulation กับเกม
แบบร่างทั้งระบบอยู่ที่ [`../เว็บไซต์/README.md`](../เว็บไซต์/README.md)

| เส้นทาง | อะไร | มาจากไหน |
|---|---|---|
| `/` | หน้าเว็บหลัก (React + Vite + TypeScript) | `web/` |
| `/api/` | API กลาง (Express + TypeScript) | `api/` |
| `/sim/` | Simulation (Net-Desktop) | สร้างจากรีโป [Mxles-Arm/Net-Desktop](https://github.com/Mxles-Arm/Net-Desktop) ตอน build |
| `/game/` | เกม NetSim3D (Godot Web) | export จาก `../net-sim-3d` ลง `game-build/` |

ฐานข้อมูล PostgreSQL 16 รันในคอนเทนเนอร์ `db` ข้อมูลเก็บใน Docker volume `pgdata`

## เปิดทั้งระบบด้วย Docker

ต้องมี Docker Desktop (Windows) หรือ Docker Engine + Compose (Linux), Node.js 24 ขึ้นไป และ Godot 4.7 ที่ติดตั้ง Web export templates แล้ว

```powershell
cd web-portal
copy .env.example .env          # แล้วแก้ค่าใน .env (รหัสผ่านฐานข้อมูล, อีเมลครู)
node scripts/export-game.mjs    # export เกมลง game-build/ (ทำใหม่ทุกครั้งที่เกมเปลี่ยน)
docker compose up -d --build
```

เปิด <http://localhost:8080>

- อัปเดต Net-Desktop เป็นเวอร์ชันล่าสุดของเพื่อน: `docker compose build --no-cache sim` แล้ว `docker compose up -d`
- ปิดทั้งระบบ: `docker compose down` (ข้อมูลยังอยู่ใน volume)
- ดู log: `docker compose logs -f api`

## พัฒนาบนเครื่อง (แก้โค้ดแล้วเห็นผลทันที)

1. เปิดฐานข้อมูลอย่างเดียว โดยเปิดพอร์ต 5433 ให้เครื่องตัวเอง:
   `docker compose -f docker-compose.yml -f compose.dev.yml up -d db`
2. สร้างไฟล์ `.env.local` (ไม่ขึ้น GitHub):
   ```
   DATABASE_URL=postgres://netsim:<POSTGRES_PASSWORD>@localhost:5433/netsim
   TEST_DATABASE_URL=postgres://netsim:<POSTGRES_PASSWORD>@localhost:5433/netsim_test
   DEV_LOGIN=true
   TEACHER_EMAILS=อีเมลครู
   ```
3. `cd api && npm install && npm run dev` (API ที่พอร์ต 3000)
4. `cd web && npm install && npm run dev` แล้วเปิด <http://localhost:5173>

ทดสอบ API: `cd api && npm test` (ใช้ฐานข้อมูล `netsim_test` แยกต่างหาก) และ `npm run typecheck`

## ล็อกอินทดสอบ และความปลอดภัย

- `DEV_LOGIN=true` ให้พิมพ์อีเมลใดก็เข้าได้ ใช้ตอนพัฒนาเท่านั้น **บนเซิร์ฟเวอร์จริงต้องเป็น `false`** (ระยะถัดไปจะเปลี่ยนเป็น Google Login)
- `TEACHER_EMAILS` คือรายชื่ออีเมลที่เป็นครูได้ ระบบถือค่านี้เป็นหลักทุกครั้งที่เปิด API เอาอีเมลออกแล้วคนนั้นจะหมดสิทธิ์ครูทันที
- รหัสผ่านคลาสเก็บแบบ bcrypt, คุกกี้ล็อกอินเป็น HttpOnly + SameSite=Lax และเก็บในฐานข้อมูลเป็น hash, คำขอที่เปลี่ยนข้อมูลต้องมาจากหน้าเว็บของเราเอง
- ใส่รหัสผ่านคลาสผิด 5 ครั้งใน 10 นาที จะถูกพักการเข้าคลาสชั่วคราว
- บนเซิร์ฟเวอร์ที่มี HTTPS ตั้ง `COOKIE_SECURE=true`

## คะแนนเกม (ระยะ 4–5)

- เกมส่งผลทุกครั้งที่จบด่านไปที่ `POST /api/game/attempts` ผ่าน `net-sim-3d/scripts/core/server_sync.gd` (autoload `ServerSync`)
  คะแนนคิดในเกมเหมือนเดิม API ตรวจแค่ว่าตัวเลขรวมกันถูกต้อง และบันทึกเข้าคลาสที่นักเรียนเลือกอยู่
- เน็ตหลุด: ผลรอในเครื่อง (`pending_attempts.json`) แล้วส่งใหม่ทุก 60 วินาทีและตอนเปิดเกม ส่งซ้ำก็บันทึกครั้งเดียว
  และส่งเฉพาะตอนที่นักเรียนคนเดิมล็อกอินอยู่ (เครื่องในห้องแล็บใช้ร่วมกันได้)
- เปิดเกม: ความคืบหน้า ดาว และการปลดล็อกด่านมาจากเซิร์ฟเวอร์ของนักเรียนคนนั้น ถ้าเปลี่ยนคนเล่นบนเครื่องเดิม ข้อมูลในเครื่องของคนก่อนจะถูกล้าง
- มุมซ้ายบนของเมนูเกมบอกว่าใครล็อกอินอยู่และอยู่คลาสไหน ถ้ายังไม่ล็อกอินจะเตือนว่าคะแนนไม่ถึงครู
- ครู: หน้าคลาส แท็บ "คะแนนเกม" ดูภาพรวม 6 ด่าน, รายด่าน (ใครยังไม่เล่น ผ่าน/ไม่ผ่าน ครั้งแรก/ดีที่สุด/ล่าสุด), ประวัติทุกครั้งพร้อมเวลาแต่ละขั้นและจุดที่ผิด
- CSV 3 แบบ (`GET /api/classes/:id/export.csv?type=summary|attempts|steps&level=&from=&to=&lang=th|en`): สรุปรายคน, Log รายครั้ง, Log รายขั้น
  รหัสนักศึกษาเขียนเป็นข้อความ Excel จึงไม่แสดงเป็น 6.8E+12 และข้อความที่ขึ้นต้นด้วย `=` `+` `-` `@` ถูกกันไม่ให้ทำงานเป็นสูตร

ทดสอบเกมกับเว็บจริง (เปิดเว็บด้วย Docker และ `DEV_LOGIN=true` ก่อน):

```powershell
godot --headless --path ../net-sim-3d -s res://tools/check_server_sync.gd -- http://localhost:8080
```

## Net-Desktop ใต้ `/sim/`

หน้าเว็บของ Net-Desktop เรียก `/api/...` จากหน้าแรกสุดของเว็บ ซึ่งจะชนกับ API กลาง
ตอนนี้ `sim/patch-paths.sh` เปลี่ยนเป็น `api/...` ให้อัตโนมัติตอน build โดยไม่แตะรีโปของเพื่อน
เมื่อ Net-Desktop เปลี่ยนเป็น path แบบนี้เองแล้ว ลบ `patch-paths.sh` และสองบรรทัดที่เรียกใช้ใน `sim/Dockerfile` ได้เลย

Net-Desktop ยังใช้ล็อกอินและฐานข้อมูลของตัวเองอยู่ (ไฟล์ SQLite ใน volume `simdata`) จะเชื่อมเข้าระบบกลางในระยะ 6

## โครงสร้าง

```
api/
  migrations/      ตารางฐานข้อมูล (รันอัตโนมัติตอนเปิด API)
  src/server.ts    จุดเริ่ม: ต่อฐานข้อมูล, migrate, รายชื่อครู, เปิดพอร์ต
  src/app.ts       Express app
  src/auth.ts      session, ตรวจบทบาท
  src/routes/      me.ts (ล็อกอิน บทบาท ข้อมูลนักเรียน), classes.ts (คลาส)
  test/            ชุดทดสอบ (node:test + supertest)
web/
  src/pages/       หน้าต่าง ๆ: Landing, Login, ChooseRole, Profile, StudentLobby, TeacherLobby, ClassPage
  src/i18n.tsx     ข้อความไทย/อังกฤษทั้งหมด
  src/styles.css   หน้าตา (ฟอนต์ Mitr และภาพพื้นหลังจากเกม)
nginx/             ด่านหน้า: แบ่งเส้นทาง / /api/ /sim/ /game/
sim/               Dockerfile ของ Net-Desktop
scripts/           export-game.mjs
```
