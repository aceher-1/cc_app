"""Read-only check of the live Sodexo widget contract; no credentials or menus are saved.

Run: python tools/check_source.py [YYYY-MM-DD]
Only counts and schema information are printed. Requires Python 3.9+ and internet.
"""
import datetime
import json
import re
import sys
import urllib.request
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

SITE = "https://msoedining.sodexomyway.com"
PAGE = SITE + "/en-us/locations/the-dining-commons"


def load(url, headers=None):
    request = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def capture(pattern, text):
    result = re.search(pattern, text)
    if not result:
        raise ValueError("The source widget configuration changed.")
    return result.group(1)


def main():
    if len(sys.argv) > 1:
        day = datetime.date.fromisoformat(sys.argv[1]).isoformat()
    else:
        try:
            day = datetime.datetime.now(ZoneInfo("America/Chicago")).date().isoformat()
        except ZoneInfoNotFoundError:
            raise SystemExit("Pass YYYY-MM-DD explicitly; this Python installation has no timezone database.")
    html = load(PAGE)
    location = capture(r'"locationId"\s*:\s*"([0-9]+)"', html)
    menu = capture(r'"menuId"\s*:\s*"([0-9]+)"', html)
    script_path = capture(r'src="(/static/js/main\.[a-zA-Z0-9]+\.js)"', html)
    production = capture(r'Production:\{(.{0,600})', load(SITE + script_path))
    key = capture(r'API_KEY:"([a-zA-Z0-9-]+)"', production)
    payload = json.loads(load(f"https://api-prd.sodexomyway.net/v0.2/data/menu/{location}/{menu}?date={day}", {"API-Key": key, "Accept": "application/json"}))
    if not isinstance(payload, list):
        raise ValueError("Unexpected menu root; expected an array.")
    count = 0
    for meal in payload:
        assert isinstance(meal["name"], str) and isinstance(meal["groups"], list)
        items = [item for group in meal["groups"] for item in group["items"]]
        for item in items:
            assert isinstance(item["formalName"], str)
            assert isinstance(item.get("allergens"), list)
            assert isinstance(item.get("ingredients"), str)
        count += len(items)
        print(f"{meal['name']}: {len(meal['groups'])} stations, {len(items)} dishes")
    print(f"PASS: {day}, {len(payload)} meals, {count} dishes; discovery and menu schema match.")


if __name__ == "__main__":
    main()
