import hashlib
import io
import json
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import pilot


class PilotTests(unittest.TestCase):
    def test_guest_guard(self):
        with patch.object(Path, "exists", return_value=False):
            with self.assertRaisesRegex(ValueError, "host-only"):
                pilot.host_only()

    def test_profile_requires_actual_cuda_nodes(self):
        with tempfile.TemporaryDirectory() as directory:
            profile = Path(directory) / "ort.json"
            profile.write_text(
                json.dumps(
                    [
                        {"cat": "Node", "args": {"provider": "CPUExecutionProvider"}},
                        {
                            "cat": "Session",
                            "args": {"provider": "CUDAExecutionProvider"},
                        },
                    ]
                )
            )
            with self.assertRaisesRegex(ValueError, "fallback"):
                pilot.check_profiles([profile], "cuda")
            self.assertEqual(
                pilot.check_profiles([profile], "cpu"), {"CPUExecutionProvider": 1}
            )
            profile.write_text(
                json.dumps(
                    [
                        {"cat": "Node", "args": {"provider": "CUDAExecutionProvider"}},
                        {"cat": "Node", "args": {"provider": "CPUExecutionProvider"}},
                    ]
                )
            )
            self.assertEqual(
                pilot.check_profiles([profile], "cuda")["CUDAExecutionProvider"], 1
            )
            with self.assertRaisesRegex(ValueError, "unverified"):
                pilot.check_profiles([], "cuda")

    def test_voice_data_must_match_cpu(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cpu, gpu = root / "cpu", root / "gpu"
            cpu.mkdir()
            gpu.mkdir()
            for name in ("voices.bin", "tokens.txt"):
                (cpu / name).write_bytes(b"same")
                (gpu / name).write_bytes(b"same")
            pilot.verify_voice(gpu, cpu)
            (gpu / "voices.bin").write_bytes(b"different")
            with self.assertRaisesRegex(ValueError, "Bella"):
                pilot.verify_voice(gpu, cpu)

    def test_fetch_default_excludes_nvidia_and_rejects_tamper(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            downloads = root / "downloads"
            downloads.mkdir()
            archive = downloads / "tiny.tar.bz2"
            with tarfile.open(archive, "w:bz2") as bundle:
                member = tarfile.TarInfo("tiny/model.onnx")
                member.size = 3
                bundle.addfile(member, io.BytesIO(b"abc"))
            assets = [
                {
                    "name": archive.name,
                    "size": archive.stat().st_size,
                    "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                    "group": "base",
                },
                {"name": "never.whl", "size": 999, "group": "nvidia"},
            ]
            with patch.object(pilot.json, "loads", return_value=assets):
                with patch.object(pilot.urllib.request, "urlopen") as network:
                    pilot.fetch(root, False)
                    network.assert_not_called()
                    self.assertEqual((root / "tiny/model.onnx").read_bytes(), b"abc")
                    archive.write_bytes(b"tampered")
                    with self.assertRaisesRegex(ValueError, "mismatch"):
                        pilot.fetch(root, False)
                    network.assert_not_called()

    def test_manifest_pins_sizes_and_hashes(self):
        assets = json.loads((pilot.HERE / "pilot-assets.json").read_text())
        self.assertEqual(
            sum(a["size"] for a in assets if a["group"] == "base"), 520538638
        )
        for asset in assets:
            self.assertRegex(asset["sha256"], r"^[a-f0-9]{64}$")
            self.assertTrue(asset["url"].startswith("https://"))


if __name__ == "__main__":
    unittest.main()
