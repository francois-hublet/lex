import os
from pathlib import Path
# Enforcement

ROOT_DIR = Path(__file__).resolve().parents[1]

_default_exe = ROOT_DIR / 'enfguard' / 'bin' / 'enfguard.exe'
if not _default_exe.exists():
	_linux_exe = ROOT_DIR / 'enfguard' / 'bin' / 'enfguard'
	if _linux_exe.exists():
		_default_exe = _linux_exe

INSTRLIB_EXE = os.environ.get('INSTRLIB_EXE', str(_default_exe))
# Extra enforcer options passed by instrlib (latest Enfflash needs -fix-since).
os.environ.setdefault('INSTRLIB_EXTRA_ARGS', '-fix-since')
INSTRLIB_FORMULA = os.environ.get('INSTRLIB_FORMULA', str(ROOT_DIR / 'gdprfs' / 'policies' / 'gdprfs.mfotl'))
# INSTRLIB_FORMULA = os.environ.get('INSTRLIB_FORMULA', str(ROOT_DIR / 'gdprfs' / 'policies' / 'session.mfotl'))
INSTRLIB_SIG = os.environ.get('INSTRLIB_SIG', str(ROOT_DIR / 'gdprfs' / 'policies' / 'gdprfs.sig'))
# INSTRLIB_SIG = os.environ.get('INSTRLIB_SIG', str(ROOT_DIR / 'gdprfs' / 'policies' / 'gdpr_draft.sig'))
INSTRLIB_LOG = os.environ.get('INSTRLIB_LOG', str(ROOT_DIR / 'gdprfs' / 'gdprfstrace.log'))

