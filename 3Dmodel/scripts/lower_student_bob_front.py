"""Lengthen the detailed bob's central front locks 1.5x, with a temple blend."""
import runpy,shutil
from pathlib import Path
ROOT=Path('D:/NetSim3D')
MAIN=ROOT/'3Dmodel/ใช้ร่วมกัน/blend/students/student_female_bob_cut.blend'
BACK=ROOT/'tmp/student_bob_before_lower_front_20261109.blend'
if not BACK.exists():shutil.copy2(MAIN,BACK)
runpy.run_path(str(ROOT/'3Dmodel/scripts/refine_student_bob_strands.py'),init_globals={
    'SOURCE_SNAPSHOT':str(BACK),
    'FRONT_LENGTH_FACTOR':1.5,
    'PREVIEW_PREFIX':'bob_lower_front',
    'CANDIDATE_NAME':'student_bob_lower_front_candidate.blend',
})
print('LOWER_FRONT_READY: central crown-to-tip drop 30 mm -> 45 mm; temples blended',flush=True)
