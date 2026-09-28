class_name StoneDesignRules
extends RefCounted
## Pure rules of a designed gravestone (docs/PHASE5_DESIGN.md §2.5, §3.4): fitting inscriptions,
## the rendered text, marker points, breakdown lines, material and minutes. Shapes, inscriptions
## and ornaments come from Database (data/stone/**); all points / minutes from the data files and
## StoneConfig.

const LABEL_INSCRIPTION := "Inschrift"
const LABEL_FITTING := "Passende Inschrift"
const LABEL_GILDED := "Vergoldet"
const LABEL_ORNAMENT := "Zierde: %s"
const BORN := "* %d"
const DIED := "† %s"
## The register marks an uncertain name with this suffix – never carved (§2.5).
const UNCERTAIN_SUFFIX := " (?)"
## Names longer than this wrap into two lines (§2.5).
const WRAP_CHARS := 22
const MAX_LINES := 4
const MINUTES_PER_DAY := 1440


## Template fits the dead (cause, age or story); i_rest (no conditions) never fits.
static func fits(ins: InscriptionData, corpse: CorpseRecord) -> bool:
	if ins == null or corpse == null:
		return false
	if corpse.cause_id != &"" and corpse.cause_id in ins.fits_causes:
		return true
	if corpse.story_id != &"" and corpse.story_id in ins.fits_story:
		return true
	var has_age := ins.fits_min_age >= 0 or ins.fits_max_age >= 0
	if has_age and corpse.age > 0:
		var low := ins.fits_min_age < 0 or corpse.age >= ins.fits_min_age
		var high := ins.fits_max_age < 0 or corpse.age <= ins.fits_max_age
		return low and high
	return false


## Lines with {name} {born} {died} {age} filled in: {name} = register name without " (?)" (names
## > WRAP_CHARS wrap into two lines), {born} = "* <death year − age>", {died} = "† <date>" of the
## arrival day (buried_day without arrival). At most MAX_LINES lines.
static func render_text(ins: InscriptionData, corpse: CorpseRecord, cfg: StoneConfig) -> PackedStringArray:
	var out := PackedStringArray()
	if ins == null or corpse == null:
		return out
	var death_day := death_day_of(corpse)
	var died := DIED % StoneCalendar.date_text(death_day, cfg)
	var born := BORN % (StoneCalendar.year_of(death_day, cfg) - maxi(corpse.age, 0))
	var name := carved_name(corpse)
	for template: String in ins.lines:
		if template.contains("{name}") and template.strip_edges() == "{name}":
			out.append_array(wrap_name(name))
			continue
		out.append(template.format({"name": name, "born": born, "died": died, "age": str(corpse.age)}))
	if out.size() > MAX_LINES:
		out.resize(MAX_LINES)
	return out


## Shape points + inscription + fitting + gilded (only with inscription) + ornament
## (stele ≤ 7, arch ≤ 8, master ≤ 9). Unknown shape → 0.
static func marker_points(design: StoneDesign, corpse: CorpseRecord, economy: EconomyConfig, cfg: StoneConfig) -> int:
	var total := 0
	for line: Dictionary in breakdown_lines(design, corpse, economy, cfg):
		total += int(line.points)
	return total


## [{label, points}] – "Meisterstein +5", "Inschrift +1", "Passende Inschrift +1", "Vergoldet +1",
## "Zierde: Holunderdolde +1". Empty for an empty / unknown shape.
static func breakdown_lines(design: StoneDesign, corpse: CorpseRecord, economy: EconomyConfig, cfg: StoneConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var eco := EconomyConfig.resolve(economy)
	var sc := _stone_config(cfg)
	if design == null or design.is_empty() or not eco.marker_quality.has(design.shape):
		return out
	var shape := Database.stone_shape(design.shape) as StoneShapeData
	out.append(_line(shape.display_name if shape != null and shape.display_name != "" else String(design.shape),
			eco.marker_quality[design.shape]))
	var ins := Database.inscription(design.inscription) as InscriptionData if design.inscription != &"" else null
	if ins != null:
		out.append(_line(LABEL_INSCRIPTION, sc.inscription_points))
		if fits(ins, corpse):
			out.append(_line(LABEL_FITTING, sc.fitting_points))
		if design.gilded:
			out.append(_line(LABEL_GILDED, sc.gilded_points))
	var orn := Database.ornament(design.ornament) as OrnamentData if design.ornament != &"" else null
	if orn != null:
		out.append(_line(LABEL_ORNAMENT % orn.display_name, orn.points))
	return out


## {item_id: amount} of shape + ink + gold leaf (gold only with an inscription).
static func inputs(design: StoneDesign, cfg: StoneConfig) -> Dictionary:
	var out := {}
	if design == null or design.is_empty():
		return out
	var sc := _stone_config(cfg)
	var shape := Database.stone_shape(design.shape) as StoneShapeData
	if shape != null:
		for id: StringName in shape.inputs:
			out[id] = int(out.get(id, 0)) + shape.inputs[id]
	if design.inscription != &"":
		out[sc.ink_item] = int(out.get(sc.ink_item, 0)) + sc.ink_amount
		if design.gilded:
			out[sc.gold_item] = int(out.get(sc.gold_item, 0)) + 1
	return out


## Shape + inscription + gilding + ornament minutes (master complete: 150 + 20 + 10 + 25 = 205).
static func minutes(design: StoneDesign, cfg: StoneConfig) -> int:
	if design == null or design.is_empty():
		return 0
	var sc := _stone_config(cfg)
	var shape := Database.stone_shape(design.shape) as StoneShapeData
	var total := shape.minutes if shape != null else 0
	if design.inscription != &"":
		total += sc.inscription_minutes
		if design.gilded:
			total += sc.gilding_minutes
	var orn := Database.ornament(design.ornament) as OrnamentData if design.ornament != &"" else null
	if orn != null:
		total += orn.minutes
	return total


## Marker points of the grave's current marker (cross 1, gravestone 3, designed = its sum; none 0).
static func current_marker_points(grave: GraveRecord, corpse: CorpseRecord, economy: EconomyConfig, cfg: StoneConfig) -> int:
	if grave == null or grave.state != GraveRecord.State.MARKED:
		return 0
	if not grave.design.is_empty():
		return marker_points(StoneDesign.from_dict(grave.design), corpse, economy, cfg)
	return int(EconomyConfig.resolve(economy).marker_quality.get(grave.marker_id, 0))


# --- helpers (public, not part of the contract) ------------------------------------------

## Game day of the death date: day of arrival_total_minutes, else buried_day, else day 1.
static func death_day_of(corpse: CorpseRecord) -> int:
	if corpse.arrival_total_minutes > 0:
		return floori(corpse.arrival_total_minutes / float(MINUTES_PER_DAY)) + 1
	return maxi(corpse.buried_day, 1)


## Register name without the uncertainty mark " (?)".
static func carved_name(corpse: CorpseRecord) -> String:
	var name := corpse.display_name.strip_edges()
	if name.ends_with(UNCERTAIN_SUFFIX.strip_edges()):
		name = name.trim_suffix(UNCERTAIN_SUFFIX.strip_edges()).strip_edges()
	return name


## One line, or two split at the space nearest the middle when longer than WRAP_CHARS.
static func wrap_name(name: String) -> PackedStringArray:
	if name.length() <= WRAP_CHARS or not name.contains(" "):
		return PackedStringArray([name])
	var mid := name.length() / 2.0
	var best := -1
	for i: int in name.length():
		if name[i] == " " and (best < 0 or absf(i - mid) < absf(best - mid)):
			best = i
	return PackedStringArray([name.substr(0, best).strip_edges(), name.substr(best + 1).strip_edges()])


## Whether `id` is a designed stone shape (no inventory item, only set via Stonemasonry).
static func is_shape(id: StringName) -> bool:
	return id != &"" and Database.stone_shape(id) != null


static func _line(label: String, points: int) -> Dictionary:
	return {"label": label, "points": points}


static func _stone_config(cfg: StoneConfig) -> StoneConfig:
	if cfg != null:
		return cfg
	var data := Database.config(&"stone_config") as StoneConfig
	return data if data != null else StoneConfig.new()
