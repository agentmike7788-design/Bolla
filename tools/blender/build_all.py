"""Build every art-prototype asset.  Usage:  python tools/blender/build_all.py [module ...]"""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

MODULES = ["asset_gravestones", "asset_environment", "asset_buildings", "asset_props", "asset_character"]

for name in (sys.argv[1:] or MODULES):
    print(f"== {name}")
    importlib.import_module(name).build()
print("BUILD DONE")
