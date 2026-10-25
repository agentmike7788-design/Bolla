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
