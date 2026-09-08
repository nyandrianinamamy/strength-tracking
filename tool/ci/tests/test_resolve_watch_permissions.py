import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'resolve_watch_permissions', Path(__file__).parents[1] / 'resolve_watch_permissions.py')
helper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helper)
WATCH = '5955382B-1BAC-4BAE-9082-FBA83BDA6AE0'


def node(label, role='StaticText', x=10, y=60, width=180, height=20, **extra):
    return {'AXLabel': label, 'type': role,
            'frame': {'x': x, 'y': y, 'width': width, 'height': height}, **extra}


def screen(*children):
    return [node('Kotrana', 'Application', x=0, y=0, width=208, height=248,
                 children=list(children))]


class WatchUITests(unittest.TestCase):
    def test_already_granted_workout_and_idle_are_observed(self):
        for label in ('Test strength exercise', 'Aucune séance active'):
            self.assertEqual(helper.inspect_ui(screen(node(label)), label)['state'], 'expected')

    def test_real_watch_captures_match_timed_workout_and_french_idle(self):
        fixtures = Path(__file__).parent / 'fixtures' / 'watch-ax'
        for filename, expected in (('timed-workout.json', 'Test timed exercise'),
                                   ('idle.json', 'Aucune séance active')):
            capture = json.loads((fixtures / filename).read_text())
            self.assertEqual(helper.inspect_ui(capture, expected)['state'], 'expected')
            self.assertEqual(helper.inspect_ui(capture, 'Missing exercise')['state'], 'waiting')

    def test_hidden_ancestor_hides_its_descendants(self):
        self.assertEqual(helper.inspect_ui(screen(node('', 'Group', hidden=True,
            children=[node('Expected')])), 'Expected')['state'], 'waiting')

    def test_offscreen_or_hidden_exercise_is_not_acceptance(self):
        for entry in (node('Expected', x=220), node('Expected', hidden=True),
                      node('Expected', visible=False), node('Expected', width=0)):
            self.assertEqual(helper.inspect_ui(screen(entry), 'Expected')['state'], 'waiting')

    def test_health_sheet_cannot_pass_through_background_exercise(self):
        tree = screen(node('Expected'), node('Health Access'), node('Review', 'Button'))
        observation = helper.inspect_ui(tree, 'Expected')
        self.assertEqual(observation['state'], 'health')
        self.assertEqual(observation['action'], {'label': 'Review', 'element_type': 'Button'})

    def test_unknown_dialog_is_not_clicked_or_accepted(self):
        tree = screen(node('Unknown request', 'Alert'), node('Expected'), node('Allow', 'Button'))
        observation = helper.inspect_ui(tree, 'Expected')
        self.assertEqual(observation['state'], 'unresolved-dialog')
        self.assertNotIn('action', observation)

    def test_label_without_matching_health_stage_is_never_clicked(self):
        self.assertNotIn('action', helper.inspect_ui(screen(node('Review', 'Button')), 'Expected'))

    def test_ambiguous_and_disabled_health_controls_fail_closed(self):
        with self.assertRaises(helper.ResolutionError):
            helper.inspect_ui(screen(node('Health Access'), node('Review', 'Button'), node('Review', 'Button')), 'Expected')
        observation = helper.inspect_ui(screen(node('Health Access'), node('Review', 'Button', enabled=False)), 'Expected')
        self.assertNotIn('action', observation)

    def test_real_write_access_top_grants_request_using_live_frame(self):
        tree = self.fixture('watch-write-access.json')
        action = helper.inspect_ui(tree, 'Expected')['action']
        self.assertEqual(action, {'gesture': 'tap', 'label': 'All Requested Data Below',
                                  'element_type': 'CheckBox', 'x': 104.0, 'y': 212.0,
                                  'confirm_checkbox': 'UIA.Health.WatchAuthSheet.SwitchCellALL_REQUESTED_DATA'})

    def test_checked_top_scrolls_using_live_screen_frame(self):
        tree = self.fixture('watch-write-access.json', checked=True)
        action = helper.inspect_ui(tree, 'Expected')['action']
        self.assertEqual(action, {'gesture': 'swipe', 'start_x': 104.0, 'start_y': 219.0,
                                  'end_x': 104.0, 'end_y': 90.0})

    def test_unchecked_workouts_under_toolbar_scrolls_back_before_done(self):
        tree = self.fixture('watch-write-access-scrolled.json')
        action = helper.inspect_ui(tree, 'Expected')['action']
        self.assertEqual(action, {'gesture': 'swipe', 'start_x': 104.0, 'start_y': 90.0,
                                  'end_x': 104.0, 'end_y': 219.0})

    def test_checked_workouts_allows_done_without_toggling_again(self):
        tree = self.fixture('watch-write-access-scrolled.json', checked=True)
        action = helper.inspect_ui(tree, 'Expected')['action']
        self.assertEqual(action, {'gesture': 'tap', 'label': 'Done',
                                  'element_type': 'GenericElement', 'x': 104.0, 'y': 208.0})
        checkbox_values = [n['AXValue'] for n in helper.flatten(tree) if helper.node_role(n) == 'checkbox']
        self.assertEqual(checkbox_values, ['1', '1'])

    def test_tappable_workouts_checkbox_is_preferred_over_all_requested(self):
        tree = self.fixture('watch-write-access-scrolled.json')
        control = next(n for n in helper.flatten(tree) if n.get('AXUniqueId') == 'UIA.Health.WatchAuthSheet.Workouts')
        control['frame']['y'] = 90
        tree[0]['children'].append(node('All Requested Data Below', 'CheckBox', y=150, height=55,
            AXUniqueId='UIA.Health.WatchAuthSheet.SwitchCellALL_REQUESTED_DATA', AXValue='0', enabled=True))
        action = helper.inspect_ui(tree, 'Expected')['action']
        self.assertEqual(action['label'], 'Workouts')
        self.assertEqual((action['x'], action['y']), (104.0, 117.5))
        self.assertEqual(action['confirm_checkbox'], 'UIA.Health.WatchAuthSheet.Workouts')

    def test_unknown_checkbox_value_and_identity_fail_closed(self):
        for changes in ({'AXValue': 'unknown'}, {'AXUniqueId': 'Another.Workouts'}):
            tree = self.fixture('watch-write-access-scrolled.json')
            control = next(n for n in helper.flatten(tree) if n.get('AXUniqueId') == 'UIA.Health.WatchAuthSheet.Workouts')
            control.update(changes)
            with self.assertRaises(helper.ResolutionError):
                helper.inspect_ui(tree, 'Expected')

    def test_extra_permission_request_is_not_granted(self):
        tree = self.fixture('watch-write-access.json')
        tree[0]['children'].append(node('Heart Rate', 'CheckBox', y=90,
            AXUniqueId='UIA.Health.WatchAuthSheet.HeartRate', AXValue='0', enabled=True))
        with self.assertRaises(helper.ResolutionError):
            helper.inspect_ui(tree, 'Expected')

    def test_done_requires_actual_workouts_checkbox_confirmation(self):
        tree = self.fixture('watch-write-access-scrolled.json', checked=True)
        for entry in helper.flatten(tree):
            if entry.get('AXUniqueId') == 'UIA.Health.WatchAuthSheet.Workouts':
                entry['hidden'] = True
        self.assertNotIn('action', helper.inspect_ui(tree, 'Expected'))

    def test_ordinary_workout_done_is_never_a_permission_action(self):
        tree = screen(node('Expected'), node('Done', 'GenericElement'))
        observation = helper.inspect_ui(tree, 'Expected')
        self.assertEqual(observation['state'], 'expected')
        self.assertNotIn('action', observation)

    def test_write_access_requires_observed_kotrana_identity(self):
        tree = self.fixture('watch-write-access-scrolled.json')
        for entry in helper.flatten(tree):
            for key in ('AXLabel', 'AXValue'):
                if isinstance(entry.get(key), str):
                    entry[key] = entry[key].replace('Kotrana', 'Another app')
        observation = helper.inspect_ui(tree, 'Expected')
        self.assertEqual(observation['state'], 'unresolved-dialog')
        self.assertNotIn('action', observation)

    def test_write_access_done_ambiguity_and_unknown_identity_fail_closed(self):
        tree = self.fixture('watch-write-access-scrolled.json', checked=True)
        control = next(n for n in helper.flatten(tree) if helper.node_role(n) == 'genericelement' and helper.node_label(n) == 'Done')
        tree[0]['children'].append(dict(control))
        with self.assertRaises(helper.ResolutionError):
            helper.inspect_ui(tree, 'Expected')
        tree[0]['children'].pop()
        control['AXUniqueId'] = 'ordinary-workout-done'
        self.assertNotIn('action', helper.inspect_ui(tree, 'Expected'))

    def test_grant_sequence_confirms_checked_workouts_before_done(self):
        captures = [self.fixture('watch-write-access.json'),
                    self.fixture('watch-write-access.json', checked=True),
                    self.fixture('watch-write-access-scrolled.json', checked=True),
                    self.fixture('timed-workout.json'), self.fixture('timed-workout.json')]
        commands = []
        clock = [0.0]

        def run(args, **kwargs):
            commands.append(args)
            if args[1] == '--version':
                return subprocess.CompletedProcess(args, 0, '1.8.0\n', '')
            if args[0] == 'xcrun':
                output = {'devices': {'com.apple.CoreSimulator.SimRuntime.watchOS-26-2': [
                    {'udid': WATCH, 'state': 'Booted', 'isAvailable': True}]}}
            elif args[1] == 'describe-ui':
                output = captures.pop(0)
            else:
                output = {}
            return subprocess.CompletedProcess(args, 0, json.dumps(output), '')

        with tempfile.TemporaryDirectory() as directory:
            resolver = helper.Resolver('/tmp/test-axe', WATCH, 'Test timed exercise', directory,
                                       run=run, monotonic=lambda: clock[0],
                                       sleep=lambda delta: clock.__setitem__(0, clock[0] + delta))
            self.assertTrue(resolver.resolve()['ok'])
            actions = [args for args in commands if args[1] in {'tap', 'swipe'}]
            self.assertEqual([args[1] for args in actions], ['tap', 'swipe', 'tap'])
            self.assertEqual(actions[0], ['/tmp/test-axe', 'tap', '-x', '104.0',
                                          '-y', '212.0', '--udid', WATCH])
            self.assertEqual(actions[2], ['/tmp/test-axe', 'tap', '-x', '104.0',
                                          '-y', '208.0', '--udid', WATCH])
            self.assertTrue(all(args[-2:] == ['--udid', WATCH] for args in actions))
            events = json.loads((Path(directory) / 'events.json').read_text())
            self.assertEqual(events[1]['confirmed_checkbox'],
                             'UIA.Health.WatchAuthSheet.SwitchCellALL_REQUESTED_DATA')
            self.assertEqual(events[2]['tapped']['label'], 'Done')

    def test_unconfirmed_toggle_cannot_scroll_tap_again_or_accept_workout(self):
        clock = [0.0]
        commands = []
        captures = [self.fixture('watch-write-access.json'),
                    self.fixture('watch-write-access.json'), self.fixture('timed-workout.json')]

        def run(args, **kwargs):
            commands.append(args)
            if args[1] == '--version':
                return subprocess.CompletedProcess(args, 0, '1.8.0\n', '')
            if args[0] == 'xcrun':
                output = {'devices': {'com.apple.CoreSimulator.SimRuntime.watchOS-26-2': [
                    {'udid': WATCH, 'state': 'Booted', 'isAvailable': True}]}}
            elif args[1] == 'describe-ui':
                output = captures.pop(0) if captures else self.fixture('timed-workout.json')
                output[0]['capture_time'] = clock[0]  # Changing snapshots must not repeat the toggle.
            else:
                output = {}
            return subprocess.CompletedProcess(args, 0, json.dumps(output), '')

        with tempfile.TemporaryDirectory() as directory:
            resolver = helper.Resolver('/tmp/test-axe', WATCH, 'Test timed exercise', directory, timeout=2,
                                       run=run, monotonic=lambda: clock[0],
                                       sleep=lambda delta: clock.__setitem__(0, clock[0] + delta))
            with self.assertRaises(helper.ResolutionError):
                resolver.resolve()
            actions = [args for args in commands if args[1] in {'tap', 'swipe'}]
            self.assertEqual(len(actions), 1)
            self.assertEqual(actions[0][1:6], ['tap', '-x', '104.0', '-y', '212.0'])

    def test_done_cli_uses_fresh_frame_center_not_activation_point(self):
        tree = self.fixture('watch-write-access-scrolled.json', checked=True)
        control = next(n for n in helper.flatten(tree) if
                       n.get('AXUniqueId') == 'UIA.Health.WatchAuthSheet.ConfigureCell.Button')
        control['frame'] = {'x': 8, 'y': 152, 'width': 160, 'height': 40}
        control['AXActivationPoint'] = '{175, 16}'
        captures = [tree, self.fixture('idle.json'), self.fixture('idle.json')]
        commands = []
        clock = [0.0]

        def run(args, **kwargs):
            commands.append(args)
            if args[1] == '--version':
                return subprocess.CompletedProcess(args, 0, '1.8.0\n', '')
            if args[0] == 'xcrun':
                output = {'devices': {'com.apple.CoreSimulator.SimRuntime.watchOS-26-2': [
                    {'udid': WATCH, 'state': 'Booted', 'isAvailable': True}]}}
            elif args[1] == 'describe-ui':
                output = captures.pop(0)
            else:
                output = {}
            return subprocess.CompletedProcess(args, 0, json.dumps(output), '')

        with tempfile.TemporaryDirectory() as directory:
            resolver = helper.Resolver('/tmp/test-axe', WATCH, 'Aucune séance active', directory,
                                       run=run, monotonic=lambda: clock[0],
                                       sleep=lambda delta: clock.__setitem__(0, clock[0] + delta))
            self.assertTrue(resolver.resolve()['ok'])
            taps = [args for args in commands if args[1] == 'tap']
            self.assertEqual(taps, [['/tmp/test-axe', 'tap', '-x', '88.0', '-y', '172.0',
                                     '--udid', WATCH]])
            events = json.loads((Path(directory) / 'events.json').read_text())
            self.assertEqual(events[0]['tapped']['x'], 88.0)
            self.assertEqual(events[0]['tapped']['y'], 172.0)

    def test_done_must_remain_fully_onscreen_and_enabled(self):
        for changes in ({'frame': {'x': 2, 'y': 230, 'width': 204, 'height': 55}},
                        {'enabled': False}):
            tree = self.fixture('watch-write-access-scrolled.json', checked=True)
            control = next(n for n in helper.flatten(tree) if
                           n.get('AXUniqueId') == 'UIA.Health.WatchAuthSheet.ConfigureCell.Button')
            control.update(changes)
            observation = helper.inspect_ui(tree, 'Expected')
            self.assertEqual(observation['state'], 'unresolved-dialog')
            self.assertNotIn('action', observation)

    @staticmethod
    def fixture(filename, checked=False):
        tree = json.loads((Path(__file__).parent / 'fixtures' / 'watch-ax' / filename).read_text())
        if checked:
            # Synthetic checked-state variants; the source captures remain untouched.
            for entry in helper.flatten(tree):
                if helper.node_role(entry) == 'checkbox':
                    entry['AXValue'] = '1'
        return tree

    def test_watch_identity_is_validated(self):
        watch = {'udid': WATCH, 'state': 'Booted', 'isAvailable': True}
        inventory = {'devices': {'com.apple.CoreSimulator.SimRuntime.watchOS-26-2': [watch]}}
        self.assertEqual(helper.validate_watch(inventory, WATCH)['udid'], WATCH)
        with self.assertRaises(helper.ResolutionError):
            helper.validate_watch({'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-26-3': [watch]}}, WATCH)
        watch['state'] = 'Shutdown'
        with self.assertRaises(helper.ResolutionError):
            helper.validate_watch(inventory, WATCH)

    def test_observed_controls_only_and_two_stable_captures(self):
        captures = [screen(node('Health Access'), node('Review', 'Button')),
                    screen(node('Health Access'), node('Review', 'Button')),
                    screen(node('Expected')), screen(node('Expected'))]
        commands = []
        clock = [0.0]

        def run(args, **kwargs):
            commands.append(args)
            if args[1] == '--version':
                return subprocess.CompletedProcess(args, 0, '1.8.0\n', '')
            if args[0] == 'xcrun':
                output = {'devices': {'com.apple.CoreSimulator.SimRuntime.watchOS-26-2': [
                    {'udid': WATCH, 'state': 'Booted', 'isAvailable': True}]}}
            elif args[1] == 'describe-ui':
                output = captures.pop(0)
            else:
                output = {}
            return subprocess.CompletedProcess(args, 0, json.dumps(output), '')

        with tempfile.TemporaryDirectory() as directory:
            resolver = helper.Resolver('/tmp/test-axe', WATCH, 'Expected', directory,
                                       run=run, monotonic=lambda: clock[0],
                                       sleep=lambda delta: clock.__setitem__(0, clock[0] + delta))
            result = resolver.resolve()
            self.assertTrue(result['ok'])
            taps = [args for args in commands if args[1] == 'tap']
            self.assertEqual(len(taps), 1, 'Do not repeat a tap on the unchanged AX snapshot')
            self.assertEqual(taps[0], ['/tmp/test-axe', 'tap', '--label', 'Review',
                                       '--element-type', 'Button', '--udid', WATCH])
            self.assertEqual(result['captures'], 4)
            self.assertTrue((Path(directory) / '004-ui.json').exists())
            self.assertTrue((Path(directory) / 'events.json').exists())

    def test_unresolved_sheet_times_out_without_guessing(self):
        clock = [0.0]
        commands = []

        def run(args, **kwargs):
            commands.append(args)
            if args[1] == '--version':
                return subprocess.CompletedProcess(args, 0, '1.8.0\n', '')
            if args[0] == 'xcrun':
                output = {'devices': {'com.apple.CoreSimulator.SimRuntime.watchOS-26-2': [
                    {'udid': WATCH, 'state': 'Booted', 'isAvailable': True}]}}
            else:
                output = screen(node('Health Access'), node('Unrecognized button', 'Button'))
            return subprocess.CompletedProcess(args, 0, json.dumps(output), '')

        with tempfile.TemporaryDirectory() as directory:
            resolver = helper.Resolver('/tmp/test-axe', WATCH, 'Expected', directory, timeout=1,
                                       run=run, monotonic=lambda: clock[0],
                                       sleep=lambda delta: clock.__setitem__(0, clock[0] + delta))
            with self.assertRaises(helper.ResolutionError):
                resolver.resolve()
            self.assertFalse(any(args[1] == 'tap' for args in commands))


if __name__ == '__main__':
    unittest.main()
