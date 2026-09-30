#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import struct
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
app = root / 'build/Build/Products/Release-iphoneos/ReyDroidSE.app'
destination = Path(sys.argv[1]).resolve()
destination.mkdir(parents=True, exist_ok=True)
assert app.is_dir(), 'Built app missing'
info = plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.rvmendillo.reydroidse'
assert info['CFBundleExecutable'] == 'ReyDroidSE'
executable = (app/'ReyDroidSE').read_bytes()
assert executable[:4] == b'\xcf\xfa\xed\xfe', 'Missing ARM64 Mach-O executable'
assert struct.unpack_from('<I', executable, 4)[0] == 0x100000c
provenance = json.loads((app/'RuntimeProvenance.json').read_text())
assert provenance['jit_required'] is False
for path in provenance['frameworks']:
    assert (app/'Frameworks'/path).is_file(), 'Missing embedded runtime: '+path
for seed in ['userdata-seed.qcow2', 'efi-vars-seed.fd']:
    assert (app/seed).read_bytes()[:4] == b'QFI\xfb'
assert (app/'qemu/edk2-aarch64-code.fd').stat().st_size == 67108864
assert not list(root.glob('App/*.entitlements')), 'This build should not request JIT/development entitlements'

source_zip = destination/'ReyDroid-SE-source.zip'
paths = ['App', 'Tests', 'scripts', 'project.template.yml', 'README.md', 'LICENSE', '.gitignore']
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for name in paths:
        p = root/name
        for f in sorted(p.rglob('*')) if p.is_dir() else [p]:
            relative = f.relative_to(root)
            if f.is_file() and not any(s in str(relative) for s in ['App/Resources/', 'Assets.xcassets/', '__pycache__']):
                archive.write(f, 'ReyDroidSE/'+str(relative))
shutil.copyfile(source_zip, app/'ReyDroid-SE-source.zip')
shutil.copyfile(root/'LICENSE', app/'LICENSE')
ipa = destination/'ReyDroid-SE-unsigned.ipa'
with zipfile.ZipFile(ipa, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for f in sorted(app.rglob('*')):
        if f.is_file(): archive.write(f, 'Payload/ReyDroidSE.app/'+str(f.relative_to(app)))
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
report = {'name': ipa.name, 'size': ipa.stat().st_size,
          'sha256': hashlib.file_digest(ipa.open('rb'), 'sha256').hexdigest(),
          'runtime': provenance['engine'], 'jit_required': False,
          'signing': 'unsigned; normal sideload signing needed',
          'device_boot_test': 'NOT PERFORMED', 'frameworks': len(provenance['frameworks']),
          'checks': ['ARM64 executable', 'interpreter provenance', 'dependency closure', 'both guest disk seeds', 'UEFI firmware', 'archive integrity']}
(destination/'ReyDroid-SE-build-report.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
