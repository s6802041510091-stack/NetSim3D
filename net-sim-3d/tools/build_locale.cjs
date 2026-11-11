const fs=require('fs');
const path=require('path');
const source=require('./locale-source.json');
const english=Object.assign({}, ...[0,1,2,3].map(n=>require('./locale-en-'+n+'.json')));
const missing=source.filter(x=>english[x.id]===undefined);
if(missing.length) throw Error('Missing translations: '+missing.map(x=>x.id));
const catalog=Object.fromEntries(source.map(x=>[x.th,english[x.id]]));
Object.assign(catalog, {
  'ค้นหา':'Search',
  'ค้นหาโปรแกรม':'Search apps',
  'กำลังโหลด . . . %d%%':'Is Loading . . . %d%%',
  'วิธีควบคุม':'Controls',
  'พร้อมสำรวจโรงเรียนแล้ว':'Ready to explore the school',
  'เดิน':'Move',
  'มองรอบตัว':'Look around',
  'วิ่ง':'Run',
  'โต้ตอบ / ใช้อุปกรณ์ / เปิดประตู':'Interact / Use equipment / Open doors',
  'เปิด–ปิดกระเป๋า':'Open / Close inventory',
  'เปิดเมนูพัก / ตั้งค่า':'Pause menu / Settings',
  'แสดงเมาส์':'Show cursor',
  'เข้าใจแล้ว เริ่มเล่น':'Got it — Play',
  'เลือกอุปกรณ์เครือข่าย':'Choose Devices',
  'ตรวจเครือข่ายด้วย ping':'Ping Test',
  'เปลี่ยนการ์ดเครือข่าย':'Replace the NIC',
  'ป้องกันภัยคอมพิวเตอร์':'Firewall & Antivirus',
  'ช่วยเหลือระยะไกล':'Remote Help',
  'กำลังพัฒนา':'In development',
  'ผ่านด่านก่อนหน้าเพื่อปลดล็อก':'Complete the previous level to unlock',
  'พักเกม / ด่าน %d':'Paused / Level %d',
  'เล่นต่อ':'Resume', 'ตั้งค่า':'Settings', 'เริ่มด่าน':'Start',
  'กลับล็อบบี้':'Exit to Lobby',
  'คลิก หรือกด F / Space เพื่อจบบทสนทนา':'Click or press F / Space to end the conversation',
  'ผู้เล่น':'You', 'คุณ':'You', 'ครูสาว':'Teacher',
  '[F] ปิดประตู%s':'[F] Close door%s', '[F] เปิดประตู%s':'[F] Open door%s',
  'คอก %d':'Cubicle %d',
  'กรุณาล้างมือทุกครั้ง':'Please wash your hands',
  'ห้องเก็บอุปกรณ์ทำความสะอาด':'Cleaning supplies',
  'ใช่':'Yes', 'ไม่ใช่':'No', 'แล้ว':'Done', 'ยัง':'Not yet'
});
fs.mkdirSync(path.join(__dirname,'../localization'),{recursive:true});
fs.writeFileSync(path.join(__dirname,'../localization/en.json'),JSON.stringify(catalog,null,2)+'\n');
console.log('CATALOG_OK '+Object.keys(catalog).length+' messages');
