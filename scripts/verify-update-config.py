"""Fail closed before producing a distributable with an unusable update channel."""
import base64
import plistlib
import sys
from pathlib import Path


def validate(info: dict) -> None:
    if info.get('NinoPublicDistribution') is not True or info.get('CFBundleIdentifier') != 'app.sandro.nino' or info.get('NinoPreviewSession') or info.get('NinoPortableStorage'):
        raise ValueError('Public Nino identity required')
    key = base64.b64decode(info.get('SUPublicEDKey', ''), validate=True)
    if len(key) != 32 or not any(key):
        raise ValueError('Update signing public key is missing; do not publish this build')
    if info.get('SUFeedURL') != 'https://nino-companion.vercel.app/appcast.xml':
        raise ValueError('Unexpected update feed')
    for name, expected in {'SUVerifyUpdateBeforeExtraction': True, 'SUAllowsAutomaticUpdates': False,
                           'SUEnableAutomaticChecks': False, 'SUAutomaticallyUpdate': False,
                           'SUEnableSystemProfiling': False}.items():
        if info.get(name) is not expected:
            raise ValueError(f'Invalid update setting: {name}')


if __name__ == '__main__':
    validate(plistlib.loads(Path(sys.argv[1]).read_bytes()))
