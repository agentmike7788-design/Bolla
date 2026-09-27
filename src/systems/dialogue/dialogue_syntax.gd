class_name DialogueSyntax
extends RefCounted
## Parsing helpers of the dialogue mini-language (docs/VERTICAL_SLICE_DESIGN.md §3.4), shared
## by DialogueConditions and DialogueActions: "key:a:b" splitting, integer / value arguments
## and the duck-typed context inventory. Stateless.


## "key:a:b" → "key"
static func key(text: String) -> String:
	return text.get_slice(":", 0).strip_edges()


## Arguments after the first colon, at most `max_parts` (the last keeps further colons).
static func parts(text: String, max_parts: int) -> PackedStringArray:
	var sep := text.find(":")
	if sep < 0:
		return PackedStringArray()
	var rest := text.substr(sep + 1)
	# split() treats maxsplit 0 as "unlimited", so a single part is taken as is.
	var out: PackedStringArray = [rest] if max_parts <= 1 else rest.split(":", true, max_parts - 1)
	for i: int in out.size():
		out[i] = out[i].strip_edges()
	return out


## Integer argument `index`; `default` when it is missing, null when it is not an integer.
static func int_arg(p: PackedStringArray, index: int, default: Variant) -> Variant:
	if index >= p.size():
		return default
	return p[index].to_int() if p[index].is_valid_int() else null


static func has_name(p: PackedStringArray, text: String) -> bool:
	if p.is_empty() or p[0] == "":
		push_warning("[DialogueRunner] '%s': missing name" % text)
		return false
	return true


## "true"/"false" → bool, integers → int, decimals → float, anything else stays String.
static func parse_value(text: String) -> Variant:
	var lower := text.to_lower()
	if lower == "true" or lower == "false":
		return lower == "true"
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text


static func truthy(value: Variant) -> bool:
	return true if value else false


## context.inventory if it is a live object with `method` (Inventory or a test double).
static func inventory(context: Dictionary, method: StringName) -> Object:
	var inv: Variant = context.get("inventory")
	if is_instance_valid(inv) and (inv as Object).has_method(method):
		return inv
	push_warning("[DialogueRunner] context has no inventory with %s()" % method)
	return null
