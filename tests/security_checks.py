"""Offline regressions: python3 tests/security_checks.py (downloads are mocked)."""
import ast
import importlib.util
import io
import json
import os
import pty
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class SecurityChecks(unittest.TestCase):
    def test_tls(self):
        spec = importlib.util.spec_from_file_location('extract', ROOT / 'skills/gabia-figma-extract/scripts/figma_extract.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        import ssl
        class Response(io.BytesIO):
            def __enter__(self): return self
            def __exit__(self, *args): self.close()
        def request(*args, **kwargs):
            self.assertTrue(kwargs['context'].check_hostname)
            self.assertEqual(kwargs['context'].verify_mode, ssl.CERT_REQUIRED)
            self.assertEqual(kwargs['timeout'], 30)
            return Response(b'{}')
        with patch.object(module.urllib.request, 'urlopen', side_effect=request):
            module.figma_get('/test', 'dummy')
            with tempfile.TemporaryDirectory() as temp:
                module.download_file('https://example.com/image', Path(temp) / 'image')

    def test_parser(self):
        script = ROOT / 'skills/gabia-figma-extract/scripts/parse_figma.mjs'
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'parsed/pc_safe').mkdir(parents=True)
            def run(name):
                (root / 'pc_raw.json').write_text(json.dumps({'name': 'root', 'type': 'FRAME', 'width': 1920, 'children': [{'name': name, 'type': 'FRAME', 'width': 1920, 'height': 100, 'children': []}]}))
                return subprocess.run(['node', str(script), '--dir', '.', '--out', 'parsed'], cwd=root, capture_output=True)
            self.assertNotEqual(run('safe/../../escaped').returncode, 0)
            self.assertFalse((root / 'escaped.json').exists())
            self.assertEqual(run('Hero').returncode, 0)
            self.assertTrue((root / 'parsed/pc_Hero.json').is_file())
            victim = root / 'victim'
            victim.write_text('unchanged')
            (root / 'parsed/pc_Link.json').symlink_to(victim)
            self.assertNotEqual(run('Link').returncode, 0)
            self.assertEqual(victim.read_text(), 'unchanged')

    def test_installer(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            project = root / 'project'
            project.mkdir()
            binary = root / 'bin'
            binary.mkdir()
            mock = binary / 'curl'
            mock.write_text('#!/bin/bash\nwhile [ "$#" -gt 0 ]; do\nif [ "$1" = "-o" ]; then cp "$TEST_ARCHIVE" "$2"; exit; fi\nshift\ndone\nexit 1\n')
            mock.chmod(0o755)
            script = root / 'install.sh'
            script.write_text((ROOT / 'install-skill.sh').read_text().replace('install_root="$HOME"', 'install_root="' + str(root / 'global') + '"'))
            env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ['PATH'], TEST_ARCHIVE=str(ROOT / 'downloads/gabia-figma-extract.tar.gz'))
            def run(target='claude', scope='local'):
                return subprocess.run(['bash', str(script), '--target', target, '--scope', scope], cwd=project, env=env, capture_output=True)
            for scope in ['local', 'global']:
                for target in ['claude', 'agents', 'codex']:
                    for _ in range(2): self.assertEqual(run(target, scope).returncode, 0)
                    dest = (project if scope == 'local' else root / 'global') / ('.' + target) / 'skills'
                    self.assertEqual(len(list(dest.glob('*.backup.*'))), 1)
                    for name in ['SKILL.md', 'scripts/figma_extract.py', 'scripts/parse_figma.mjs']:
                        self.assertEqual((dest / 'gabia-figma-extract' / name).read_bytes(), (ROOT / 'skills/gabia-figma-extract' / name).read_bytes())
            master, slave = pty.openpty()
            try:
                process = subprocess.Popen(['bash', str(script)], cwd=project, env=env, stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                os.write(master, b'2\n2\n')
                output, error = process.communicate(timeout=15)
                self.assertEqual(process.returncode, 0, error.decode())
                self.assertIn('설치 범위'.encode(), output)
                self.assertTrue((project / '.agents/skills/gabia-figma-extract/SKILL.md').is_file())
            finally:
                os.close(master)
                os.close(slave)
            self.assertNotEqual(run('invalid').returncode, 0)
            installed = project / '.claude/skills/gabia-figma-extract/SKILL.md'
            before = installed.read_bytes()
            for kind in ['traversal', 'symlink', 'hardlink', 'extra', 'duplicate', 'missing']:
                archive_path = root / (kind + '.tar.gz')
                with tarfile.open(archive_path, 'w:gz') as archive:
                    if kind != 'missing':
                        with tarfile.open(env['TEST_ARCHIVE']) as original:
                            for member in original:
                                archive.addfile(member, original.extractfile(member) if member.isfile() else None)
                    name = {'traversal': '../escaped', 'symlink': 'gabia-figma-extract/evil', 'hardlink': 'gabia-figma-extract/link', 'extra': 'gabia-figma-extract/extra', 'duplicate': 'gabia-figma-extract/SKILL.md', 'missing': 'gabia-figma-extract/SKILL.md'}[kind]
                    member = tarfile.TarInfo(name)
                    if kind in ['symlink', 'hardlink']:
                        member.type = tarfile.SYMTYPE if kind == 'symlink' else tarfile.LNKTYPE
                        member.linkname = '../escaped'
                    archive.addfile(member)
                bad_env = dict(env, TEST_ARCHIVE=str(archive_path))
                result = subprocess.run(['bash', str(script), '--target', 'claude', '--scope', 'local'], cwd=project, env=bad_env, capture_output=True)
                self.assertNotEqual(result.returncode, 0, kind)
                self.assertEqual(installed.read_bytes(), before)
            env['FIGMA_SKILL_BASE_URL'] = 'http://example.com'
            self.assertNotEqual(run().returncode, 0)
            self.assertEqual(installed.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
