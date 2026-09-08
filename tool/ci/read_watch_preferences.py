#!/usr/bin/env python3
"""Read the paired Watch's binary or XML preferences without plutil diagnostics."""

import argparse
import json
import math
from pathlib import Path
import plistlib
import sys


class PreferencesError(Exception):
    """A present preferences file or value cannot be read safely."""


def _reject_constant(_value):
    raise ValueError('Non-finite JSON number')


def _finite_float(value):
    number = float(value)
    if not math.isfinite(number):
        raise ValueError('Non-finite JSON number')
    return number


def read_preferences(path):
    result = {'snapshot': None, 'healthAuthorization': None,
              'healthAuthorizationPending': None}
    try:
        payload = Path(path).read_bytes()
    except FileNotFoundError:
        return result
    except OSError as error:
        raise PreferencesError(f'Preferences file I/O failed ({type(error).__name__}).') from None

    try:
        preferences = plistlib.loads(payload)
    except Exception:
        # Parser exceptions can include preference contents; expose only the category.
        raise PreferencesError('Preferences file is not a valid plist.') from None
    if not isinstance(preferences, dict):
        raise PreferencesError('Preferences plist root must be a dictionary.')

    if 'cached_session_snapshot' in preferences:
        data = preferences['cached_session_snapshot']
        if not isinstance(data, bytes):
            raise PreferencesError('Cached snapshot must be plist data.')
        try:
            snapshot = json.loads(data.decode('utf-8'),
                                  parse_constant=_reject_constant,
                                  parse_float=_finite_float)
        except (UnicodeDecodeError, ValueError, RecursionError):
            raise PreferencesError('Cached snapshot must contain valid UTF-8 JSON.') from None
        if not isinstance(snapshot, dict):
            raise PreferencesError('Cached snapshot JSON must be an object.')
        result['snapshot'] = snapshot

    for key, output_key, value_type in (
        ('watch_health_authorization', 'healthAuthorization', int),
        ('watch_health_authorization_pending', 'healthAuthorizationPending', bool),
    ):
        if key in preferences:
            value = preferences[key]
            # bool is an int subclass in Python; these plist types must stay distinct.
            if type(value) is not value_type:
                raise PreferencesError(f'{output_key} must be {value_type.__name__}.')
            result[output_key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', type=Path)
    arguments = parser.parse_args()
    try:
        result = read_preferences(arguments.path)
    except PreferencesError as error:
        print(f'Cannot read Watch preferences: {error}', file=sys.stderr)
        return 1
    print(json.dumps(result, allow_nan=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
