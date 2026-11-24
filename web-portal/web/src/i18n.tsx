import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { ApiError } from './api';

export type Lang = 'th' | 'en';

const th = {
  'app.sub': 'SCHOOL NETWORK LAB',
  'app.tagline': 'เรียนรู้เครือข่ายคอมพิวเตอร์ผ่านการจำลองและภารกิจในโรงเรียน',

  'landing.forWho': 'สำหรับนักเรียนชั้น ปวช.3',
  'landing.login': 'เข้าสู่ระบบ',
  'landing.continue': 'ไปที่ห้องเรียนของฉัน',
  'landing.simTitle': 'Simulation',
  'landing.simText': 'ต่ออุปกรณ์ ตั้งค่า IP และทดสอบเครือข่าย ใช้ประกอบการสอนและวัดผล',
  'landing.gameTitle': 'เกม NetSim3D',
  'landing.gameText': 'ภารกิจ 6 ด่านในโรงเรียน ใช้วัดผลการเรียน',
  'landing.privacy': 'ระบบเก็บชื่อ-นามสกุล รหัสนักศึกษา อีเมล และผลการเรียน เพื่อใช้วัดผลการเรียนในรายวิชาเท่านั้น',

  'nav.logout': 'ออกจากระบบ',
  'nav.profile': 'ข้อมูลของฉัน',
  'nav.home': 'หน้าแรก',
  'lang.switch': 'English',
  'lang.label': 'เปลี่ยนภาษา',
  'role.teacher': 'ครู',
  'role.student': 'นักเรียน',

  'login.title': 'เข้าสู่ระบบ',
  'login.google': 'เข้าสู่ระบบด้วย Google',
  'login.googleSoon': 'เปิดใช้เมื่อติดตั้งบนเซิร์ฟเวอร์จริง',
  'login.or': 'หรือ',
  'login.devBadge': 'โหมดทดสอบ',
  'login.devNote': 'ใช้ตอนพัฒนาเท่านั้น พิมพ์อีเมลใดก็เข้าได้ บนเซิร์ฟเวอร์จริงส่วนนี้จะถูกปิด',
  'login.email': 'อีเมล',
  'login.name': 'ชื่อที่แสดง (ไม่บังคับ)',
  'login.submit': 'เข้าสู่ระบบทดสอบ',
  'login.unavailable': 'ตอนนี้ยังเข้าสู่ระบบไม่ได้ ติดต่อผู้ดูแลระบบ',

  'role.title': 'คุณใช้งานในฐานะอะไร',
  'role.once': 'เลือกได้ครั้งเดียว ถ้าเลือกผิดให้ติดต่อผู้ดูแลระบบ',
  'role.studentText': 'เข้าคลาส เรียนกับ Simulation และทำภารกิจในเกม',
  'role.teacherText': 'สร้างคลาส ดูรายชื่อนักเรียน และติดตามผลการเรียน',
  'role.teacherLocked': 'อีเมลนี้ไม่อยู่ในรายชื่อครูที่ได้รับอนุญาต',
  'role.choose': 'เลือก',

  'profile.title': 'ข้อมูลนักเรียน',
  'profile.intro': 'กรอกครั้งเดียว ครูจะเห็นข้อมูลนี้ในรายชื่อคลาสและไฟล์คะแนน',
  'profile.first': 'ชื่อ',
  'profile.last': 'นามสกุล',
  'profile.studentId': 'รหัสนักศึกษา',
  'profile.idHint': 'ตัวเลข 13 หลัก เช่น 6800000000000',
  'profile.idInvalid': 'รหัสนักศึกษาต้องเป็นตัวเลข 13 หลัก',
  'profile.email': 'อีเมล (จากบัญชีที่เข้าสู่ระบบ)',
  'profile.save': 'บันทึก',
  'profile.saved': 'บันทึกแล้ว',

  'lobby.hello': 'สวัสดี {name}',
  'lobby.activeClass': 'คลาสที่กำลังเรียน',
  'lobby.noClass': 'ยังไม่ได้เข้าคลาส',
  'lobby.needClass': 'เข้าคลาสก่อน แล้วจึงเริ่มเรียนได้',
  'lobby.simTitle': 'Simulation',
  'lobby.simText': 'เรียนบทเรียน ต่อเครือข่าย และทำภารกิจฝึก',
  'lobby.gameTitle': 'เกม NetSim3D',
  'lobby.gameText': 'ภารกิจวัดผล 6 ด่านในโรงเรียน',
  'lobby.open': 'เข้าใช้งาน',
  'lobby.joinTitle': 'เข้าคลาส',
  'lobby.joinIntro': 'ใช้ Class ID และรหัสผ่านคลาสที่ครูให้',
  'lobby.code': 'Class ID',
  'lobby.password': 'รหัสผ่านคลาส',
  'lobby.join': 'เข้าคลาส',
  'lobby.joined': 'เข้าคลาส {name} แล้ว',
  'lobby.already': 'คุณอยู่ในคลาส {name} อยู่แล้ว',
  'lobby.myClasses': 'คลาสของฉัน',
  'lobby.teacherBy': 'ครู {name}',
  'lobby.joinedAt': 'เข้าเมื่อ {date}',
  'lobby.use': 'ใช้คลาสนี้',
  'lobby.inUse': 'กำลังใช้',
  'lobby.noClasses': 'ยังไม่มีคลาส เข้าคลาสด้วย Class ID ที่ครูให้',

  'teacher.createTitle': 'สร้างคลาส',
  'teacher.className': 'ชื่อคลาส',
  'teacher.classNamePh': 'เช่น ปวช.3/1 เครือข่ายคอมพิวเตอร์',
  'teacher.classPassword': 'รหัสผ่านคลาส (อย่างน้อย 4 ตัว)',
  'teacher.create': 'สร้างคลาส',
  'teacher.created': 'สร้างคลาสแล้ว ให้นักเรียนใช้ Class ID {code} กับรหัสผ่านที่ตั้งไว้',
  'teacher.classes': 'คลาสของฉัน',
  'teacher.noClasses': 'ยังไม่มีคลาส เริ่มจากสร้างคลาสแรก',
  'teacher.members': 'นักเรียน {n} คน',
  'teacher.open': 'รับสมาชิก',
  'teacher.closed': 'ปิดรับสมาชิก',
  'teacher.deleted': 'คลาสที่ลบแล้ว',
  'teacher.restore': 'กู้คืน',
  'teacher.tools': 'เครื่องมือครู',
  'teacher.simTeacher': 'หน้าครู Simulation',
  'teacher.simTeacherText': 'ผลก่อน–หลังเรียน ภารกิจ และ CSV ของ Simulation',
  'teacher.tryGame': 'ทดลองเล่นเกม',
  'teacher.tryGameText': 'เปิดเกม NetSim3D แบบเดียวกับที่นักเรียนเห็น',
  'teacher.gameDash': 'คะแนนเกมและ CSV',
  'teacher.soon': 'เร็ว ๆ นี้',

  'class.back': 'กลับห้องเรียน',
  'class.share': 'ให้นักเรียนกรอก Class ID นี้กับรหัสผ่านคลาสในหน้าห้องเรียน',
  'class.copy': 'คัดลอก',
  'class.copied': 'คัดลอกแล้ว',
  'class.settings': 'ตั้งค่าคลาส',
  'class.name': 'ชื่อคลาส',
  'class.saveName': 'บันทึกชื่อ',
  'class.nameSaved': 'บันทึกชื่อแล้ว',
  'class.newPassword': 'รหัสผ่านคลาสใหม่',
  'class.changePassword': 'เปลี่ยนรหัสผ่าน',
  'class.passwordChanged': 'เปลี่ยนรหัสผ่านแล้ว นักเรียนที่อยู่ในคลาสแล้วยังอยู่เหมือนเดิม',
  'class.openState': 'เปิดรับนักเรียนใหม่อยู่',
  'class.closedState': 'ปิดรับนักเรียนใหม่อยู่',
  'class.close': 'ปิดรับสมาชิก',
  'class.reopen': 'เปิดรับสมาชิก',
  'class.members': 'รายชื่อนักเรียน ({n} คน)',
  'class.noMembers': 'ยังไม่มีนักเรียนเข้าคลาส',
  'class.colStudentId': 'รหัสนักศึกษา',
  'class.colName': 'ชื่อ-นามสกุล',
  'class.colEmail': 'อีเมล',
  'class.colJoined': 'เข้าคลาสเมื่อ',
  'class.remove': 'นำออก',
  'class.removeTitle': 'นำนักเรียนออกจากคลาส',
  'class.removeText': 'นำ {name} ออกจากคลาสนี้? นักเรียนเข้าคลาสใหม่ได้ด้วย Class ID และรหัสผ่าน',
  'class.danger': 'ลบคลาส',
  'class.deleteText': 'นักเรียนจะไม่เห็นคลาสนี้ ข้อมูลและคะแนนยังเก็บไว้ และกู้คืนได้ภายหลัง',
  'class.delete': 'ลบคลาส',
  'class.deleteTitle': 'ลบคลาส {name}?',
  'class.deletedBanner': 'คลาสนี้ถูกลบแล้ว นักเรียนมองไม่เห็นคลาสนี้',

  'class.tabStudents': 'นักเรียนและตั้งค่า',
  'class.tabGame': 'คะแนนเกม',
  'teacher.gameDashText': 'ดูในหน้าคลาส แท็บคะแนนเกม',

  'game.levelAll': 'ทุกด่าน',
  'game.level': 'ด่าน {n}',
  'game.played': 'เล่นแล้ว {n}/{total} คน',
  'game.passedCount': 'ผ่าน {n} คน',
  'game.avgBest': 'คะแนนดีที่สุดเฉลี่ย {n}',
  'game.colStudent': 'นักเรียน',
  'game.colStatus': 'สถานะ',
  'game.colFirst': 'ครั้งแรก',
  'game.colBest': 'ดีที่สุด',
  'game.colLast': 'ล่าสุด',
  'game.colAttempts': 'จำนวนครั้ง',
  'game.colLastPlayed': 'เล่นล่าสุดเมื่อ',
  'game.notPlayed': 'ยังไม่เล่น',
  'game.pass': 'ผ่าน',
  'game.fail': 'ไม่ผ่าน',
  'game.former': 'ออกจากคลาสแล้ว',
  'game.hint': 'ตัวเลขคือคะแนนดีที่สุด (เต็ม 100) ผ่านที่ 50 คะแนน กดชื่อนักเรียนเพื่อดูทุกครั้งที่เล่น',
  'game.levelHint': 'กดชื่อนักเรียนเพื่อดูทุกครั้งที่เล่น เวลาแต่ละขั้น และจุดที่ผิด',
  'game.detailTitle': 'ประวัติการเล่นของ {name}',
  'game.attemptLine': 'ด่าน {level} · ครั้งที่ {n}',
  'game.parts': 'ความถูกต้อง {c}/30 · กระบวนการ {p}/50 · เวลา {t}/20',
  'game.timeTaken': 'ใช้เวลา {time}',
  'game.decisions': 'ตัดสินใจถูก {a}/{b}',
  'game.checks': 'กดตรวจ {n} ครั้ง',
  'game.steps': 'เวลาแต่ละขั้น',
  'game.mistakes': 'จุดที่ผิดพลาด',
  'game.noMistakes': 'ไม่มีจุดที่ผิด',
  'game.atSec': 'วินาทีที่ {s}',
  'game.atEnd': 'ตอนจบด่าน',
  'game.noAttempts': 'ยังไม่มีการเล่นในคลาสนี้',
  'game.close': 'ปิด',

  'csv.title': 'ดาวน์โหลด CSV',
  'csv.intro': 'เปิดด้วย Excel หรือ Google Sheets ได้ทันที',
  'csv.summary': 'สรุปรายคน',
  'csv.summaryText': 'คนละ 1 แถว: ครั้งแรก ดีที่สุด ล่าสุด และจำนวนครั้งของแต่ละด่าน',
  'csv.attempts': 'Log รายครั้ง',
  'csv.attemptsText': 'การเล่น 1 ครั้งต่อ 1 แถว พร้อมคะแนนทุกส่วนและจุดที่ผิด',
  'csv.steps': 'Log รายขั้น',
  'csv.stepsText': '1 แถวต่อ 1 ขั้นของแต่ละครั้ง: เวลาที่ใช้และจุดที่ผิดในขั้นนั้น',
  'csv.level': 'ด่าน',
  'csv.from': 'ตั้งแต่วันที่',
  'csv.to': 'ถึงวันที่',
  'csv.download': 'ดาวน์โหลด CSV',

  'common.cancel': 'ยกเลิก',
  'common.loading': 'กำลังโหลด…',
  'notFound.title': 'ไม่พบหน้านี้',

  'err.network': 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่อีกครั้ง',
  'err.invalid_input': 'ข้อมูลไม่ถูกต้อง ตรวจแล้วลองใหม่',
  'err.student_id_taken': 'รหัสนักศึกษานี้มีผู้ใช้แล้ว ถ้าเป็นของคุณให้แจ้งครู',
  'err.not_allowed_teacher': 'อีเมลนี้ไม่อยู่ในรายชื่อครูที่ได้รับอนุญาต',
  'err.role_already_set': 'เลือกบทบาทไปแล้ว',
  'err.class_not_found': 'ไม่พบคลาสที่มี Class ID นี้',
  'err.wrong_password': 'รหัสผ่านคลาสไม่ถูกต้อง',
  'err.class_closed': 'คลาสนี้ปิดรับนักเรียนใหม่แล้ว',
  'err.too_many_attempts': 'ลองผิดหลายครั้งเกินไป รอ {min} นาทีแล้วลองใหม่',
  'err.profile_required': 'กรอกข้อมูลนักเรียนให้ครบก่อน',
  'err.teacher_only': 'ส่วนนี้สำหรับครู',
  'err.student_only': 'ส่วนนี้สำหรับนักเรียน',
  'err.not_logged_in': 'กรุณาเข้าสู่ระบบอีกครั้ง',
  'err.class_deleted': 'คลาสนี้ถูกลบแล้ว',
  'err.generic': 'เกิดข้อผิดพลาด ลองใหม่อีกครั้ง',
};

export type Key = keyof typeof th;

const en: Record<Key, string> = {
  'app.sub': 'SCHOOL NETWORK LAB',
  'app.tagline': 'Learn computer networking through simulation and school missions',

  'landing.forWho': 'For vocational certificate year 3 students',
  'landing.login': 'Log in',
  'landing.continue': 'Go to my classroom',
  'landing.simTitle': 'Simulation',
  'landing.simText': 'Connect devices, set IP addresses and test networks, for lessons and assessment',
  'landing.gameTitle': 'NetSim3D game',
  'landing.gameText': 'Six missions around the school, used for assessment',
  'landing.privacy': 'We keep your name, student ID, email and results only to assess your learning in this course.',

  'nav.logout': 'Log out',
  'nav.profile': 'My details',
  'nav.home': 'Home',
  'lang.switch': 'ไทย',
  'lang.label': 'Change language',
  'role.teacher': 'Teacher',
  'role.student': 'Student',

  'login.title': 'Log in',
  'login.google': 'Sign in with Google',
  'login.googleSoon': 'Available once the site is on the real server',
  'login.or': 'or',
  'login.devBadge': 'Test mode',
  'login.devNote': 'For development only: any email can log in. This is turned off on the real server.',
  'login.email': 'Email',
  'login.name': 'Display name (optional)',
  'login.submit': 'Test log in',
  'login.unavailable': 'Logging in is not available yet. Contact the administrator.',

  'role.title': 'How will you use NetSim?',
  'role.once': 'You can choose only once. Contact the administrator if you pick the wrong one.',
  'role.studentText': 'Join classes, learn with the Simulation and play the game missions',
  'role.teacherText': 'Create classes, see your students and follow their results',
  'role.teacherLocked': 'This email is not on the list of approved teachers',
  'role.choose': 'Choose',

  'profile.title': 'Student details',
  'profile.intro': 'Fill this in once. Your teacher sees it in the class list and score files.',
  'profile.first': 'First name',
  'profile.last': 'Last name',
  'profile.studentId': 'Student ID',
  'profile.idHint': '13 digits, e.g. 6800000000000',
  'profile.idInvalid': 'The student ID must be 13 digits',
  'profile.email': 'Email (from the account you logged in with)',
  'profile.save': 'Save',
  'profile.saved': 'Saved',

  'lobby.hello': 'Hi {name}',
  'lobby.activeClass': 'Current class',
  'lobby.noClass': 'Not in a class yet',
  'lobby.needClass': 'Join a class to start learning',
  'lobby.simTitle': 'Simulation',
  'lobby.simText': 'Lessons, network building and practice missions',
  'lobby.gameTitle': 'NetSim3D game',
  'lobby.gameText': 'Six assessment missions around the school',
  'lobby.open': 'Open',
  'lobby.joinTitle': 'Join a class',
  'lobby.joinIntro': 'Use the Class ID and class password from your teacher',
  'lobby.code': 'Class ID',
  'lobby.password': 'Class password',
  'lobby.join': 'Join',
  'lobby.joined': 'You joined {name}',
  'lobby.already': 'You are already in {name}',
  'lobby.myClasses': 'My classes',
  'lobby.teacherBy': 'Teacher: {name}',
  'lobby.joinedAt': 'Joined {date}',
  'lobby.use': 'Use this class',
  'lobby.inUse': 'In use',
  'lobby.noClasses': 'No classes yet. Join one with the Class ID from your teacher.',

  'teacher.createTitle': 'Create a class',
  'teacher.className': 'Class name',
  'teacher.classNamePh': 'e.g. Year 3/1 Computer Networks',
  'teacher.classPassword': 'Class password (at least 4 characters)',
  'teacher.create': 'Create class',
  'teacher.created': 'Class created. Students join with Class ID {code} and the password you set.',
  'teacher.classes': 'My classes',
  'teacher.noClasses': 'No classes yet. Start by creating your first one.',
  'teacher.members': '{n} students',
  'teacher.open': 'Open',
  'teacher.closed': 'Closed',
  'teacher.deleted': 'Deleted classes',
  'teacher.restore': 'Restore',
  'teacher.tools': 'Teacher tools',
  'teacher.simTeacher': 'Simulation teacher page',
  'teacher.simTeacherText': 'Pre/post tests, missions and CSV from the Simulation',
  'teacher.tryGame': 'Try the game',
  'teacher.tryGameText': 'Open NetSim3D the way students see it',
  'teacher.gameDash': 'Game scores and CSV',
  'teacher.soon': 'Coming soon',

  'class.back': 'Back to classroom',
  'class.share': 'Students enter this Class ID and the class password on their classroom page',
  'class.copy': 'Copy',
  'class.copied': 'Copied',
  'class.settings': 'Class settings',
  'class.name': 'Class name',
  'class.saveName': 'Save name',
  'class.nameSaved': 'Name saved',
  'class.newPassword': 'New class password',
  'class.changePassword': 'Change password',
  'class.passwordChanged': 'Password changed. Students already in the class stay in it.',
  'class.openState': 'Accepting new students',
  'class.closedState': 'Not accepting new students',
  'class.close': 'Close to new students',
  'class.reopen': 'Reopen',
  'class.members': 'Students ({n})',
  'class.noMembers': 'No students have joined yet',
  'class.colStudentId': 'Student ID',
  'class.colName': 'Name',
  'class.colEmail': 'Email',
  'class.colJoined': 'Joined',
  'class.remove': 'Remove',
  'class.removeTitle': 'Remove student from class',
  'class.removeText': 'Remove {name} from this class? They can join again with the Class ID and password.',
  'class.danger': 'Delete class',
  'class.deleteText': 'Students will no longer see this class. Its data and scores are kept and you can restore it later.',
  'class.delete': 'Delete class',
  'class.deleteTitle': 'Delete {name}?',
  'class.deletedBanner': 'This class is deleted. Students cannot see it.',

  'class.tabStudents': 'Students & settings',
  'class.tabGame': 'Game scores',
  'teacher.gameDashText': 'On each class page, Game scores tab',

  'game.levelAll': 'All levels',
  'game.level': 'Level {n}',
  'game.played': '{n} of {total} played',
  'game.passedCount': '{n} passed',
  'game.avgBest': 'Average best score {n}',
  'game.colStudent': 'Student',
  'game.colStatus': 'Status',
  'game.colFirst': 'First',
  'game.colBest': 'Best',
  'game.colLast': 'Latest',
  'game.colAttempts': 'Attempts',
  'game.colLastPlayed': 'Last played',
  'game.notPlayed': 'Not played',
  'game.pass': 'Passed',
  'game.fail': 'Not passed',
  'game.former': 'Left the class',
  'game.hint': 'Numbers are best scores (out of 100); 50 passes. Click a student to see every attempt.',
  'game.levelHint': 'Click a student to see every attempt, the time per step and the mistakes.',
  'game.detailTitle': '{name}: every attempt',
  'game.attemptLine': 'Level {level} · attempt {n}',
  'game.parts': 'Correctness {c}/30 · Process {p}/50 · Time {t}/20',
  'game.timeTaken': 'Took {time}',
  'game.decisions': 'Right decisions {a}/{b}',
  'game.checks': 'Checked {n} times',
  'game.steps': 'Time per step',
  'game.mistakes': 'What went wrong',
  'game.noMistakes': 'No mistakes',
  'game.atSec': 'at {s} s',
  'game.atEnd': 'at the end',
  'game.noAttempts': 'Nobody in this class has played yet',
  'game.close': 'Close',

  'csv.title': 'Download CSV',
  'csv.intro': 'Opens directly in Excel or Google Sheets',
  'csv.summary': 'Summary per student',
  'csv.summaryText': 'One row per student: first, best and latest score and attempts for each level',
  'csv.attempts': 'Log per attempt',
  'csv.attemptsText': 'One row per attempt with every score part and the mistakes',
  'csv.steps': 'Log per step',
  'csv.stepsText': 'One row per step of each attempt: time taken and mistakes in that step',
  'csv.level': 'Level',
  'csv.from': 'From',
  'csv.to': 'To',
  'csv.download': 'Download CSV',

  'common.cancel': 'Cancel',
  'common.loading': 'Loading…',
  'notFound.title': 'Page not found',

  'err.network': 'Cannot reach the server. Please try again.',
  'err.invalid_input': 'Some details are not valid. Check them and try again.',
  'err.student_id_taken': 'This student ID is already in use. If it is yours, tell your teacher.',
  'err.not_allowed_teacher': 'This email is not on the list of approved teachers',
  'err.role_already_set': 'Your role is already chosen',
  'err.class_not_found': 'No class has this Class ID',
  'err.wrong_password': 'The class password is wrong',
  'err.class_closed': 'This class is not accepting new students',
  'err.too_many_attempts': 'Too many wrong tries. Wait {min} minutes and try again.',
  'err.profile_required': 'Fill in your student details first',
  'err.teacher_only': 'This part is for teachers',
  'err.student_only': 'This part is for students',
  'err.not_logged_in': 'Please log in again',
  'err.class_deleted': 'This class has been deleted',
  'err.generic': 'Something went wrong. Please try again.',
};

const dictionaries: Record<Lang, Record<Key, string>> = { th, en };

type Vars = Record<string, string | number>;
type I18n = { lang: Lang; setLang: (l: Lang) => void; t: (key: Key, vars?: Vars) => string; errorText: (err: unknown) => string };

const I18nContext = createContext<I18n | null>(null);
const STORAGE_KEY = 'netsim.lang';

function savedLang(): Lang {
  try {
    const v = localStorage.getItem(STORAGE_KEY);
    if (v === 'th' || v === 'en') return v;
  } catch {
    // storage blocked: fall back to Thai
  }
  return 'th';
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLang] = useState<Lang>(savedLang);

  useEffect(() => {
    document.documentElement.lang = lang;
    try {
      localStorage.setItem(STORAGE_KEY, lang);
    } catch {
      // storage blocked: the choice lasts for this visit only
    }
  }, [lang]);

  const t = useCallback((key: Key, vars?: Vars) => {
    let s = dictionaries[lang][key] ?? th[key] ?? key;
    if (vars) for (const [k, v] of Object.entries(vars)) s = s.replaceAll(`{${k}}`, String(v));
    return s;
  }, [lang]);

  const errorText = useCallback((err: unknown) => {
    if (err instanceof ApiError) {
      const key = `err.${err.code}` as Key;
      if (key in th) {
        const retry = (err.details as { retryAfterSec?: number } | undefined)?.retryAfterSec;
        return t(key, { min: Math.max(1, Math.ceil((retry ?? 60) / 60)) });
      }
    }
    return t('err.generic');
  }, [t]);

  const value = useMemo(() => ({ lang, setLang, t, errorText }), [lang, t, errorText]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18n {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error('useI18n outside I18nProvider');
  return ctx;
}

export function formatDate(iso: string, lang: Lang): string {
  return new Intl.DateTimeFormat(lang === 'th' ? 'th-TH' : 'en-GB', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(iso));
}
