#!/bin/bash
set -euo pipefail

# Build with a fixed Lab data namespace in both the app and CLI, without changing default Whisky builds.
LAB_REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAB_BUILD_DIR="$LAB_REPO_ROOT/.build/lab"
LAB_PACKAGE_DIR="$LAB_REPO_ROOT/.build/packaged"
LAB_BUILD_CONFIG="${WHISKY_LAB_CONFIGURATION:-Debug}"

if ! command -v swiftlint >/dev/null; then
    echo "SwiftLint is required. Add an official SwiftLint executable to PATH before building." >&2
    exit 1
fi

xcodebuild -project "$LAB_REPO_ROOT/Whisky.xcodeproj" -scheme Whisky \
    -configuration "$LAB_BUILD_CONFIG" -derivedDataPath "$LAB_BUILD_DIR" \
    'OTHER_SWIFT_FLAGS=$(inherited) -DWHISKY_LAB' CODE_SIGNING_ALLOWED=NO build

python3 - "$LAB_BUILD_DIR/Build/Products/$LAB_BUILD_CONFIG/Whisky.app" "$LAB_PACKAGE_DIR" <<'PYTHON'
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

source = Path(sys.argv[1])
staging = Path(sys.argv[2])
destination = staging / 'Whisky Lab.app'
staging.mkdir(parents=True, exist_ok=True)
if destination.exists():
    shutil.rmtree(destination)
shutil.copytree(source, destination, symlinks=True)

info_path = destination / 'Contents/Info.plist'
with info_path.open('rb') as stream:
    info = plistlib.load(stream)
info.update(CFBundleIdentifier='com.lechuit.WhiskyLab', CFBundleName='Whisky Lab',
            CFBundleDisplayName='Whisky Lab', SUEnableAutomaticChecks=False,
            SUAutomaticallyUpdate=False)
info.pop('SUFeedURL', None)
info.pop('SUPublicEDKey', None)
with info_path.open('wb') as stream:
    plistlib.dump(info, stream)

for extension in (destination / 'Contents/PlugIns').glob('*.appex'):
    extension_info = extension / 'Contents/Info.plist'
    with extension_info.open('rb') as stream:
        values = plistlib.load(stream)
    values['CFBundleIdentifier'] = 'com.lechuit.WhiskyLab.' + extension.stem
    with extension_info.open('wb') as stream:
        plistlib.dump(values, stream)

# Local ad-hoc signing is reproducible and does not require an Apple distribution certificate.
subprocess.run(['/usr/bin/codesign', '--force', '--deep', '--sign', '-', str(destination)], check=True)
subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(destination)], check=True)
print(destination)
PYTHON
