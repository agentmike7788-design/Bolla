class_name WishlistData
extends Resource
## The open wish list (docs/PHASE10_DESIGN.md §2.3 Grundsatz 2, §3.4): data/economy/wishlist.tres (P1) – the lasting,
## sensible purchases (stations, levels, tools, decor, mortsafes, gold, rose bushes, market goods). At the checkpoints
## (day 14, 30, 45, 60, 75, 91) the ones not yet owned and available must cost ≥ 1.3 × the income of the next 14 days.

@export var entries: Array[WishlistEntryData] = []
