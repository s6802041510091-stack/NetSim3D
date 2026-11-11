"""Fit the front bob tips approximately 3 cm above the actual brow mesh."""
import runpy,shutil
from pathlib import Path
ROOT=Path('D:/NetSim3D')
MAIN=ROOT/'3Dmodel/ใช้ร่วมกัน/blend/students/student_female_bob_cut.blend'
BACK=ROOT/'tmp/student_bob_before_brow_clearance_20261110.blend'
if not BACK.exists():shutil.copy2(MAIN,BACK)
runpy.run_path(str(ROOT/'3Dmodel/scripts/refine_student_bob_strands.py'),init_globals={
 'SOURCE_SNAPSHOT':str(BACK),'BROW_CLEARANCE_METERS':.030,
 'PREVIEW_PREFIX':'bob_brow_clearance','CANDIDATE_NAME':'student_bob_brow_clearance_candidate.blend',
})
