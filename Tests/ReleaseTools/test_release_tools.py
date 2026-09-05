import importlib.util
import json
import os
import plistlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


stamp = load('stamp-release-version')
publisher = load('publish-release')


class ReleaseTests(unittest.TestCase):
    def test_stamp_preserves_identity_and_rejects_invalid_version_without_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Info.plist'
            path.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.local.SteadyFrame', 'CFBundleName': 'HiFrame'}))
            original = path.read_bytes()
            for invalid in ['v0.5.1', '0.5.1-beta', '01.2.3', '1.2', '1.2.3/extra']:
                with self.assertRaises(ValueError):
                    stamp.stamp(path, invalid)
                self.assertEqual(path.read_bytes(), original)
            stamp.stamp(path, '0.5.1')
            info = plistlib.loads(path.read_bytes())
            self.assertEqual(info['CFBundleIdentifier'], 'com.local.SteadyFrame')
            self.assertEqual(info['CFBundleShortVersionString'], '0.5.1')
            self.assertEqual(info['CFBundleVersion'], '0.5.1')

    def test_published_release_and_downgrade_are_rejected_without_mutation(self):
        for releases in [
            [{'tagName': 'v0.5.0', 'isDraft': False, 'isLatest': True}],
            [{'tagName': 'v0.6.0', 'isDraft': False, 'isLatest': True}],
        ]:
            with patch.object(publisher, 'gh', return_value=json.dumps(releases)) as client:
                with self.assertRaises(RuntimeError):
                    publisher.publish('v0.5.0')
                self.assertEqual(client.call_count, 1)

    def test_api_failure_never_creates_release(self):
        with patch.object(publisher, 'gh', side_effect=RuntimeError('network error')) as client:
            with self.assertRaises(RuntimeError):
                publisher.publish('v0.5.0')
            self.assertEqual(client.call_count, 1)

    def test_assets_are_verified_before_publication_and_failure_keeps_draft(self):
        for corrupt in [False, True]:
            with self.subTest(corrupt=corrupt), tempfile.TemporaryDirectory() as directory:
                previous = Path.cwd()
                try:
                    os.chdir(directory)
                    assets = Path('downloads')
                    assets.mkdir()
                    (assets / 'HiFrame.zip').write_bytes(b'test archive')
                    digest = publisher.hashlib.sha256(b'test archive').hexdigest()
                    (assets / 'HiFrame.zip.sha256').write_text(f'{digest}  HiFrame.zip\n')
                    calls = []

                    def fake_gh(*args):
                        calls.append(args)
                        if args[:2] == ('release', 'list'):
                            return '[]'
                        if args[:2] == ('release', 'download'):
                            destination = Path(args[args.index('--dir') + 1])
                            destination.mkdir()
                            for asset in assets.iterdir():
                                (destination / asset.name).write_bytes(b'corrupt' if corrupt else asset.read_bytes())
                        return 'https://github.com/example/release'

                    with patch.object(publisher, 'gh', side_effect=fake_gh), patch.dict(os.environ, {'GITHUB_STEP_SUMMARY': ''}):
                        if corrupt:
                            with self.assertRaises(RuntimeError):
                                publisher.publish('v0.5.0')
                        else:
                            publisher.publish('v0.5.0')
                    published = [call for call in calls if '--draft=false' in call]
                    self.assertEqual(bool(published), not corrupt)
                    self.assertIn('--draft', next(call for call in calls if call[:2] == ('release', 'create')))
                finally:
                    os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
