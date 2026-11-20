"""Check the independently selectable renderer compatibility prefix."""

from pathlib import Path
import subprocess
import tempfile
import unittest


class AppleseedStagesTest(unittest.TestCase):
    def test_patch_stages(self):
        root = Path(__file__).resolve().parents[2]
        manifest = root / "appleseed" / "patches" / "Series.cmake"
        with tempfile.TemporaryDirectory(prefix="appleseed-stages-") as temporary:
            work = Path(temporary)
            script = work / "check.cmake"
            script.write_text(
                f'include("{manifest.as_posix()}")\n'
                'string(JOIN "\\n" selected ${APPLESEED_PATCH_FILES})\n'
                'file(WRITE "${OUTPUT}" "${selected}\\n")\n'
            )

            def select(stage=None):
                output = work / "selected.txt"
                args = ["cmake", f"-DOUTPUT={output}"]
                if stage is not None:
                    args.append(f"-DAPPLESEED_PATCH_STAGE={stage}")
                result = subprocess.run(
                    [*args, "-P", str(script)], capture_output=True, text=True
                )
                return result, output

            selected = {}
            for stage in ("CORE", "ART", None):
                result, output = select(stage)
                self.assertEqual(result.returncode, 0, result.stderr)
                paths = output.read_text().splitlines()
                self.assertTrue(paths)
                self.assertEqual(len(paths), len(set(paths)))
                self.assertTrue(all(Path(path).is_file() for path in paths))
                selected[stage] = paths
            core = selected["CORE"]
            full = selected["ART"]
            self.assertLess(len(core), len(full))
            self.assertEqual(core, full[: len(core)])
            self.assertEqual(full, selected[None])
            self.assertTrue(all(Path(path).parent.name != "art" for path in core))
            self.assertTrue(all(Path(path).parent.name == "art" for path in full[len(core) :]))
            for stage in ("", "cor", "OTHER"):
                result, _ = select(stage)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("must be CORE or ART", result.stderr)


if __name__ == "__main__":
    unittest.main()
