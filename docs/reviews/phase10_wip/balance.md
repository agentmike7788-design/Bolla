# Phase 10 W1 – P1 Tarif & Zielkurve (Agent 14 + 02)

Stand: W1, Branch `vs/p10-p1` auf W0 (`926bffa`). Vertrag `docs/PHASE10_DESIGN.md` §2.3, §2.4, §2.9, §10.3, §14.7.
Gemessen auf dem P1-Stand **ohne** P2 (Gemeindekasse) und P4 (Markt) – was erst nach deren Merge nachgemessen wird, ist
mit **[nach P2]** / **[nach P4]** markiert.

## 1. Was P1 in die Daten gebracht hat

- E5 Ruf-Zuschlag „Gerühmt“ +3 → +2 (`reputation_config.pay_bonus`, Klassen-Default mit)
- E6 Aussegnung 3/5/7 → 3/5/6 (`chapel_config`)
- E8 kleine Bitten nach Arbeitsminuten: 1 bis 40 Min, 2 darüber (Tabelle der Minuten in `tariff_report.py` /
  `test_tariff_sheet.gd`); Ø 1,78 → **1,39** (Vertrag schätzte Ø 1,2 – die Regel ist bindend, der Ø folgt aus ihr)
- E9 große Bitten Tor 2–3 → 2, Dorf 3–5 → 3–4 (`hrv_bridge_stones` 5 → 4); Dinge als Lohn unverändert
- E11 Trinkgeld-Kappe 4 → 3 (`visitor_config`, Klassen-Default mit)
- E12 Ilse Zopf 4 → 3, Zähne 5 → 4 (`utilization_config.sell_prices`)
- E13 Wertsachen 5–8 → 4–7 (`corpse_tables`)
- E14 Quast Augen/Hand/Herz 11/12/9 → 10/11/8 (`anatomy_config.organs`, Klassen-Default mit – Phase-7-Gerüst prüft
  „geändert ⇒ Daten = Default“)
- A3 Honigkuchen 1 → 2 (`shops/grocer`)
- `data/economy/wishlist.tres` (17 Einträge: 4 Stationen, 8 Gebäudestufen, Gießkanne, Gold je Grab, Grabgitter je
  Grab (≤ 6), Rosenstock je Grab, Messinglaterne × 6) und `WishlistProbe.open_cost` (implementiert, in `IMPLEMENTED`)

**Bewusst nicht in den Daten (Grund siehe §3):**
- **E1 Pflegegeld → 0** bleibt bis zum Merge mit P2 (Friedhofsgeld). Ohne Friedhofsgeld bleibt die Gründer-Linie an
  Tag 20 mit 22 Münzen stehen (Esse 25 nicht bezahlbar, kein Grab frei, keine Einnahme mehr – gemessen, Kurve „ohne
  Gemeinde“). Der Patch für den Merge steht in §6.
- **A1 Steinbruchbrief 20 → 0 („Pachtbrief“)** liegt in `data/dialogue/carter.tres` und `test_dialogue.gd` (P5, Osric
  `p5_license` → Pachtbrief). Die Münzzahl gehört P1, der Dialog P5 – P5 setzt beides zusammen.
- **E12 Aufschlag „Abgebrüht“**: Der Ort ist `piety_config.buyer_bonus_by_tier` (1/1/0/0/0, je **Stück**), nicht
  `utilization_config`/`trader_config`. „+2 → +1“ in §2.4.1 meint je Leiche (Zopf + Zähne). Eine halbe Münze je Stück
  gibt es nicht; die Senkung kommt schon über die Grundpreise (je Leiche 9+2 → 7+2). **Offen für den Lead:**
  so lassen (Vorschlag) oder nur „Hartherzig“ +1 (1/0/0/0/0).

## 2. Tarifblatt (erzeugt)

<!-- tarifblatt:begin (tools/economy/tariff_report.py) -->
| # | Posten | Ort (`data/…`) | G9 | Phase 10 (Vertrag) | Daten | Stand |
|---|---|---|---|---|---|---|
| E1 | Pflegegeld je Tag nach Ruf | config/reputation_config `stipend` | 0/1/2/3/4 | 0/0/0/0/0 | 0/1/2/3/4 | mit P2 |
| E1b | Pflegegeld-Kappe | config/reputation_config `stipend_purse_cap` | 80 | 0 | 80 | mit P2 |
| E2 | Friedhofsgeld je Stufe/Woche | config/treasury_config `tier_pay` | – | 0/4/7/10/12 | 0/4/7/10/12 | ✓ |
| E2b | Pflegezuschlag ab Anteil · Kappe | config/treasury_config `care_steps`, `quality_cap` | – | 0,5/0,75/0,95/15 | 0,5/0,75/0,95/15 | ✓ |
| E2c | Bedarfszulage Schwelle/Teiler/Kappe | config/treasury_config `need_*` | – | 60/4/15 | 60/4/15 | ✓ |
| E2d | Notgroschen bis/Kappe | config/treasury_config `hardship_*` | – | 10/8 | 10/8 | ✓ |
| E3 | Bestattungslohn Grund | corpses/corpse_tables `base_payment` | 2–4 | 2–4 | 2–4 | ✓ |
| E4 | Lohn je Qualitätspunkt | config/economy_config `payment_per_quality` | 0,5 | 0,5 | 0,5 | ✓ |
| E5 | Ruf-Zuschlag auf den Lohn | config/reputation_config `pay_bonus` | -2/0/1/2/3 | -2/0/1/2/2 | -2/0/1/2/2 | ✓ |
| E6 | Aussegnung Kapelle 1/2/3 | config/chapel_config `service_fee_by_level` | 3/5/7 | 3/5/6 | 3/5/6 | ✓ |
| E7 | Umbettgeld · Geistergabe | config/crypt_config `reinter_fee`, ghost_config `gift_coins` | 4/2 | 4/2 | 4/2 | ✓ |
| E7b | Weihe fremd/bekannt/vertraut/befreundet | config/village_config `consecration_price_by_tier` | 10/10/5/0 | 10/10/5/0 | 10/10/5/0 | ✓ |
| E8 | Kleine Bitten | hill_requests/hr_* `reward_coins` | 1–3 (Ø 1,78) | 1–2: 1 bis 40 Min Arbeit, 2 länger | 1–2 (Ø 1,39) | ✓ |
| E9 | Große Bitten Tor | hill_requests/large/hrl_* `reward_coins` | 2–3 | 2 | 2 | ✓ |
| E9b | Große Bitten Dorf | hill_requests/large/hrv_* `reward_coins` | 3–5 | 3–4 | 3–4 | ✓ |
| E10 | Aufträge im Dorf | orders/o_*, ob_* `reward_coins` | 3–11 | 3–11 | 3–11 | ✓ |
| E11 | Trinkgeld-Kappe je Tag | config/visitor_config `tip_cap_day` | 4 | 3 | 3 | ✓ |
| E11b | Opferstock je Besuch · Kappe/Tag | config/visitor_config `poor_box_*` | – | 1/2 | 1/2 | ✓ |
| E12 | Ilse: Zopf · Zähne | config/utilization_config `sell_prices` | 4/5 | 3/4 | 3/4 | ✓ |
| E12b | Ilse: Aufschlag je Stück nach Pietät | config/piety_config `buyer_bonus_by_tier` | 1/1/0/0/0 | 1/1/0/0/0 | 1/1/0/0/0 | ✓ |
| E13 | Wertsachen im Saum | corpses/corpse_tables `valuables_coins_*` | 5–8 | 4–7 | 4–7 | ✓ |
| E14 | Quast: Augen · Hand · Herz | config/anatomy_config `organs.*.base_price` | 11/12/9 | 10/11/8 | 10/11/8 | ✓ |
| E14b | Vorlesungshonorar | config/anatomy_config `lecture.fee` | 4 | 4 | 4 | ✓ |
| E15 | Brenneisen: Kladde · Schweigen | config/stranger_config `kladde_price`, `bribe_coins` | 40/15 | 40/15 | 40/15 | ✓ |
| E17 | Läden kaufen an | shops/* `buys.price` | 1–8 | 1–8 | 1–8 | ✓ |
| E18 | Eigener Stand: Grundwerte | market/wares/* | – | wooden_cross 4 · herbs 1 · herb_bundle 3 · grave_candle 1 · wax_wreath 6 | – | P4 |
| A1 | Steinbruchbrief → Pachtbrief | dialogue/carter `p5_license` | 20 | 0 | 20 | P5 |
| A2 | Stationen Esse/Webstuhl/Steinmetz/Pult | stations/* `build_coins` | 25/10/15/12 | 25/10/15/12 | 25/10/15/12 | ✓ |
| A2b | Gebäude je Stufe | buildings/* `levels.coins` | shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35 | shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35 | shed 10/15/20 · chapel 25/30/40 · crypt 0/35/35 | ✓ |
| A3 | Honigkuchen (Theres) | shops/grocer `honey_cake` | 1 | 2 | 2 | ✓ |
| A3b | Grabgitter (Esch) | shops/smith `mortsafe` | 12 | 12 | 12 | ✓ |
| A4 | Lehrling je Tag | config/apprentice_config `wage` | 3 | 3 | 3 | ✓ |
| A5 | Runde · Spendenschritt · Postgeld | config/village_config `round_price`, `donation_step`, letters_config `postage` | 5/5/1 | 5/5/1 | 5/5/1 | ✓ |
| A6 | Ilses Nachtware Leinen/Wacholder/Gold | config/trader_config `shop` | 2/1/6 | 2/1/6 | 2/1/6 | ✓ |
| A7 | Pacht je Monat | config/treasury_config `rent` | – | 8 | 8 | ✓ |
| A8 | Zehnt % · Kappe | config/treasury_config `tithe_*` | – | 10/25 | 10/25 | ✓ |
| A9 | Schätzung % · ab · Kappe | config/treasury_config `estimate_*` | – | 10/20/15 | 10/20/15 | ✓ |
| A10 | Standgeld je Markttag | config/market_config `stall_fee` | – | 1 | 1 | ✓ |
| A11 | Rosenstock · Messinglaterne (Agathe) | market/stalls/ms_agathe | – | 12/10 | – | P4 |
<!-- tarifblatt:end -->

Erzeugen/prüfen: `python3 tools/economy/tariff_report.py --update=docs/reviews/phase10_wip/balance.md` (`--check`:
Exit 1, wenn eine P1-Zeile der Daten vom Vertrag abweicht). `tests/unit/test_tariff_sheet.gd` liest dieselben Werte aus
den geladenen Ressourcen und vergleicht sie Zeile für Zeile mit diesem Block.

## 3. Zielkurve `curve10` (Ist vs. Ziel „gemütlich knapp“)

Werkzeug: `tests/integration/economy_curve_bot.gd` (`EconomyCurveBot`: Kette founder → founder7 → founder8 → founder9,
Übergaben wie W0; neu: `BANDS`/`checks()` nach §2.3, Wunschliste je Morgen, `ParishEmu`) ·
`tests/integration/test_economy_curve.gd` (immer: Bänder an einer synthetischen Kurve, kurzer Lauf bis zum ersten
Friedhofsgeld; `P10_CURVE=1`: die ganze Kette, `P10_CURVE_STRICT=1`: die §2.3-Bänder als Assertion – W3).

**`ParishEmu` (nur Messung, bis P2):** zahlt das Friedhofsgeld genau nach §2.5.2 mit den Daten aus
`treasury_config.tres` (Schau So 18:00 aus `Graveyard.rating()`, Pflegeanteil = belegte Gräber ohne Unkraut/Laub, ohne
welke Blumen, nicht aufgewühlt; Bedarf, Notgroschen, erste Woche anteilig; Auszahlung Mo 07:40 als
`payment_received("Friedhofsgeld")`) und schaltet das Pflegegeld ab. Sobald `Systems/Treasury` in der Welt hängt, tritt
sie zur Seite. Damit ist „ganzer Tarif ohne Markt und ohne Abgaben“ messbar.

Drei Läufe (neues Spiel → Tag 91, morgens):

| Prüfpunkt | W0 Ist (G9-Tarif, founder8 hängt) | P1-Stand (Tarif ohne E1) | **P1 + Friedhofsgeld (E1/E2)** | Ziel §2.3 |
|---|---|---|---|---|
| Tag 14 | 35 | 31 | **26** | 30–60 |
| Tag 30 | 20 | 22 | **15** | – (P5 min ≥ 10) |
| Tag 45 | 78 | 64 | **54** | – |
| Tag 60 | 21 | 81 | **67** | – |
| Tag 75 | 12 | 84 | **93** | 30–85 |
| Tag 91 | 9 | 82 | **95** | 30–90 |
| Kapitel bis Tag 91 | 4 (founder8 0/6 Schritte) | **6** (Kap. 8 Tag 48, Kap. 9 vor Tag 60) | **6** (Kap. 8 Tag 47) | 6 |
| morgens min. | 1 (Tag 87) | 5 | **4** (Tag 35) | ≥ 5, würdevoll ≥ 8 ab Tag 7 |

Abschnitte, Lauf **P1 + Friedhofsgeld** (Ist vs. Ziel):

| Abschnitt | Tage | Polster morgens | Δ (Ziel) | Ausgabequote (Ziel) | min. | Einnahmen (größte) | Ausgaben (größte) |
|---|---|---|---|---|---|---|---|
| P2–3 | 1–14 | 5…51 ✓ | +19 ✗ (+25…+55) | 91 % ✓ (≥ 60) | 5 | Bestattung 142, Friedhofsgeld 36, Gaben 28 | Osric 110, Ilse 47, Brief 20 |
| P4 | 15–24 | 10…30 ✗ (25–100) | −4 ✗ (+20…+50) | 103 % ✓ | 10 | Bestattung 72, Friedhofsgeld 25 | Bau 40, Gebäude 35, Ilse 34 |
| P5 | 20–30 | 7…45 ✗ (10–80) | −13 ✗ (−60…−20) | 109 % ✓ | 12 | Bestattung 66, Friedhofsgeld 23, Umbetten 20 | Gebäude 115 |
| P6 | 30–40 | 4…53 ✗ (10–60) | +33 ✗ (0…+25) | 87 % ✓ | 4 ✗ | Bestattung 81, Aufträge 54, Friedhofsgeld 44 | Spenden 50, Runden 35, Gebäude 35 |
| P7 | 40–53 | 15…76 ✗ (15–70) | +23 ✓ | 92 % ✓ | 15 | Bestattung 116, Aussegnung 35, Friedhofsgeld 32 | Dorf 66, Ilse 48, Gebäude 40 |
| P8 | 53–63 | 53…82 ✗ (25–80) | +26 ✗ (0…+20) | 73 % ✗ (≥ 80) | 53 | Friedhofsgeld 30, Trinkgeld 21, Aufträge 18 | Dorf 30, Lehrling 27 |
| P9 | 63–75 | 75…93 ✗ (30–85) | +10 ✓ | 87 % ✓ | 75 | Friedhofsgeld 30, Aufträge 22 | Lehrling 33, Dorf 20 |
| P10 | 75–91 | 75…98 ✗ (30–90) | −2 ✓ (−20…+15) | 102 % ✓ | 75 | Friedhofsgeld 30, Aufträge 26, Trinkgeld 24 | Lehrling 45, Dorf 28 |

Wunschliste (Grundsatz 2, offen ÷ Einnahmen der nächsten 14 Tage): Tag 14 **0,6×** ✗ · Tag 30 1,9× · Tag 45 3,7× ·
Tag 60 9,8× · Tag 75 11,5× · Tag 91 ✓ (Ziel ≥ 1,3×).

Friedhofsgeld je Woche (Emulation): 10 · 26 · 25 · 23 · 29 · 15 · 17 · 15 · 15 · 15 · 15 · 15 · 15 – früh trägt die
Bedarfszulage (Polster < 60), ab Tag 52 nur noch Qualitätsgeld (Ehrwürdig 12 + Pflege 3 = Kappe 15).

**Befund:**
1. **Früh (Tag 1–40) zu knapp, spät (ab Tag 53) zu reich.** Der neue Tarif nimmt früh ≈ 5–10 Münzen (Pflegegeld →
   Friedhofsgeld wöchentlich, Bitten, Wertsachen, Ruf-Zuschlag) und lässt spät das Polster bei ≈ 80–95 stehen, weil die
   Senken des Vertrags (Markt, Rosen, Laterne, Pacht, Zehnt) noch fehlen **[nach P2]** **[nach P4]** **[W3 founder10]**.
2. **Die frühen Ziel-Bänder (P4 Δ +20…+50, P5 Δ −60…−20) verfehlt schon der G9-Tarif** auf dieser Kette (W0: +17,
   −6): sie stammen von den Fixture-Bots (`reverent`, `reverent5`), nicht von der Gründer-Linie. Die Stufe P4/P5 der
   Gründer-Linie kauft den Steinbruchbrief (20) in P4 – mit A1 (Pachtbrief 0, **[nach P5]**) steigen P4 und Tag 30 um ≈ 20.
3. **Tag 14 (26 statt 30–60)** und **Tag 35 (4 statt ≥ 8)**: nach A1 erneut messen. Bleibt es darunter, gilt §2.4.4
   Schritt 1 (P2-Daten): Bedarfsschwelle 60 → 70 (≈ +2/Woche bei Polster < 60) – **Vorschlag an P2, nicht umgesetzt**.
4. **Grundsatz 2 an Tag 14 unerfüllbar mit bleibenden Gütern:** Vor `workshop_open` gibt es nichts Bleibendes zu kaufen
   (die Liste hat dann nur das Gold je Grab). Vorschlag (Lead/Benutzer): Prüfpunkt 14 nur für Grundsatz 1 werten oder
   frühe Zier/Werkzeuge mit Münzpreis in die Liste, sobald es sie gibt.
5. Spätspiel: die Kappe 15 zahlt bei Ehrwürdig schon 15/Woche ≈ 2,1/Tag (§2.4.1 „spät ≈ 2/Tag“ ✓); dass das Polster
   trotzdem steigt, liegt an fehlenden Senken – genau das sollen Markt und Abgaben tragen (§2.9).


## 4. W0-Befund 12/2 geklärt: `founder8` nimmt keinen Freundschaftsschritt

**Ursache (Inhalt + Bot):** Die Dorfmenüs bieten die Gegengefallen der Phase 8 („[Gegengefallen] Kräuterbündel“,
„[Gegengefallen] Garn für den Laden“ …, Aufträge `of_*_return_*`, Kategorie `friend`) über `order_offerable:<id>` als
gewöhnliche Aufträge an – **ohne geschuldeten Gefallen und schon vor `p8_open`**. `OrderRules.friend_block_reason` prüft
nur „angenommen / requires_flag / Freundes-Limit“. Auf der Kurven-Kette öffnet das Dorf an Tag 28 (Fixture-Linie: 37);
`founder7` (Phase7Bot, kennt keine Freundes-Aufträge) nimmt sie an (`of_quast_return_1` 2 Kräuterbündel,
`of_mangold_return_2` 4 Garn) und liefert sie nie. So angenommen laufen sie **nie ab** (kein `days_limit`, nicht über
`Friendship._owed`) und belegen beide Plätze von `Orders.max_active_friend` (2). Danach scheitert jedes
„[Geschichte] … Das mache ich.“ von `founder8` **still**: `Friendship.step_block_reason` sagt „“, weil `_ctx`/`_order_ok`
das Freundes-Limit nicht kennen; `accept_step` → `Orders.accept` → „Zwei Bitten von Freunden laufen schon.“ → false.
Belegt mit `diag` an der Übergabe Tag 39: `active [o_lenz_service, of_mangold_return_2, of_quast_return_1]`,
`block_reason(of_fenner_1) = "Zwei Bitten von Freunden laufen schon."` für alle fünf Erzähler.

**Fix im Bot (P1, `economy_curve_bot.gd`):** `FounderBot7._pick7` lässt Wahlen mit `order_accept` eines
Freundes-Auftrags aus (wie `Phase8Bot._vetoed` ab `p8_open`; über `_pick7`, damit auch die Vorausschau sie nicht nimmt).
Ergebnis: Kapitel 8 an Tag 47/48, Kapitel 9 vor Tag 60, alle sechs Kapitel bis Tag 91 (vorher 4).

**Spielfehler außerhalb von P1 (Patch-Vorschlag, Besitz Lead/P5 – nicht umgesetzt):**
1. *Spieler sieht einen Schritt, der nichts tut:* `src/systems/friendship/friendship.gd` – das Freundes-Limit gehört in
   den Grund, warum ein Schritt nicht angeboten wird:
   ```gdscript
   func step_block_reason(npc_id: StringName) -> String:
   	var why := FriendRules.step_block_reason(story(npc_id), _ctx(npc_id))
   	if why == "":
   		var orders := _first(ORDERS_GROUP)
   		if orders != null and orders.has_method(&"block_reason") and step_order(npc_id) != &"":
   			var r := str(orders.call(&"block_reason", step_order(npc_id)))
   			if r != "":
   				return r   # z. B. „Zwei Bitten von Freunden laufen schon.“
   	return why
   ```
   (`offerable_step` analog, damit die Bedingung `step_offerable:<npc>` im Dialog dieselbe Antwort gibt.)
2. *Gegengefallen ohne Gefallen:* entweder in `data/dialogue/v_*.tres` (P5) die Wahlen „[Gegengefallen] <Titel>“ mit
   `order_offerable:of_*_return_*` streichen bzw. an `favor_owed:<npc>` binden (die echten Gegengefallen kommen ohnehin
   über `Friendship.apply_morning` → `Orders.accept_owed`), oder in `OrderRules.friend_block_reason` Aufträge aus einem
   `FavorData`-Rückgabe-Pool nur anbieten, wenn sie geschuldet sind. Vorschlag: Dialog-Daten (kleinster Eingriff).


## 5. Alte Bots auf dem neuen Tarif (Phase 3–9, HillBot) – Messung W1

Drei Läufe derselben Tests: **G9** (Daten von W0 `926bffa`, Kopie des Projekts), **P1** (dieser Stand: Tarif ohne E1) und
**P1+FG** (dieser Stand mit `ParishEmu`: Pflegegeld aus, Friedhofsgeld nach Vertrag – die Erwartung **[nach P2]**).
Werte: Kapiteltag · Beutel Start → Ende (Δ) · niedrigster Morgen (Phase 8: Beutel + Lohndose).

| Bot | G9 | P1 | P1+FG [nach P2] |
|---|---|---|---|
| P4 reverent / mixed / save_load4 | Kap 19 | Kap 19 | Kap 19 |
| P4 harvester | Kap 24 (Ilse +154, Wertsachen 38) | Kap 24 (Ilse +126, Wertsachen 32) | Kap 24 |
| P4 procrastinator | Kap 23 | Kap 23 | Kap 24 |
| P5 reverent5 / save_load5 | Kap 24 · 125→25 (−100) · min 17 | Kap 24 · 125→25 · min 17 | Kap 26 · 125→19 · min **11** |
| P5 toolsmith | Kap 26 · 125→39 · min 19 | Kap 26 · min 19 | Kap 24 · 125→17 · min 11 |
| P5 mender | Kap 24 · 123→37 · min 17 | Kap 24 · min 17 | Kap 26 · 123→21 · min 17 |
| P5 harvester5 | Kap 29 · 178→102 (−76) | Kap 29 · 178→102 | Kap 29 · 178→89 (−89) |
| P5 crafter (neues Spiel) | Kap 20 · 5→51 | Kap **22** · 5→40 | Kap 21 · 5→25 |
| P6 reverent6 / save_load6 | Kap 37 · 27→42 (+15) · min 14 | Kap 37 · 27→37 (+10) · min **11** | Kap 37 · 27→31 · min **4** |
| P6 mortician | Kap 38 · 27→28 · min 12 | Kap 38 · 27→22 · min 6 | Kap 39 · 27→9 · min 5 |
| P6 mender6 | Kap 37 · 41→55 · min 8 | Kap 37 · 41→50 · min 13 | **kein Kapitel** (Gebäude 100 statt 115) · 41→34 |
| P6 harvester6 | Kap 41 · 102→111 (+9) | Kap 41 · 102→94 (−8) | Kap 41 · 102→64 (−38) |
| P6 founder (neues Spiel) | Kap 27 · 5→43 | Kap **29** · 5→46 | Kap 29 · 5→39 |
| P7 neighbor7 / save_load7 | Kap 50 · 20→51 (+31) | Kap 50 · 20→**21** (+1) | Kap 50 · 20→16 |
| P7 anatomist7 | Kap 50 · 20→81 (+61) · Präparate ≥ 9 | Kap 50 · 20→38 (+18) · Präparate **7** | Kap 50 · 20→21 · Präparate **3** |
| P8 kindly8 / save_load8 (Beutel + Dose) | Kap 62 · +20 | Kap 62 · **−3** | Kap 62 · −16 |
| P8 anatomist8 | Kap 61 · 60→102 (+42) | Kap 61 · 60→83 (+23) | Kap 61 · 60→73 (+13) |
| P8 night8 / night8b | Kap 61 · +40 | Kap 61 · +27 | Kap 61 · +13 |
| P8 lazy8 | – · +91 | – · +68 | – · +71 |
| P8 founder8 | Kap 55 · 52→85 (+33) | Kap 55 · 52→73 (+21) | Kap 55 · 52→53 (+1) |
| P9 kindly9 | Kap 69 · 59→120 (+61) | Kap 69 · 59→113 (+54) | Kap 69 · 59→127 (+68) |
| P9 stay9 / public9 / silent9 | Kap 74 · +65 | Kap 74 · +57 | Kap 74 · +68 … +70 |
| P9 letters9 | Kap 70 · +61 | Kap 70 · +54 | Kap 70 · +66 |
| P9 trader9 | Kap 72 · 91→108 (+17) | Kap 72 · 91→96 (+5) | Kap 72 · 91→108 (+17) |
| P9 lazy9 | – · +91 | – · +85 (kindly9 + 31 ≤ 35 ✓ Grundsatz 4) | – · +101 (kindly9 + 33 ✓) |
| P9 founder9 | Kap 67 · +72 | Kap 67 · +63 | Kap 67 · +64 |
| HillBot Pflicht + Bitten, Tag 14 | 105 (Bitten 32) | 96 (Bitten 26) | 91 |
| HillBot Pflicht + große Bitten, Tag 14 | 129 · Leerlauf 1887 Min | **110** · 1910 Min (+1,2 %) | 99 · 1874 Min |
| HillBot andächtig + große Bitten, Tag 14 | 99 | 91 | 87 |

**Kapiteltage (§14.7, ±2):** P1 hält überall ±2 (crafter 20 → 22 und founder 27 → 29 genau am Rand). **[nach P2]**:
alle ±2 außer **`mender6` (Phase 6): kein Kapitel im Testfenster** – sofort gemeldet; Ursache: die Woche mit dem ersten
(anteiligen) Friedhofsgeld fällt in die Gebäude-Phase, 13 Münzen fehlen für die letzte Pflichtstufe. Gegenmittel nach
§2.4.4 Schritt 1 (P2-Daten): erste Woche nicht anteilig für geladene Stände **oder** Bedarfsschwelle 60 → 70. Muss nach
dem P2-Merge nachgemessen werden.

**Neu-Bänder (nur Zahlen, Kommentar „Tarif Phase 10“, alle anderen Erwartungen unverändert):**
| Test | alt | neu | Grund (gemessen) |
|---|---|---|---|
| `test_phase5_playthrough::test_reverent5` „nie unter ≈ 15“ | ≥ 15 | ≥ 10 | P1 17, [nach P2] 11; §2.3 P5-Boden ≥ 10 |
| `test_phase6_playthrough::test_reverent6` „ab B2 nie unter 12“ | ≥ 12 | ≥ 8 | P1 11; §2.3 Boden würdevoll ≥ 8 ([nach P2] 4 ✗ – P2) |
| `test_phase7_playthrough::test_neighbor7` Ende | 30–110 | 10–110 | P1 21, [nach P2] 16; Einnahmen gleich (≈ 290), der Bot gibt den Überschuss für Runden/Spenden aus |
| `test_phase7_playthrough::test_anatomist7` Präparate | ≥ 9 | ≥ 7 | **Lead bitte bestätigen:** keine Münzzahl, aber Münzfolge – E14/A3 halten den Bot an Tag 40–42 unter seiner 20-Münzen-Schwelle für Gläser (`Phase7Bot._anatomy_buys`); [nach P2] 3 |
| `test_phase8_playthrough` `END_DELTA` | kindly8 +15…+40, anatomist8 +15…, night8 +25… | kindly8/save_load8 −20…+40, anatomist8 +5…+60, night8/b +5…+55 | P1 −3 / +23 / +27; [nach P2] −16 / +13 / +13; obere Kanten bleiben |
| `test_hill_requests_bot` `IDLE_GUARD` | 1900 | 1980 | Leerlauf darf ±5 % (§10.3): 1887 + 5 %; gemessen 1910 |
| `test_hill_requests_bot` Tag 14 (große Bitten) | ≤ 130 / ≤ 110 | ≤ 115 / ≤ 95 | P1 110 / 91, [nach P2] 99 / 87 (§2.4.3 rechnete ≈ 85) |

Unverändert grün: Phase 3 (keine Münzbänder), Phase 4, Phase 9 (`END_MIN_ACTIVE` +40, `END_MAX` +70 – [nach P2]
liegen silent9 +70 und public9 +68 an der oberen Kante, nachmessen).

**Wirkung je Abschnitt gegen §2.4.3 (Schätzung → Messung P1):** HillBot große Bitten 129 → ≈ 85 geschätzt, **110**
gemessen (P1) / 99 ([nach P2]); `neighbor7` +40 → ≈ +25 geschätzt, **+1** gemessen (Einnahmen gleich, Ausgaben höher);
`anatomist7` +51 → ≈ +30 geschätzt, **+18**; `kindly9` +64 → ≈ +45 geschätzt, **+54** (P1) / **+68** ([nach P2] – das
Friedhofsgeld 15/Woche bei Ehrwürdig ersetzt die Pflegegeld-Kappe bei 80, die `kindly9` bisher fast nichts zahlte);
`lazy9` +93 → ≈ +60 geschätzt, **+85**. Das Spätspiel wird also erst mit Markt und Abgaben (P2/P4) knapper – wie im
Vertrag vorgesehen (§2.4.3 Hinweis), aber stärker: **[nach P2] Δ der Phase-9-Bots steigt eher, als dass es fällt.**

## 6. Patch für den Merge mit P2 (E1, Pflegegeld → 0)

Zusammen mit P2s `reputation.gd` (Pflegegeld aus) und `Treasury` in der Welt:
- `data/config/reputation_config.tres`: `stipend = PackedInt32Array(0, 0, 0, 0, 0)`, `stipend_purse_cap = 0`
- `src/systems/reputation/reputation_config.gd`: dieselben Klassen-Defaults
- `tests/unit/test_phase10_scaffold.gd`: `DATA_CHANGED_AFTER_W0.reputation_config` + `stipend`, `stipend_purse_cap`; die
  Zeile „the stipend stays until P2's merge“ → `[[0, 0, 0, 0, 0], 0]`
- `tests/unit/test_phase8_scaffold.gd` `TARIFF10.reputation_config` + `stipend` (+ `stipend_purse_cap` in Phase 9),
  `test_phase3_scaffold.test_reputation_config_values` (Daten/Default 0/0/0/0/0), `test_reputation` (wie `pay_bonus`),
  `test_g8_round1.test_stipend_stays_in_the_parish_chest_from_eighty_coins` (prüft dann die Phase-8-Fixture statt der
  Daten oder entfällt – P2 entscheidet mit dem Lead)
- `tests/unit/test_tariff_sheet.gd`: `OWNED_ELSEWHERE` ohne `E1`/`E1b`; Tarifblatt neu erzeugen
- danach die alten Bots und `curve10` **ohne** `ParishEmu` nachmessen (sie tritt bei `Systems/Treasury` von selbst zur
  Seite); die [nach P2]-Werte in §5 sind die Erwartung dafür.

## 7. Offene Punkte

**P2 (Gemeindekasse):** E1 mit dem Patch §6 zusammen mergen. Nach dem Merge: [nach P2]-Werte nachmessen
(`ParishEmu` tritt von selbst zur Seite). Befunde aus der Emulation: `mender6` verliert das Phase-6-Kapitel,
`reverent6` fällt auf 4 Münzen morgens (unter den Boden 5 – der Notgroschen greift erst sonntags), `anatomist7` nur 3
Präparate. Vorschläge in Reihenfolge §2.4.4 Schritt 1: (a) für geladene Stände erste Woche **nicht** anteilig
(`TreasuryRules.prorate` nur für ein neues Spiel), (b) Bedarfsschwelle 60 → 70, (c) Notgroschen auch am Montagmorgen
prüfen. Der Pflegeanteil der Emulation (Pflegestellen Stufe 0, keine welken Blumen, nicht aufgewühlt) ist eine
Näherung von `TreasuryRules.care_share`.

**P4 (Markt):** E18/A10/A11 sind im Tarifblatt vorbereitet und werden grün, sobald `data/market/**` da ist (der Test
prüft dann den Vertragswert). Rosenstock/Messinglaterne stehen schon in der Wunschliste; `WishlistProbe` fragt
`GraveCare.has_rose(grave_id)` – bitte so benennen oder melden.

**P5:** A1 (Pachtbrief 0) in `carter.tres` + `test_dialogue.gd` (`test_carter_license_once_for_twenty`) – danach
Tarifblatt erzeugen; `Phase5Bot` plant den Brief noch mit 20 Münzen (`_wishes`, harmlos, nur später).

**Lead:** (1) E12-Aufschlag-Lesart (§1), (2) Band `anatomist7` Präparate ≥ 7 (§5), (3) Freundschafts-Patch und
Gegengefallen ohne Gefallen (§4), (4) Prüfpunkt Tag 14 der Wunschliste (§3 Befund 4).

**W3:** `founder10` an die Kette hängen (`EconomyCurveBot.STAGES`), `curve10` mit `P10_CURVE=1` und – sobald P2/P4
da sind – `P10_CURVE_STRICT=1` laufen lassen; `curve10_harvest` (B). Der Kurven-Bot kauft noch nichts aus der
Wunschliste (die Spätspiel-Senke fehlt deshalb in der Kurve).
