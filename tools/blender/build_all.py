"""Build every asset.  Usage:  python tools/blender/build_all.py [module ...]
Modules that do not exist (yet) are skipped with a note."""
import importlib
import importlib.util
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

MODULES = ["asset_gravestones", "asset_environment", "asset_buildings", "asset_props", "asset_character",
           "asset_carter", "asset_props_slice", "asset_items", "asset_ground_graveyard"]

skipped = []
for name in (sys.argv[1:] or MODULES):
    if importlib.util.find_spec(name) is None:
        print(f"== {name}: module not found, skipped")
        skipped.append(name)
        continue
    print(f"== {name}")
    importlib.import_module(name).build()
print("BUILD DONE" + (f" (skipped: {', '.join(skipped)})" if skipped else ""))
