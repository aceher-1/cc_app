"""Cheap scheduled health check; never treat yesterday's or an empty menu as complete."""
import datetime as dt
import json
import os
import urllib.request
from zoneinfo import ZoneInfo


def needed(manifest, now):
    try:
        stamp = dt.datetime.fromisoformat(manifest['updatedAt'].replace('Z', '+00:00'))
        if manifest.get('schemaVersion') != 1 or stamp.tzinfo is None or stamp > now:
            return True
        if stamp.astimezone(now.tzinfo).date() != now.date():
            return True
        entry = next(x for x in manifest['dates'] if x['date'] == now.date().isoformat())
        return not isinstance(entry.get('itemCount'), int) or entry['itemCount'] <= 0
    except (KeyError, TypeError, ValueError, StopIteration, AttributeError):
        return True


def main():
    refresh = True
    if os.environ.get('EVENT_NAME') == 'schedule':
        try:
            request = urllib.request.Request('https://aceher-1.github.io/cc_app/manifest.json',
                                             headers={'Cache-Control': 'no-cache'})
            with urllib.request.urlopen(request, timeout=20) as response:
                refresh = needed(json.load(response), dt.datetime.now(ZoneInfo('America/Chicago')))
        except (OSError, ValueError):
            pass  # A failed health check must not suppress recovery.
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
        output.write(f'needed={str(refresh).lower()}\n')
    print('Publication required.' if refresh else 'Today already has a nonempty publication; skipping upstream downloads.')


if __name__ == '__main__':
    main()
