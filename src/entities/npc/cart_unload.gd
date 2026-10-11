class_name CartUnload
extends RefCounted
## G8 Runde 3: Osric's unloading at the bier as a pure function of the clock (like every Npc pose – a load or a
## skip shows the same as watching it happen). In the unload_minutes before CorpseTables.delivery_minute he steps
## from the handles to the side of the cart that faces the bier, lifts the dead off the cart, carries them over and
## lays them onto the bier's slot; with several corpses one after the other (one share each, a bier each). After the
## delivery he walks back to the handles in return_minutes. Values: CartDeliveryConfig. Only positions and
## orientations – the Npc moves its figure (Model) and the cargo nodes, the CorpseManager delivers at the end.

const ANIM_WALK := &"walk"
const ANIM_LIFT := &"load_lift"
const ANIM_CARRY := &"carry_walk"
const ANIM_LOWER := &"load_lower"
const ANIM_RING := &"ring_bell"
const EPSILON := 0.0001


## The pose at `minute_f` (minute of day with fraction). `cargo`: world transforms of the corpses on the cart that
## are unloaded today (in order), `biers`: the bier slot of each (world), `handles`: where he stands at the cart (the
## Npc root), `root_yaw` its heading, `cart_center` / `cart_axis`: the cart's slot and long axis (world). After the
## delivery (`delivered` corpses > 0) the walk back starts at the bier `return_bier`, the corpse lay as `cargo_rest`.
## `bell`: the gate bell's hanging point (world, Vector3; null = no bell) – after the delivery he walks round the
## bier's end to it and rings it (CartDeliveryConfig.ring_bell) before he goes back to the handles.
## Returns {active, figure (world), yaw (world), anim, anim_t (one-shot 0..1, -1 = loop), speed (m per game minute),
## index (corpse in his hands / moving, -1 = none), corpse (its world transform), laid (corpses already on biers),
## ringing (at the bell)}.
static func pose(cfg: CartDeliveryConfig, minute_f: float, delivery_minute: int, cargo: Array[Transform3D],
		biers: Array[Transform3D], handles: Vector3, root_yaw: float, cart_center: Vector3, cart_axis: Vector3,
		delivered: int = 0, return_bier: Transform3D = Transform3D.IDENTITY, cargo_rest: Transform3D = Transform3D.IDENTITY,
		bell: Variant = null) -> Dictionary:
	var out := {"active": false, "figure": handles, "yaw": root_yaw, "anim": &"", "anim_t": -1.0, "speed": 0.0,
			"index": -1, "corpse": Transform3D.IDENTITY, "laid": 0, "ringing": false}
	if cfg == null:
		return out
	var minutes := float(maxi(cfg.unload_minutes, 1))
	var start := float(cfg.unload_start(delivery_minute))
	var count := mini(cargo.size(), biers.size())
	if minute_f >= start and minute_f < float(delivery_minute) and count > 0:
		return _unloading(cfg, (minute_f - start) / minutes, minutes, count, cargo, biers, handles, root_yaw, cart_center, cart_axis, out)
	var with_bell := bell is Vector3 and cfg.ring_bell
	var after := cfg.after_minutes(with_bell)
	var since := minute_f - float(delivery_minute)
	if delivered > 0 and after > 0.0 and since >= 0.0 and since < after:
		var spot := _spots(cfg, cargo_rest, return_bier, handles, cart_center, cart_axis)
		var from: Vector3 = spot.stand
		var from_yaw: float = spot.bier_yaw
		out.active = true
		out.laid = delivered
		if with_bell:
			var at_bell := bell_spot(cfg, bell as Vector3, handles)
			var walk := maxf(cfg.bell_walk_minutes, 0.0)
			var ring := maxf(cfg.bell_ring_minutes, 0.0)
			if since < walk:
				var route := PackedVector3Array([from, _corner(cfg, return_bier, from, at_bell.spot), at_bell.spot])
				_walk_route(out, route, since / walk, walk, from_yaw, float(at_bell.yaw))
				return out
			if since < walk + ring:
				out.figure = at_bell.spot
				out.yaw = at_bell.yaw
				out.anim = ANIM_RING
				out.anim_t = (since - walk) / maxf(ring, EPSILON)
				out.ringing = true
				return out
			since -= walk + ring
			from = at_bell.spot
			from_yaw = at_bell.yaw
		var back := float(maxi(cfg.return_minutes, 0))
		var t := since / maxf(back, EPSILON)
		var motion := _yaw_to(from, handles, root_yaw)
		out.figure = from.lerp(handles, t)
		out.yaw = lerp_angle(lerp_angle(from_yaw, motion, smoothstep(0.0, 0.25, t)), root_yaw, smoothstep(0.7, 1.0, t))
		out.anim = ANIM_WALK
		out.speed = _flat(handles - from).length() / maxf(back, EPSILON)
	return out


## Under the gate bell: `bell` (its hanging point, world) moved bell_stand_distance towards the handles, on the
## ground; he faces the bell. {spot, yaw}.
static func bell_spot(cfg: CartDeliveryConfig, bell: Vector3, handles: Vector3) -> Dictionary:
	var to := _flat(handles - bell)
	var dir := to.normalized() if to.length_squared() > EPSILON else Vector3.BACK
	var spot := _ground(bell, handles) + dir * cfg.bell_stand_distance
	return {"spot": spot, "yaw": _yaw_of(-dir, 0.0)}


## The corner round the bier's end on the way from his place at the bier (`stand`) to `target`: along the bier's
## long axis by bell_corner_offset, to the side of the target.
static func _corner(cfg: CartDeliveryConfig, bier: Transform3D, stand: Vector3, target: Vector3) -> Vector3:
	var axis := _flat(bier.basis.x)
	axis = axis.normalized() if axis.length_squared() > EPSILON else Vector3.RIGHT
	var side := 1.0 if _flat(target - stand).dot(axis) >= 0.0 else -1.0
	return stand + axis * side * cfg.bell_corner_offset


## Walks the polyline `route` (by arc length, `t` 0..1, `minutes` long): turns from `from_yaw` into the walk and at
## the end to `to_yaw`.
static func _walk_route(out: Dictionary, route: PackedVector3Array, t: float, minutes: float, from_yaw: float, to_yaw: float) -> void:
	var lengths := PackedFloat32Array([0.0])
	for k: int in range(1, route.size()):
		lengths.append(lengths[k - 1] + _flat(route[k] - route[k - 1]).length())
	var total := lengths[lengths.size() - 1]
	var s := clampf(t, 0.0, 1.0) * total
	var pos := route[route.size() - 1]
	var motion := to_yaw
	for k: int in range(1, route.size()):
		if s <= lengths[k] or k == route.size() - 1:
			var seg := lengths[k] - lengths[k - 1]
			pos = route[k - 1].lerp(route[k], clampf((s - lengths[k - 1]) / seg, 0.0, 1.0) if seg > EPSILON else 1.0)
			motion = _yaw_to(route[k - 1], route[k], to_yaw)
			break
	out.figure = pos
	out.yaw = lerp_angle(lerp_angle(from_yaw, motion, smoothstep(0.0, 0.12, t)), to_yaw, smoothstep(0.85, 1.0, t))
	out.anim = ANIM_WALK
	out.speed = total / maxf(minutes, EPSILON)


## Spots for one corpse: the side of the cart facing the bier, the yaw there (towards the cart), the carry sign
## (+1: the corpse's +X along his figure's +X), the stand in front of the bier and his yaw there.
static func _spots(cfg: CartDeliveryConfig, on_cart: Transform3D, bier: Transform3D, handles: Vector3,
		cart_center: Vector3, cart_axis: Vector3) -> Dictionary:
	var axis := _flat(cart_axis)
	axis = axis.normalized() if axis.length_squared() > EPSILON else Vector3.FORWARD
	var side := Vector3.UP.cross(axis).normalized()
	if _flat(bier.origin - cart_center).dot(side) < 0.0:
		side = -side
	var at_cart := _ground(cart_center, handles) + side * cfg.cart_side_distance
	var cart_yaw := _yaw_of(-side, 0.0)
	var sign := 1.0 if _flat(on_cart.basis.x).dot(figure_x(cart_yaw)) >= 0.0 else -1.0
	var bx := _flat(bier.basis.x)
	bx = bx.normalized() if bx.length_squared() > EPSILON else Vector3.RIGHT
	# figure_x(yaw) · sign = the bier's +X: cos(yaw) = sign·bx.x, −sin(yaw) = sign·bx.z
	var bier_yaw := atan2(-sign * bx.z, sign * bx.x)
	var stand := _ground(bier.origin, handles) - forward(bier_yaw) * cfg.bier_side_distance
	return {"cart": at_cart, "cart_yaw": cart_yaw, "sign": sign, "stand": stand, "bier_yaw": bier_yaw}


static func _unloading(cfg: CartDeliveryConfig, u: float, minutes: float, count: int, cargo: Array[Transform3D],
		biers: Array[Transform3D], handles: Vector3, root_yaw: float, cart_center: Vector3, cart_axis: Vector3, out: Dictionary) -> Dictionary:
	var k := mini(int(floor(u * count)), count - 1)
	var v := clampf(u * count - k, 0.0, 1.0)
	var per := minutes / count
	var sh := cfg.shares()
	var spot := _spots(cfg, cargo[k], biers[k], handles, cart_center, cart_axis)
	var prev := handles
	var prev_yaw := root_yaw
	if k > 0:
		var before := _spots(cfg, cargo[k - 1], biers[k - 1], handles, cart_center, cart_axis)
		prev = before.stand
		prev_yaw = before.bier_yaw
	var cart: Vector3 = spot.cart
	var stand: Vector3 = spot.stand
	var cart_yaw: float = spot.cart_yaw
	var bier_yaw: float = spot.bier_yaw
	var sign: float = spot.sign
	out.active = true
	out.laid = k
	var a := sh[0]
	var b := sh[0] + sh[1]
	var c := b + sh[2]
	if v < a:
		var t := v / maxf(a, EPSILON)
		var motion := _yaw_to(prev, cart, prev_yaw)
		out.figure = prev.lerp(cart, t)
		out.yaw = lerp_angle(lerp_angle(prev_yaw, motion, smoothstep(0.0, 0.25, t)), cart_yaw, smoothstep(0.55, 1.0, t))
		out.anim = ANIM_WALK
		out.speed = _flat(cart - prev).length() / maxf(sh[0] * per, EPSILON)
	elif v < b:
		var t := (v - a) / maxf(sh[1], EPSILON)
		out.figure = cart
		out.yaw = cart_yaw
		out.anim = ANIM_LIFT
		out.anim_t = t
		out.index = k
		var w := smoothstep(cfg.lift_move_from, cfg.lift_move_to, t)
		out.corpse = _between(cargo[k], carry_transform(cfg, cart, cart_yaw, sign), w, cfg.arc_height)
	elif v < c:
		var t := (v - b) / maxf(sh[2], EPSILON)
		var motion := _yaw_to(cart, stand, cart_yaw)
		var yaw := lerp_angle(lerp_angle(cart_yaw, motion, smoothstep(0.0, 0.3, t)), bier_yaw, smoothstep(0.6, 1.0, t))
		var at := cart.lerp(stand, t)
		out.figure = at
		out.yaw = yaw
		out.anim = ANIM_CARRY
		out.speed = _flat(stand - cart).length() / maxf(sh[2] * per, EPSILON)
		out.index = k
		out.corpse = carry_transform(cfg, at, yaw, sign)
	else:
		var t := (v - c) / maxf(sh[3], EPSILON)
		out.figure = stand
		out.yaw = bier_yaw
		out.anim = ANIM_LOWER
		out.anim_t = t
		out.index = k
		var w := smoothstep(cfg.lower_move_from, cfg.lower_move_to, t)
		out.corpse = _between(carry_transform(cfg, stand, bier_yaw, sign), biers[k], w, cfg.arc_height)
	return out


## The dead in his arms: in front of the figure at `pos` turned to `yaw`, lying across his arms (+X along the
## figure's ±X).
static func carry_transform(cfg: CartDeliveryConfig, pos: Vector3, yaw: float, sign: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw if sign >= 0.0 else yaw + PI)
	return Transform3D(basis, pos + forward(yaw) * cfg.carry_forward + Vector3.UP * cfg.carry_height)


## The figure's facing (+Z of a yaw) and its +X.
static func forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


static func figure_x(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


static func _between(a: Transform3D, b: Transform3D, w: float, arc: float) -> Transform3D:
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), w)
	var origin := a.origin.lerp(b.origin, w) + Vector3.UP * arc * sin(PI * w)
	return Transform3D(Basis(q), origin)


static func _yaw_to(from: Vector3, to: Vector3, fallback: float) -> float:
	return _yaw_of(to - from, fallback)


static func _yaw_of(v: Vector3, fallback: float) -> float:
	var f := _flat(v)
	return atan2(f.x, f.z) if f.length_squared() > EPSILON else fallback


static func _ground(p: Vector3, handles: Vector3) -> Vector3:
	return Vector3(p.x, handles.y, p.z)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
