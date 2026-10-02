import importlib.util
import json
import pathlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('capture', pathlib.Path(__file__).parents[1] / 'capture_ios_simulator.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)

class ReadinessTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = pathlib.Path(self.directory.name) / 'state.json'

    def write(self, **updates):
        value = {'launch_id':'fresh','stage':'ready','locale':'ja','requested_scene':'home'}
        value.update(updates)
        self.path.write_text(json.dumps(value))

    def poll(self):
        return capture.wait_for_capture(self.path, 'ja', 'home', 'fresh', timeout=.025, poll=.002)

    def test_ready(self):
        self.write()
        self.assertEqual(self.poll()['stage'], 'ready')

    def test_missing_file_is_bounded(self):
        with self.assertRaisesRegex(TimeoutError, 'last_stage=None'):
            self.poll()

    def test_stale_launch_is_rejected(self):
        self.write(launch_id='stale')
        with self.assertRaises(TimeoutError):
            self.poll()

    def test_startup_stage_is_reported(self):
        self.write(stage='controller_start')
        with self.assertRaisesRegex(TimeoutError, 'controller_start'):
            self.poll()

    def test_explicit_error_is_reported(self):
        self.write(stage='error', error='Missing simulator environment')
        with self.assertRaisesRegex(RuntimeError, 'Missing simulator environment'):
            self.poll()

    def test_wrong_locale_is_rejected(self):
        self.write(locale='en')
        with self.assertRaisesRegex(RuntimeError, 'mismatch'):
            self.poll()

    def test_partial_json_is_bounded(self):
        self.path.write_text('{')
        with self.assertRaises(TimeoutError):
            self.poll()

if __name__ == '__main__':
    unittest.main()
