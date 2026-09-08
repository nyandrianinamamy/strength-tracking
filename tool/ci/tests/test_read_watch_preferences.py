import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / 'read_watch_preferences.py'
SPEC = importlib.util.spec_from_file_location('read_watch_preferences', SCRIPT)
helper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helper)
EMPTY = {'snapshot': None, 'healthAuthorization': None,
         'healthAuthorizationPending': None}
FORMATS = (plistlib.FMT_BINARY, plistlib.FMT_XML)


class WatchPreferencesTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / 'watch.plist'

    def write(self, preferences, fmt=plistlib.FMT_BINARY):
        self.path.write_bytes(plistlib.dumps(preferences, fmt=fmt))

    def cli(self, *arguments):
        return subprocess.run([sys.executable, str(SCRIPT), *map(str, arguments)],
                              capture_output=True, text=True, check=False)

    def test_missing_file_is_absent(self):
        self.assertEqual(helper.read_preferences(self.path), EMPTY)

    def test_missing_keys_and_unrelated_preferences_are_absent_in_both_formats(self):
        for fmt in FORMATS:
            with self.subTest(fmt=fmt):
                self.write({'unrelated': b'not JSON'}, fmt)
                self.assertEqual(helper.read_preferences(self.path), EMPTY)

    def test_initial_health_only_preferences_have_no_snapshot(self):
        for fmt in FORMATS:
            with self.subTest(fmt=fmt):
                self.write({'watch_health_authorization': 0,
                            'watch_health_authorization_pending': False}, fmt)
                self.assertEqual(helper.read_preferences(self.path), {
                    'snapshot': None, 'healthAuthorization': 0,
                    'healthAuthorizationPending': False})

    def test_nsdata_snapshot_and_health_values_in_both_formats(self):
        snapshot = {'sessionId': 'paired-watch-fixture', 'revision': 3,
                    'isActive': True, 'exercise': 'Séance',
                    'sets': [{'duration': 1.5, 'completed': False}], 'rest': None}
        for fmt in FORMATS:
            for status in (0, 1, 2):
                for pending in (False, True):
                    with self.subTest(fmt=fmt, status=status, pending=pending):
                        self.write({
                            'cached_session_snapshot': json.dumps(snapshot).encode(),
                            'watch_health_authorization': status,
                            'watch_health_authorization_pending': pending,
                            'unrelated': 'ignored'}, fmt)
                        self.assertEqual(helper.read_preferences(self.path), {
                            'snapshot': snapshot, 'healthAuthorization': status,
                            'healthAuthorizationPending': pending})

    def test_empty_snapshot_object_is_distinct_from_absence(self):
        self.write({'cached_session_snapshot': b'{}'})
        self.assertEqual(helper.read_preferences(self.path)['snapshot'], {})

    def test_reads_preferences_file_once(self):
        payload = plistlib.dumps({'watch_health_authorization': 2})
        with patch.object(Path, 'read_bytes', return_value=payload) as read:
            self.assertEqual(helper.read_preferences(self.path)['healthAuthorization'], 2)
        read.assert_called_once_with()

    def test_corrupt_binary_xml_and_non_plist_fail(self):
        for payload in (b'bplist00broken', b'<?xml version="1.0"?><plist><dict>',
                        b'not a plist'):
            with self.subTest(payload=payload):
                self.path.write_bytes(payload)
                with self.assertRaises(helper.PreferencesError):
                    helper.read_preferences(self.path)

    def test_non_dictionary_plist_root_fails(self):
        for fmt in FORMATS:
            for root in ([], 'text', 1, True, b'data'):
                with self.subTest(fmt=fmt, root=root):
                    self.write(root, fmt)
                    with self.assertRaises(helper.PreferencesError):
                        helper.read_preferences(self.path)

    def test_snapshot_must_be_nsdata(self):
        for value in ('{}', {}, [], 1, True):
            with self.subTest(value=value):
                self.write({'cached_session_snapshot': value})
                with self.assertRaises(helper.PreferencesError):
                    helper.read_preferences(self.path)

    def test_snapshot_must_contain_utf8_json_object(self):
        for value in (b'\xff', b'{invalid}', b'[]', b'null', b'1', b'true', b'"text"'):
            with self.subTest(value=value):
                self.write({'cached_session_snapshot': value})
                with self.assertRaises(helper.PreferencesError):
                    helper.read_preferences(self.path)

    def test_snapshot_rejects_non_finite_json_numbers(self):
        for value in (b'{"value":NaN}', b'{"value":Infinity}',
                      b'{"value":-Infinity}', b'{"nested":[1e400]}'):
            with self.subTest(value=value):
                self.write({'cached_session_snapshot': value})
                with self.assertRaises(helper.PreferencesError):
                    helper.read_preferences(self.path)

    def test_health_status_is_integer_not_bool_or_other_types(self):
        for value in (True, False, '2', 2.0, [], {}, b'2'):
            with self.subTest(value=value):
                self.write({'watch_health_authorization': value})
                with self.assertRaises(helper.PreferencesError):
                    helper.read_preferences(self.path)

    def test_health_pending_is_bool_not_integer_or_other_types(self):
        for value in (0, 1, 'false', 0.0, [], {}, b'false'):
            with self.subTest(value=value):
                self.write({'watch_health_authorization_pending': value})
                with self.assertRaises(helper.PreferencesError):
                    helper.read_preferences(self.path)

    def test_permission_and_io_errors_fail_without_exposing_contents(self):
        for error in (PermissionError('private preference details'),
                      OSError('private preference details')):
            with self.subTest(error=type(error).__name__):
                with patch.object(Path, 'read_bytes', side_effect=error):
                    with self.assertRaises(helper.PreferencesError) as raised:
                        helper.read_preferences(self.path)
                self.assertNotIn('private preference details', str(raised.exception))

    def test_directory_instead_of_plist_is_an_io_failure(self):
        with self.assertRaises(helper.PreferencesError):
            helper.read_preferences(Path(self.directory.name))

    def test_cli_contract_for_present_and_absent_preferences(self):
        for present in (False, True):
            with self.subTest(present=present):
                if present:
                    self.write({'cached_session_snapshot': b'{"revision":1}',
                                'watch_health_authorization': 2,
                                'watch_health_authorization_pending': False})
                result = self.cli(self.path)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                actual = json.loads(result.stdout)
                self.assertEqual(set(actual), set(EMPTY))
                self.assertEqual(actual, {
                    'snapshot': {'revision': 1}, 'healthAuthorization': 2,
                    'healthAuthorizationPending': False} if present else EMPTY)

    def test_cli_errors_are_nonzero_with_no_snapshot_output_or_private_details(self):
        for preferences in ({'cached_session_snapshot': b'private-snapshot-data'},
                            {'watch_health_authorization': 'private-health-data'}):
            with self.subTest(preferences=preferences):
                self.write(preferences)
                result = self.cli(self.path)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertIn('Cannot read Watch preferences:', result.stderr)
                self.assertNotIn('private-', result.stderr)
                self.assertNotIn('Traceback', result.stderr)

    def test_cli_requires_one_path(self):
        for arguments in ((), (self.path, self.path)):
            with self.subTest(arguments=arguments):
                result = self.cli(*arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
