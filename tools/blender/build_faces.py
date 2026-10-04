"""Rebuild every figure that carries a lib_faces head (G7 Änderungsrunde 1): the gravekeeper, Osric,
Ilse, the ghost and the laid-out corpses (the villagers: build_all.py asset_villagers).
Usage:  python tools/blender/build_faces.py [heroes] [ghost] [corpses]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

what = set(sys.argv[1:]) or {"heroes", "ghost", "corpses"}
if "heroes" in what:
    import asset_character
    import asset_carter
    import asset_trader
    asset_character.build()
    asset_carter.build()
    asset_trader.build()
if "ghost" in what:
    import asset_ghost
    asset_ghost.build()
if "corpses" in what:
    import asset_props_slice
    import asset_corpses_phase4
    asset_props_slice.build(["corpse", "corpse_02", "corpse_03", "corpse_04", "corpse_shrouded"])
    asset_corpses_phase4.build()
print("FACES DONE")
