"""Select the named XCTest screenshot rather than relaunching a possibly cloned simulator."""
import json
from pathlib import Path
import shutil
import sys

directory = Path(sys.argv[1]).resolve()
manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
attachments = [attachment for test in manifest for attachment in test.get("attachments", [])]
for prefix in ["03-filtered-after-relaunch", "01-menu"]:
    selected = next((item for item in attachments if item.get("suggestedHumanReadableName", "").startswith(prefix)), None)
    if selected:
        source = (directory / selected["exportedFileName"]).resolve()
        if source.parent != directory or source.suffix != ".png":
            raise ValueError("Unexpected screenshot path.")
        destination = Path(sys.argv[2])
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        print("Preview exported from XCTest:", prefix)
        break
else:
    print("No menu screenshot was captured; inspect the test logs.")
