import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'ci-screenshots.sh'


class ScreenshotRecoveryTest(unittest.TestCase):
    def run_screenshots(self, failure):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binaries = root / 'bin'
            binaries.mkdir()
            apk = root / 'build/app/outputs/flutter-apk/app-profile.apk'
            apk.parent.mkdir(parents=True)
            apk.write_bytes(b'apk')
            adb = binaries / 'adb'
            adb.write_text('''#!/usr/bin/env bash
set -eu
echo "$*" >> adb.log
case "$*" in
  *get-state) echo device ;;
  *sys.boot_completed) echo 1 ;;
esac
''')
            flutter = binaries / 'flutter'
            flutter.write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
import struct
import sys

assert not any(arg.startswith('--host-vmservice-port=') for arg in sys.argv)
first = not Path('attempted').exists()
Path('attempted').touch()
if first:
    print(os.environ['FAILURE'])
    sys.exit(1)
commands = Path('adb.log').read_text()
assert '-s emulator-5554 reboot' in commands
assert commands.count('shell am force-stop com.presley.flexify') == 2
assert commands.count('forward --remove-all') == 2
output = Path('fastlane/metadata/android/en-US/images/phoneScreenshots')
for number in range(1, 9):
    (output / f'{number}_en-US.png').write_bytes(
        b'\\x89PNG\\r\\n\\x1a\\n' + bytes(8) + struct.pack('>II', 1080, 2160) + bytes((8, 2)))
print('All tests passed!')
''')
            adb.chmod(0o755)
            flutter.chmod(0o755)
            result = subprocess.run(
                ['bash', str(SCRIPT)],
                cwd=root,
                env={**os.environ, 'PATH': f'{binaries}:{os.environ["PATH"]}',
                     'EMULATOR_PORT': '5554', 'FLEX_DEVICE_TYPE': 'phoneScreenshots',
                     'FAILURE': failure},
                capture_output=True,
                text=True,
                timeout=15,
            )
            return result, (root / 'adb.log').read_text()

    def test_reboots_and_cleans_transport_before_retry(self):
        result, _ = self.run_screenshots('Service has disappeared')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_framework_errors_are_not_retried(self):
        result, commands = self.run_screenshots('Another exception was thrown: broken widget')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('reboot', commands)
        self.assertIn('Flutter error output detected', result.stderr)


if __name__ == '__main__':
    unittest.main()
