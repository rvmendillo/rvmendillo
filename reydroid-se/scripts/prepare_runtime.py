#!/usr/bin/env python3
"""Fetch pinned upstream runtime and guest seeds; never use the JIT variant."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import struct
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = Path(os.environ.get('RD_CACHE', str(ROOT / '.downloads')))
CACHE.mkdir(parents=True, exist_ok=True)
UTM_URL = 'https://github.com/utmapp/UTM/releases/download/v4.7.5/UTM-SE.ipa'
UTM_HASH = 'ccb8529b8b8781410ff481e4ffbdf0d1b47ce5d431031e782e4b6f9601cac06d'
GUEST_URL = 'https://github.com/jqssun/android-lineage-qemu/releases/download/v2026.09.17/UTM-VM-lineage-23.2-20260917-jqssun-virtio_arm64only.zip'
GUEST_HASH = '0a50afc821d905848b4560c33a5a706e6aee5ac414f85b31f9e52fc1ffabbd61'

def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def fetch(name, url, expected):
    path = CACHE / name
    if not path.exists() or digest(path) != expected:
        partial = path.with_suffix('.part')
        print('Downloading', name, flush=True)
        with urllib.request.urlopen(url, timeout=120) as response, partial.open('wb') as out:
            shutil.copyfileobj(response, out, 4 << 20)
        if digest(partial) != expected:
            partial.unlink()
            raise RuntimeError('SHA-256 mismatch for ' + name)
        partial.replace(path)
    print('Verified', name, flush=True)
    return path

def macho(data):
    if struct.unpack_from('<I', data)[0] != 0xfeedfacf:
        raise RuntimeError('Expected a thin 64-bit Mach-O')
    if struct.unpack_from('<I', data, 4)[0] != 0x100000c:
        raise RuntimeError('Expected ARM64')
    count = struct.unpack_from('<I', data, 16)[0]
    offset = 32
    dependencies, symbols = [], set()
    for _ in range(count):
        command, size = struct.unpack_from('<II', data, offset)
        if command in (0xc, 0x80000018, 0x8000001f):
            nameoffset = struct.unpack_from('<I', data, offset + 8)[0]
            dependencies.append(data[offset + nameoffset:offset + size].split(b'\0')[0].decode())
        elif command == 2:
            symoff, nsyms, stroff, strsize = struct.unpack_from('<4I', data, offset + 8)
            strings = data[stroff:stroff + strsize]
            for index in range(nsyms):
                name, typ, section, desc, value = struct.unpack_from('<IBBHQ', data, symoff + index * 16)
                symbols.add(strings[name:strings.find(b'\0', name)].decode(errors='replace'))
        offset += size
    return dependencies, symbols

def prepare():
    ipa = fetch('UTM-SE.ipa', UTM_URL, UTM_HASH)
    guest = fetch('android-template.zip', GUEST_URL, GUEST_HASH)
    frameworks = ROOT / 'Runtime'
    resources = ROOT / 'App' / 'Resources'
    frameworks.mkdir(exist_ok=True)
    (resources / 'qemu').mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ipa) as archive:
        prefix = 'Payload/UTM SE.app/Frameworks/'
        needed = ['qemu-aarch64-softmmu.framework/qemu-aarch64-softmmu']
        included = set()
        while needed:
            relative = needed.pop()
            if relative in included:
                continue
            data = archive.read(prefix + relative)
            dependencies, symbols = macho(data)
            if relative.startswith('qemu-'):
                required = {'_qemu_init', '_qemu_main_loop', '_qemu_cleanup', '_tcg_qemu_tb_exec', '_tcti_call_return_address'}
                assert required <= symbols, 'The pinned runtime lacks its interpreter or VM entrypoints'
            folder = relative.split('/')[0]
            for member in archive.namelist():
                if member.startswith(prefix + folder + '/') and not member.endswith('/'):
                    name = member[len(prefix):]
                    assert '..' not in Path(name).parts
                    dest = frameworks / name
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(archive.read(member))
            included.add(relative)
            needed.extend(d[len('@rpath/'):] for d in dependencies if d.startswith('@rpath/'))
        # The software display uses no graphics translation layer. The dependency
        # closure above still includes the linked virgl library, as required by dyld.
        for member in archive.namelist():
            if member.startswith('Payload/UTM SE.app/qemu/') and member.endswith(('edk2-aarch64-code.fd', 'edk2-licenses.txt')):
                (resources / 'qemu' / Path(member).name).write_bytes(archive.read(member))
        (resources / 'ThirdPartyLicenses.plist').write_bytes(archive.read('Payload/UTM SE.app/Settings.bundle/License.plist'))
    with zipfile.ZipFile(guest) as archive:
        for original, name in [('vdb.qcow2', 'userdata-seed.qcow2'), ('efi_vars.fd', 'efi-vars-seed.fd')]:
            data = archive.read('LineageOS_on_arm64.utm/Data/' + original)
            assert data[:4] == b'QFI\xfb', 'Guest seed must be QCOW2'
            (resources / name).write_bytes(data)
    info = {'engine': 'UTM SE v4.7.5 ARM64 TCTI', 'engine_sha256': UTM_HASH,
            'jit_required': False, 'frameworks': sorted(included),
            'guest_template_sha256': GUEST_HASH}
    (resources / 'RuntimeProvenance.json').write_text(json.dumps(info, indent=2) + '\n')
    # XcodeGen includes the complete transitive dependency closure for signing.
    dependencies = '\n'.join('      - framework: Runtime/' + p.split('/')[0] + '\n        embed: true\n        link: false\n        codeSign: true' for p in sorted(included))
    (ROOT / 'project.yml').write_text((ROOT / 'project.template.yml').read_text().replace('# RUNTIME_DEPENDENCIES', dependencies))
    print('Prepared', len(included), 'frameworks, firmware, and both guest seeds.', flush=True)

if __name__ == '__main__':
    prepare()
