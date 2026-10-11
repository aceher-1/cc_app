"""Fetch the public Sodexo widget once centrally, then publish static JSON snapshots.

Usage: python tools/refresh_menus.py --output _site [--date YYYY-MM-DD]
No upstream key or authentication configuration is written to the output.
"""
import argparse
import datetime as dt
import json
from pathlib import Path
import re
import time
import urllib.error
import urllib.request
from zoneinfo import ZoneInfo

SITE = "https://msoedining.sodexomyway.com"
SOURCE = SITE + "/en-us/locations/the-dining-commons"


def capture(pattern, text):
    match = re.search(pattern, text)
    if not match:
        raise ValueError("The public dining widget configuration changed.")
    return match.group(1)


def load(url, headers=None):
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "CommonsMenuCache/1.0", **(headers or {})})
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read().decode("utf-8")
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)


def discover():
    html = load(SOURCE)
    location = capture(r'"locationId"\s*:\s*"([0-9]+)"', html)
    menu = capture(r'"menuId"\s*:\s*"([0-9]+)"', html)
    path = capture(r'src="(/static/js/main\.[a-zA-Z0-9]+\.js)"', html)
    production = capture(r'Production:\{(.{0,600})', load(SITE + path))
    key = capture(r'API_KEY:"([a-zA-Z0-9-]+)"', production)
    return location, menu, key


def validate_menu(meals):
    if not isinstance(meals, list):
        raise ValueError("Menu root must be an array.")
    count = 0
    for meal in meals:
        if not isinstance(meal, dict) or not isinstance(meal.get("name"), str) or not isinstance(meal.get("groups"), list):
            raise ValueError("Unexpected meal format.")
        for group in meal["groups"]:
            if not isinstance(group, dict) or not isinstance(group.get("name"), str) or not isinstance(group.get("items"), list):
                raise ValueError("Unexpected station format.")
            for item in group["items"]:
                if not isinstance(item, dict) or not isinstance(item.get("formalName") or item.get("name"), str):
                    raise ValueError("Unexpected item format.")
                if "allergens" in item and item["allergens"] is not None:
                    if not isinstance(item["allergens"], list) or any(not isinstance(a, dict) for a in item["allergens"]):
                        raise ValueError("Unexpected allergen format.")
                count += 1
    return count


def build(output, today, now, fetch_day):
    """Validate all dates before writing; a failed run never deploys a partial dataset."""
    timestamp = now.astimezone(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    snapshots = []
    for offset in range(-1, 15):
        day = (today + dt.timedelta(days=offset)).isoformat()
        meals = fetch_day(day)
        count = validate_menu(meals)
        snapshots.append((day, {"schemaVersion": 1, "date": day, "updatedAt": timestamp, "source": SOURCE, "meals": meals}, count))
        print(f"{day}: {len(meals)} meals, {count} dishes")
    api = Path(output) / "api"
    api.mkdir(parents=True, exist_ok=True)
    current_dates = {day for day, _, _ in snapshots}
    for path in api.glob("*.json"):
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", path.stem) and path.stem not in current_dates:
            path.unlink()
    for day, snapshot, _ in snapshots:
        (api / f"{day}.json").write_text(json.dumps(snapshot, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    manifest = {"schemaVersion": 1, "updatedAt": timestamp, "timezone": "America/Chicago", "source": SOURCE,
                "dates": [{"date": day, "file": f"api/{day}.json", "itemCount": count} for day, _, count in snapshots]}
    (Path(output) / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (Path(output) / ".nojekyll").touch()
    print(f"PASS: published {len(snapshots)} date snapshots; no upstream credentials included.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("_site"))
    parser.add_argument("--date", type=dt.date.fromisoformat)
    args = parser.parse_args()
    now = dt.datetime.now(dt.timezone.utc)
    today = args.date or now.astimezone(ZoneInfo("America/Chicago")).date()
    location, menu, key = discover()
    def fetch_day(day):
        url = f"https://api-prd.sodexomyway.net/v0.2/data/menu/{location}/{menu}?date={day}"
        return json.loads(load(url, {"API-Key": key, "Accept": "application/json"}))
    build(args.output, today, now, fetch_day)


if __name__ == "__main__":
    main()
