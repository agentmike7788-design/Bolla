class_name WishlistProbe
extends RefCounted
## STUB (P1) – tests / debug only (docs/PHASE10_DESIGN.md §2.3 Grundsatz 2, §3.4, §6 `wish`, §10.3 curve10): the sum of
## the lasting purchases of the wish list (data/economy/wishlist.tres) the player does not own yet and that are
## available (available_flag; per_grave entries count per occupied grave without it, at most max_count).
## W1 (P1) fills the body; the signature is the contract.


static func open_cost(_tree: SceneTree, _data: WishlistData) -> int:
	return 0
