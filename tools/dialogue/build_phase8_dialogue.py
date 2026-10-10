"""Phase 8 dialogues (docs/PHASE8_DESIGN.md §1.2, §1.6, §2.1–§2.13, §3.4; P6 owns data/dialogue/*).

    python3 tools/dialogue/build_phase8_dialogue.py

Writes the new dialogues (v_apprentice, beggar, peddler, robber, kin_kehr|brandt|ott|sieber, lights_lenz) and
patches the existing ones (carter, carter_village, trader, v_innkeeper … v_washer) idempotently: every Phase-8
block carries the sub_resource prefix "p8_" and is replaced on a re-run. Texts: German, dry, melancholic,
dignified (§ "Sprache"); the leading texts of §1–§2 are the basis.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tres_dialogue import C, N, patch, write_new  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DLG = os.path.join(ROOT, "data", "dialogue")
P = "p8_"


def path(name):
    return os.path.join(DLG, name + ".tres")


def back(text="…"):
    return [C(text, "menu")]


# --- shared villager blocks (§2.1.1 moods, §2.4 stories / favours, §2.7.1 dance) ---------------------------

def story_blocks(npc, stories, listen_text, cross_text, favor=None, returns=(), dance=None, extra_menu=(), extra_nodes=()):
    """Menu choices + nodes of one villager's Phase-8 part.
    stories: [(step, title, offer_text, yes_text, done_label, done_text, extra_conditions, yes_actions)]."""
    menu = []
    nodes = []
    for step, title, offer, yes, done_label, done, cond, yes_act in stories:
        gate = ["step_offerable:%s" % npc]
        if step > 1:
            gate.append("step_gte:%s:%d" % (npc, step - 1))
        gate.append("!step_gte:%s:%d" % (npc, step))
        menu.append(C("[Geschichte] %s" % title, "story_%d" % step, gate + list(cond)))
        nodes.append(N("story_%d" % step, offer, [
            C("Das mache ich.", "story_%d_yes" % step, act=["step_accept:%s" % npc] + list(yes_act)),
            C("Später.", "menu")]))
        nodes.append(N("story_%d_yes" % step, yes, back()))
        menu.append(C(done_label, "story_%d_done" % step,
                      ["flag:friend_%s_%d" % (npc, step), "!flag:p8_told_%s_%d" % (npc, step)],
                      ["set_flag:p8_told_%s_%d" % (npc, step)]))
        nodes.append(N("story_%d_done" % step, done, back()))
    menu.append(C("[Geschichte] …", "story_cross", ["p8_open", "mood:%s:cross" % npc, "!step_gte:%s:3" % npc]))
    nodes.append(N("story_cross", cross_text, back("Morgen also.")))
    menu.append(C("[Zuhören]", "listen", ["p8_open", "mood:%s:low" % npc, "!flag_today:p8_listen_%s" % npc],
                  ["listen:%s" % npc, "set_flag_day:p8_listen_%s" % npc]))
    nodes.append(N("listen", listen_text, back("(Schweigen)")))
    if favor:
        label, ask, choices = favor
        menu.append(C("[Gefallen] %s" % label, "favor", ["step_gte:%s:3" % npc, "favor_ready:%s" % npc]))
        nodes.append(N("favor", ask, choices + [C("Ein andermal.", "menu")]))
        nodes.append(N("favor_done", favor_thanks(npc), back()))
    for oid, title, offer, yes, thanks in returns:
        menu.append(C("[Gegengefallen] %s" % title, "o_%s" % oid, ["order_offerable:%s" % oid]))
        menu.append(C("[Gegengefallen] Hier ist es: %s" % title, "t_%s" % oid, ["order_ready:%s" % oid],
                      ["order_turn_in:%s" % oid]))
        nodes.append(N("o_%s" % oid, offer, [C("Ich kümmere mich darum.", "o_%s_yes" % oid, act=["order_accept:%s" % oid]),
                                              C("Später.", "menu")]))
        nodes.append(N("o_%s_yes" % oid, yes, back()))
        nodes.append(N("t_%s" % oid, thanks, back("Gern.")))
    if dance:
        menu.append(C("[Tanzen] Einen Tanz? (15 Min)", "dance", ["fest_running:kathrein"], ["dance:%s" % npc]))
        nodes.append(N("dance", dance, back("(Zurück an den Tisch)")))
    menu.extend(extra_menu)
    nodes.extend(extra_nodes)
    return menu, nodes


def favor_thanks(npc):
    return {
        "innkeeper": "Abgemacht. Wenn einer über dich redet, red ich lauter. Das kann Wackernagel.",
        "smith": "Morgen liegt es bereit. Sag keinem, dass es umsonst war.",
        "grocer": "Ich schreibe es Hanne auf. Morgen früh liegt es bei mir, zu ihrem Preis, nicht zu meinem. Das tut weh, aber gut.",
        "priest": "Ich bete für ihn. Drei Nächte. Gott hört zu, auch wenn er nicht antwortet. Die Toten vielleicht auch.",
        "mayor": "Der Nachtwächter geht heute Nacht über den Hügel. Mit Laterne und Horn. Ich trage es ein.",
        "surgeon": "Hier. Zwei Fläschchen. Ich schreibe es nicht auf. Das ist das Geschenk.",
        "washer": "Morgen, wenn einer unten liegt. Halb zehn. Leg Leinen und Hemd bereit, ich bring nur meine Hände mit.",
    }[npc]


def hill(npc, text):
    """§2.1.4: the greeting when the villager stands on the cemetery (npc_<id>_g uses the same dialogue)."""
    return N("p8_hill", text, back(), ["p8_open", "region:graveyard"], "start", ["talked:%s" % npc])


# --- Osric (carter.tres, carter_village.tres) ---------------------------------------------------------------

def carter():
    nodes = [
        N("p8_intro", "Unten reden sie über dich, Totengräber. Diesmal nicht über die Toten. Die Wirtin will was von dir, "
          "es geht um ihren Jungen. Und Fenner hat noch ein Stück Lindenacker übrig, sagt er, falls du wieder Platz brauchst. "
          "Ich brauch keinen. Ich fahr nur.",
          [C("Wer kommt eigentlich zu den Gräbern hinauf?", "p8_who"), C("Gut.", "menu")],
          ["p8_open", "!flag:p8_intro"], "p8_robber_seen", ["set_flag:p8_intro"]),
        N("p8_robber_seen", "Ich hab auf dem Weg einen gesehen, um zwei, mit Spaten. Ich hab nicht angehalten. Ich halte nie an.",
          [C("Wo?", "p8_robber_where"), C("Danke, Osric.", "menu")],
          ["p8_open", "stat_gte:robber_encounters:1", "!flag:p8_carter_robber"], "p8_robber_seen_b",
          ["set_flag:p8_carter_robber", "set_flag:robber_known"]),
        N("p8_robber_seen_b", "Am Lindenacker ist die Erde aufgeworfen, hab ich gesehen. Heute Nacht war einer da, mit Spaten. "
          "Ich hab ihn gesehen, um zwei, am Waldrand. Ich hab nicht angehalten. Ich halte nie an.",
          [C("Wo?", "p8_robber_where"), C("Danke, Osric.", "menu")],
          ["p8_open", "stat_gte:graves_disturbed:1", "!flag:p8_carter_robber"], "p8_lights",
          ["set_flag:p8_carter_robber", "set_flag:robber_known"]),
        N("p8_robber_where", "Unten, wo der Wald an den Lindenacker stößt. Er kam von Ellbach her, glaub ich. Die von Ellbach "
          "graben nicht mehr selbst, die lassen graben. Stell ihnen ein Licht hin, den Frischen. Das mögen die nicht.",
          back("Mach ich.")),
        N("p8_lights", "Vom Pfarrer. Zwölf Grabkerzen. Für die, zu denen keiner hinaufgeht, sagt er. Ich hab gesagt, das sind "
          "mehr als zwölf. Er hat gesagt, den Rest zahlst du. Das war ein Scherz. Glaub ich.",
          back("Ich stell sie auf."), ["fest_today:lights", "!flag_today:p8_carter_lights"], "p4_rumor",
          ["set_flag_day:p8_carter_lights"]),
        N("p8_who", "Die Kehr, mit Heide im Korb. Der Brandt, der den Hut nicht aufbehalten kann. Der alte Sieber, der redet mit "
          "seiner Grete, als säße sie noch am Ofen. Wer einen bei dir liegen hat, kommt jetzt. Früher kam keiner. Früher war "
          "auch keiner, zu dem man gehen wollte.", back("Ich seh sie."), ["!flag:p8_who_1"], "p8_who_2", ["set_flag:p8_who_1"]),
        N("p8_who_2", "Der Veit sitzt manchmal außen am Tor. Ammer, der Bettler, früher an der Fähre. Gib ihm was oder lass es, "
          "er nickt so oder so. Aber er sieht, wer nachts geht. Er schläft schlecht, seit dem Wasser.",
          back("Ich red mit ihm."), ["!flag:p8_who_2"], "p8_who_3", ["set_flag:p8_who_2"]),
        N("p8_who_3", "Und alle sechs Tage die Vogelsang mit ihrer Kiepe. Kommt aus dem Tal, geht über den Hügel weiter, "
          "verkauft Grabkerzen und Blumen, die den Winter aushalten. Sie redet schneller, als ich fahre. Das ist nicht schwer.",
          back("Gut zu wissen."), [], "", ["clear_flag:p8_who_1", "clear_flag:p8_who_2"]),
        N("p8_crate", "Die Kiste vom Quast? Stell sie hinten drauf, zu den anderen. Die klirren alle gleich. Ich frag nicht.",
          back("Danke, Osric.")),
    ]
    menu = [C("Wer kommt eigentlich zu den Gräbern hinauf?", "p8_who", ["flag:p8_intro"]),
            C("[Auftrag] Die Kiste vom Wundarzt.", "p8_crate", ["order_ready:of_quast_2"], ["order_turn_in:of_quast_2"])]
    patch(path("carter"), P, nodes, {"menu": menu}, {"p7_intro": "p8_intro"}, insert_before='next = &"goodbye')


def carter_village():
    nodes = [
        N("p8_jakob", "Der Wackernagel-Junge fragt mir Löcher in den Bauch. Wie tief, wie lang, wie schwer. Ich sag ihm: Frag den "
          "da oben. Er sagt, das tut er schon. Dann frag ich mich, was du ihm antwortest.",
          back("Die Wahrheit, meistens."), ["apprentice_hired", "!flag:p8_carter_jakob"], "menu", ["set_flag:p8_carter_jakob"]),
    ]
    patch(path("carter_village"), P, nodes, {}, {"chapter": "p8_jakob"})


def trader():
    nodes = [
        N("p8_grell", "Der Grell? Der gräbt für die Stadt. Ich kaufe nur, was über der Erde liegt. Das ist ein Unterschied, auch "
          "wenn du ihn nicht siehst.", back("Ich seh ihn.")),
        N("p8_veit", "Veit sieht alles und verkauft nichts davon. Das mag ich an ihm. Er hat mir einmal gesagt, wo ich nicht "
          "gehen soll. Er hatte recht. Er hat kein Geld dafür genommen. Das war das Einzige, was ich ihm übel nahm.",
          back("Hm.")),
        N("p8_lights", "Am Lichtgang? Zu viel Licht für eine wie mich. Ich komm in der Nacht danach. Dann brennen sie noch, "
          "und keiner schaut hin.", back("Ich halte die Tür auf.")),
    ]
    menu = [C("Kennst du einen Grell?", "p8_grell", ["p8_open", "robber_known"]),
            C("Was weißt du über Veit?", "p8_veit", ["p8_open"]),
            C("Kommst du zum Lichtgang?", "p8_lights", ["p8_open", "!flag:lights_held"])]
    patch(path("trader"), P, nodes, {"menu": menu}, {}, insert_before='next = &"goodbye"')


# --- villagers ------------------------------------------------------------------------------------------------

def innkeeper():
    menu, nodes = story_blocks("innkeeper", [
        (1, "Der Junge",
         "Du hast Augen wie einer, der nicht viel schläft. Gut. Mein Jakob schläft zu viel. Seit der Tinktur ist er nicht mehr "
         "zu halten, Totengräber, er klettert aufs Dach und redet mit den Hühnern. Nimm ihn mit hinauf. Er soll lernen, was "
         "die Leute brauchen, auch wenn sie es nicht wollen. Und etwas, das nicht nach Bier riecht.",
         "Morgen früh steht er am Tor, mit Brot in der Tasche. Einen Rechen in seiner Größe hat Esch, eine Gießkanne auch. "
         "Schreib ihm an die Tafel, was er tun soll. Lesen kann er. Zuhören weniger.",
         "Über Jakobs ersten Tag", "Er ist heimgekommen und hat gegessen wie zwei. Dann hat er gesagt: Mutter, oben ist es "
         "ruhiger als hier. Ich hab nicht gefragt, ob das gut ist. Ich hab ihm noch Brot gegeben.", [], ["apprentice_hire"]),
        (2, "Konrads Name",
         "Konrad. Mein Mann. Im Fährwinter ist er hinaus, wie die anderen, und das Wasser hat ihn behalten. Sechzehn haben sie "
         "wiedergefunden. Ihn nicht. Er hat kein Grab, Totengräber. Jakob war vier. Mach ihm eine Tafel mit seinem Namen, und "
         "bring sie dem Pfarrer. Dann hängt er wenigstens irgendwo.",
         "Konrad Wackernagel. Mit zwei a. Die Leute schreiben ihn immer falsch, als hätten sie ihn nie gekannt.",
         "Über Konrads Tafel", "Ich war in der Kirche. Sie hängt am Gedenkbrett, gleich unter der Fähre. Ich hab sie angefasst. "
         "Sie war kalt. Er war auch immer kalt an den Händen. Danke, Totengräber. Das sag ich nicht zweimal.", [], []),
        (3, "Oben bei Jakob",
         "Ich will ihn einmal sehen, oben bei dir. Bei der Arbeit, nicht beim Essen. Um drei, an der Bank bei deiner Hütte. "
         "Wenn er's kann. Wenn nicht, sag's mir vorher, dann komm ich nicht.",
         "Um drei. Ich bring Kuchen mit. Nicht für ihn. Für dich.",
         "Über den Besuch oben", "Er hält den Rechen wie du. Das hat er nicht von mir. Ich hab den ganzen Weg hinunter nichts "
         "gesagt, und Wackernagel sagt immer was. Das bleibt unter uns.", [], []),
    ],
        "Konrad hätte heute Namenstag gehabt. Ich weiß nicht, warum ich dir das sag. Ich stell ihm jedes Jahr ein Glas hin. "
        "Keiner trinkt es. Abends kipp ich es weg. … So. Jetzt ist es gesagt.",
        "Heute nicht, Totengräber. Morgen.",
        ("Ein Wort im Krug",
         "Du willst, dass Wackernagel den Mund aufmacht? Für dich? Wenn die nächsten Tage einer was Schlechtes über dich sagt, "
         "red ich es klein. Das kann ich. Das ist mein Beruf.",
         [C("Ja, bitte.", "favor_done", act=["favor_use:innkeeper"])]),
        [("of_rosine_return_1", "Holunder für Rosine", "Sechs Hände Holunderbeeren, wenn du welche findest. Der Wein wartet nicht.",
          "Drei Tage. Dann sind sie mir zu weich.", "Holunder. Sechs Hände. Du hast es nicht vergessen."),
         ("of_rosine_return_2", "Ein Tag für Jakob", "Gib dem Jungen einen Tag frei. Den Lohn trotzdem. Er schläft wieder zu "
          "wenig, seit er bei dir ist. Das ist auch nicht recht.", "Einen Tag. Er wird maulen. Lass ihn.",
          "Er hat bis Mittag geschlafen. Dann hat er gefragt, ob oben alles in Ordnung ist. Ich hab gesagt: Frag ihn selber.")],
        "Kathrein stellt den Tanz ein, aber noch nicht jetzt. Komm, Totengräber. Du trittst wie einer, der Erde gewohnt ist. "
        "Das macht nichts. Ich führe.",
        [C("Wie macht sich Jakob?", "p8_jakob", ["apprentice_hired"]),
         C("[Geschichte] Du bist heraufgekommen.", "story_3_meet", ["order:of_rosine_3:accepted", "region:graveyard"],
           ["meet:apprentice_lunch"])],
        [N("p8_jakob", "Er redet nur noch vom Hügel. Vom Laub, das von unten nach oben geharkt wird, nicht hin und her. Von dir. "
           "Wenn du streng bist, sag ich nichts. Wenn du zu streng bist, sag ich was. Laut.", back("Ich weiß.")),
         N("story_3_meet", "Er hält den Rechen wie du. Das hat er nicht von mir. Schau, wie er pfeift. Das hat er von Konrad. "
           "Ich bleib noch ein bisschen. Er soll nicht merken, dass ich schau.", back("(Sich neben sie setzen)"))])
    nodes.insert(0, hill("innkeeper", "Hier oben ist es stiller, als ich dachte. Gar kein Krug, nirgends. Wie hältst du das aus, "
                         "Totengräber?"))
    patch(path("v_innkeeper"), P, nodes, {"menu": menu}, {}, start="p8_hill")


def smith():
    menu, nodes = story_blocks("smith", [
        (1, "Meister Gratz",
         "Der alte Gratz hat mir das Schmieden beigebracht. Den Hammer und wann man aufhört. Er selbst hat nie aufgehört. "
         "Halt ihm das Grab sauber. Drei Morgen in Folge. Dann glaub ich's.",
         "Drei Morgen. Ich seh nach.", "Über Meister Gratz",
         "Drei Morgen sauber. Gratz hätte gesagt: Na also. Mehr hat er nie gesagt. Mir hat es gereicht.", [], []),
        (2, "Ein Gitter für die Frischen",
         "In der Stadt haben sie Gitter über den frischen Gräbern. Eisen, mannshoch nicht, aber schwer. Ich kann das auch. "
         "Bring mir vier Stangen Eisen und zwei Säcke Kohle. Das erste schenk ich dir.",
         "Vier Stangen. Zwei Säcke. Dann schmied ich.", "Über das Gitter",
         "Das erste steht bereit. Die nächsten kosten acht. Für die Gemeinde zwölf. Sag's Fenner nicht.", [], []),
        (3, "Feierabend unter der Linde",
         "Setz dich abends mal zu mir unter die Linde. Zweimal. Einmal ist Zufall.",
         "Nach der Schmiede. Halb sechs.", "Über die Abende unter der Linde",
         "Zweimal. Kein Zufall. Gut.", [], []),
    ],
        "Heute ist der Tag, an dem sie gestorben ist. Meine Frau. Ich schmied trotzdem. Was soll ich sonst. … Danke, dass du "
        "dastehst und nichts sagst.",
        "Heute nicht, Totengräber. Morgen.",
        ("Umsonst geschmiedet",
         "Was brauchst du? Sag's. Ich frag nicht, wofür.",
         [C("Drei Beschläge.", "favor_done", act=["favor_use:smith:iron_fittings"]),
          C("Einen Stahlstab.", "favor_done", act=["favor_use:smith:steel_rod"]),
          C("Leih mir ein Grabgitter, zehn Tage.", "favor_done", act=["favor_use:smith:mortsafe_loan"])]),
        [("of_esch_return_1", "Kohle für die Esse", "Sechs Säcke Kohle. Die Esse frisst.", "Gut.", "Gute Kohle."),
         ("of_esch_return_2", "Werkstein für den Amboss", "Zwei Werksteine. Der Amboss braucht ein neues Bett.", "Gut.",
          "Sauber gehauen. Der Amboss liegt wieder gerade.")],
        "Ich tanz nicht. … Einmal. Weil Kathrein ist.",
        [C("[Geschichte] Ich setz mich zu dir.", "story_3_meet", ["order:of_esch_3:accepted", "time_between:1054:1140"],
           ["meet:v_linden"]),
         C("[Auftrag] Hier sind Eisen und Kohle.", "story_2_turn_in", ["order_ready:of_esch_2"], ["order_turn_in:of_esch_2"])],
        [N("story_3_meet", "Setz dich. … Meine Frau ist im Kindbett gestorben. Das Kind auch. Quast war dabei. Er hat getan, "
           "was er konnte. Das sag ich jedem.", back("(Sitzen bleiben)"), ["flag:p8_esch_bench_1"], "story_3_meet_first"),
         N("story_3_meet_first", "Setz dich. Die Bank hält. Hab ich selbst beschlagen.", back("(Sitzen bleiben)"), [], "",
           ["set_flag:p8_esch_bench_1"]),
         N("story_2_turn_in", "Gutes Eisen. Morgen steht das Gitter. Das erste kostet dich nichts.", back("Danke, Esch."))])
    nodes.insert(0, hill("smith", "Bin oben beim Meister. Red nicht so laut. Er mochte keinen, der redet."))
    patch(path("v_smith"), P, nodes, {"menu": menu}, {}, start="p8_hill")


def grocer():
    menu, nodes = story_blocks("grocer", [
        (1, "Mutters Grab",
         "Setz Mutter Christrosen aufs Grab und halt sie frisch, bis ich wiederkomme. Den Topf geb ich Ihnen, ich rechne ihn "
         "nicht an. Das heißt, ich rechne ihn an, aber nicht Ihnen.",
         "Christrosen. Die blühen, wenn sonst nichts blüht. Mutter hat das gemocht. Sie hat alles gemocht, was sich nicht "
         "nach den anderen richtet.", "Über Mutters Grab",
         "Sie waren frisch, als ich kam. Ich hab gezählt: elf Blüten. Mutter hätte zwölf gesagt, aus Prinzip.", [],
         ["give_item:flower_seedlings:1"]),
        (2, "Das Anschreibebuch",
         "Im Buch meiner Mutter stehen noch Schulden. Von Leuten, die längst tot sind. Ich will die Seiten am Lichtgang "
         "verbrennen. Aber erst will ich wissen, wer davon oben liegt. Schreiben Sie mir die Namen aus Ihrem Register ab.",
         "Mit Tinte, bitte. Bleistift verwischt. Bei Schulden darf nichts verwischen, auch nicht beim Verbrennen.",
         "Über das Anschreibebuch",
         "Ich hab die Seiten verbrannt. Sie haben schlecht gebrannt, das Papier war gut. Mutter hat nie an Papier gespart, "
         "nur an sich.", [], []),
        (3, "Für die ohne Namen",
         "Drei Töpfe Christrosen. Für drei Gräber, zu denen keiner kommt. Halten Sie sie frisch bis zum dritten Morgen. Ich "
         "zahle die Töpfe. Das schreib ich nirgends hin.",
         "Drei. Mehr hab ich nicht. Mehr sollte auch keiner brauchen.", "Über die drei Töpfe",
         "Drei Gräber mit Christrosen, und keiner weiß, von wem. So ist es richtig. Wenn man es weiß, ist es ein Geschäft.",
         [], []),
    ],
        "Heute vor elf Jahren hat Mutter den Laden zugemacht. Für immer, meine ich. Ich hab ihn am nächsten Morgen wieder "
        "aufgemacht, um sieben, wie sie. Das war das Einzige, was ich konnte. … Danke. Sie hören zu wie einer, der nichts kauft.",
        "Heute nicht, Totengräber. Morgen. Heute rechne ich nur.",
        ("Aus der Stadt bestellt",
         "Etwas aus Hannes Kiepe? Außerhalb ihres Tages? Ich bestelle es Ihnen. Morgen früh liegt es bei mir. Zu ihrem Preis.",
         [C("Zeig mir, was sie trägt.", "", act=["open_panel:favor"])]),
        [("of_mangold_return_1", "Kräuter für den Laden", "Acht Bund Kräuter. Die Stadt will sie, und ich will die Stadt.",
          "Drei Tage. Ich zähle.", "Acht Bund. Ich hab nachgezählt. Acht."),
         ("of_mangold_return_2", "Garn für den Laden", "Vier Strang Garn. Meins ist alle, und die Dorn spinnt nur für Tote.",
          "Gut.", "Vier Strang. Schönes Garn. Fast zu schön zum Verkaufen.")],
        "Einen Tanz? Mit dem Totengräber? Na gut. Aber Sie zählen nicht mit. Ich zähle.",
        [C("[Auftrag] Hier sind die Namen.", "story_2_turn_in", ["order_ready:of_mangold_2"], ["order_turn_in:of_mangold_2"]),
         C("[Gefallen] Ist meine Bestellung da?", "p8_ware", ["ware_ready"], ["take_ware"])],
        [N("p8_ware", "Da. Aus Hannes Kiepe, zu Hannes Preis. Ich hab nichts draufgeschlagen. Das tut mir mehr weh als Ihnen.",
           back("Danke, Theres.")),
         N("story_2_turn_in", "Neun Namen. Sieben davon im Buch. Zwei haben bar gezahlt. Die zwei hat Mutter nie gemocht.",
           back("…"))])
    nodes.insert(0, hill("grocer", "Ich bin bei Mutter. Fünf Minuten, dann muss ich zurück, der Laden ist zu, und ein "
                         "geschlossener Laden kostet."))
    patch(path("v_grocer"), P, nodes, {"menu": menu}, {}, start="p8_hill")


def priest():
    menu, nodes = story_blocks("priest", [
        (1, "Die Namen im Buch",
         "Totengräber, eine Bitte. Ich brauche Namen und Tage der Toten im Lindenacker, fürs Sterbebuch. Schreiben Sie sie mir "
         "aus Ihrem Register ab. Meine Augen, wissen Sie. Und meine Beine. Und der Hügel.",
         "Schön. Schön. Mit Tinte, wenn es geht. Bleistift verwischt im Buch.", "Über das Sterbebuch",
         "Die Namen stehen jetzt drin. Ordentlich. Ich habe sie zweimal gelesen, das tue ich immer, damit keiner verloren geht.",
         [], []),
        (2, "Das Archiv",
         "Das Pfarrarchiv ist in Unordnung, Totengräber. Rechnungen, Taufen, Briefe von Leuten, die nicht mehr schreiben. "
         "Helfen Sie mir am Abend, es zu ordnen? Zwischen vier und sechs. Ich halte das Licht, Sie halten den Staub aus.",
         "Ich freue mich. Wirklich. Ein Archiv ist wie ein Friedhof, nur trockener.", "Über das Archiv",
         "Das Archiv ist geordnet, so weit es sich ordnen lässt. Sie haben etwas eingesteckt? Nein. Ich habe nichts gesehen. "
         "Ich sehe ohnehin schlecht, wissen Sie.", [], []),
        (3, "Das Wort am Lichtgang",
         "Am Lichtgang lese ich die Namen derer, zu denen keiner hinaufgeht. Lesen Sie sie mit mir. Sie kennen sie besser als "
         "ich. Sie haben sie hingelegt.",
         "Um zwanzig vor sechs, am Kirchhof vor Ihrer Kapelle. Wenn es regnet, auch.", "Über die Namen am Lichtgang",
         "Wir haben jeden Namen gelesen. Ihre Stimme ist besser als meine. Das ist kein Lob, das ist eine Beobachtung.", [], []),
    ],
        "Heute war ich bei einem, der nicht sterben wollte. Er ist trotzdem gestorben. Ich habe gebetet, und er hat geflucht. "
        "Wir hatten beide recht. … Verzeihen Sie. Ein Pfarrer soll das nicht sagen. Ein Mensch schon.",
        "Heute nicht, Totengräber. Morgen. Heute bete ich für mich selbst, das ist anstrengend genug.",
        ("Fürbitte",
         "Eine Fürbitte? Für einen Ihrer Toten? Gern. Drei Nächte. Sagen Sie mir nur, für wen. Gott kennt den Namen, aber ich nicht.",
         [C("Ich sage Ihnen, für wen.", "", act=["open_panel:favor"])]),
        [("of_lenz_return_1", "Kerzen für den Altar", "Vier Altarkerzen. Der Advent kommt, und Gott sieht auch so, aber die "
          "Gemeinde nicht.", "Danke. Sie sind ein Segen. Sagen Sie es nicht dem Schultheiß.", "Vier. Schön gezogen. Vergelt's Gott."),
         ("of_lenz_return_2", "Blumen für einen Vergessenen", "Ein Grab, zu dem keiner kommt, mit frischen Blumen. Welches, "
          "überlasse ich Ihnen. Sie wissen, wer vergessen ist.", "Schön.", "Ich habe die Blumen gesehen. Ich habe nicht "
          "gefragt, für wen. Gott weiß es.")],
        "Bis die Musik zu schnell wird, Totengräber. Dann setze ich mich. Ein Pfarrer darf tanzen, er darf nur nicht dabei "
        "gesehen werden. Ach, sieht ja doch jeder.",
        [C("[Auftrag] Die Tafel für Konrad Wackernagel.", "p8_plate", ["order_ready:of_rosine_2"], ["order_turn_in:of_rosine_2"]),
         C("[Auftrag] Hier sind die Namen.", "story_1_turn_in", ["order_ready:of_lenz_1"], ["order_turn_in:of_lenz_1"]),
         C("[Geschichte] Die Namen lesen.", "p8_names_inside", ["order:of_lenz_3:accepted", "fest_after:lights"],
           ["task:lights_names"]),
         C("Die dritte Reihe – muss sie geweiht werden?", "p8_row3", ["flag:linden_row3_granted", "!flag:p8_lenz_row3"],
           ["set_flag:p8_lenz_row3"])],
        [N("p8_plate", "Konrad Wackernagel. Ich hänge sie gleich auf, unter die Fähre. Da gehört er hin, so sehr man zu Wasser "
           "gehören kann. Rosine wird kommen und so tun, als käme sie wegen der Messe.", back("Danke, Herr Pfarrer.")),
         N("story_1_turn_in", "Ah. Sie haben auch die Striche gesehen, nicht wahr? Am Rand. Tinte ist Tinte, Totengräber. "
           "Manchmal ist sie eben früher da.", back("…")),
         N("p8_names_inside", "Dann lesen wir sie eben drinnen. Gott hört auch durch Mauern. Die Toten auch, hoffe ich.",
           back("(Lesen)")),
         N("p8_row3", "Geweiht ist der ganze Acker, nicht die Reihe. Ich komme nicht noch einmal hinauf, Totengräber. "
           "Meine Knie sind auch nur ein Acker.", back("Verstehe."))])
    patch(path("v_priest"), P, nodes, {"menu": menu}, {})


def mayor():
    menu, nodes = story_blocks("mayor", [
        (1, "Die Beine",
         "Unter vier Augen, Totengräber. Die Wassersucht wird schlimmer. Einen Wacholderumschlag, wenn Sie haben. Zwei Hände "
         "Wacholder, eine Bahn Leinen. Oder das Pulver, falls Sie noch eins übrig haben. Diskret, bitte. Amtlich diskret.",
         "Ich trage es nicht ein. Das ist ein Opfer.", "Über die Beine",
         "Die Beine sind besser. Nicht gut, aber besser. Ich habe heute zwei Treppen genommen, ohne zu zählen. Fast ohne.",
         [], []),
        (2, "Ein Platz mit Blick",
         "Ich möchte mir einen Platz ansehen. Für später. Sehr viel später, verstehen Sie. In der dritten Reihe, mit Blick "
         "aufs Amtshaus, wenn man das von oben sieht. Ich komme um vier hinauf. Statt der Gemeindetafel.",
         "Um vier. Ich bringe das Register mit. Man weiß nie.", "Über den Platz mit Blick",
         "Die zwölfte Stelle. Ich habe sie mir vermerkt, nur vermerkt, nicht gesperrt. Und den Schlüssel haben Sie ja nun. "
         "Gehen Sie sparsam damit um. Akten verzeihen nichts.", [], []),
        (3, "Eine Runde von mir",
         "Kommen Sie abends in den Krug. Heute zahle ich. Das kommt selten vor, ich habe es nachgerechnet.",
         "Ab sechs. Ich sitze am Tisch mit der Kerbe.", "Über die Runde",
         "Ich habe Ihnen von meiner Frau erzählt. Das ist nicht amtlich. Das ist überhaupt nichts. Danke, dass Sie es so "
         "behandeln.", [], []),
    ],
        "Heute habe ich den Gemeindehaushalt dreimal gerechnet, und jedes Mal fehlten vier Münzen. Ich weiß, wo sie sind. "
        "Ich habe sie meiner Frau aufs Grab gelegt, unten bei St. Gallus. Jedes Jahr. … Das bleibt unter uns.",
        "Heute nicht, Totengräber. Morgen. Im Rahmen der Öffnungszeiten.",
        ("Der Nachtwächter",
         "Der Nachtwächter, eine Nacht auf Ihrem Hügel? Das lässt sich einrichten. Sagen Sie mir, welche. Heute? Gut. Ich "
         "trage es ein.", [C("Heute Nacht.", "favor_done", act=["favor_use:mayor"])]),
        [("of_fenner_return_1", "Holz für den Gemeindezaun", "Zehn Scheit Holz für den Zaun der Gemeinde. Ordnungsgemäß.",
          "Vermerkt.", "Zehn. Ich zähle: zehn. Die Gemeinde dankt."),
         ("of_fenner_return_2", "Die Armenkasse", "Fünf Münzen in die Armenkasse. Für die Ordnung, nicht für mich.",
          "Vermerkt.", "Fünf Münzen. Eins, zwei, drei, vier, fünf. Mit Ihrem Namen.")],
        "Ein Tanz? Ich tanze nur mit Protokoll. … Ach, was soll's. Kathrein steht nicht im Gesetz.",
        [C("[Geschichte] Hier, die zwölfte Stelle.", "story_2_meet", ["order:of_fenner_2:accepted", "region:graveyard"],
           ["meet:gv_l_12"]),
         C("[Geschichte] Ein Bier, Herr Schultheiß?", "story_3_meet", ["order:of_fenner_3:accepted", "time_between:1085:1260"],
           ["meet:v_in_inn_table"]),
         C("[Auftrag] Der Umschlag für die Beine.", "story_1_turn_in", ["order_ready:of_fenner_1"], ["order_turn_in:of_fenner_1"])],
        [N("story_2_meet", "Hier. Von hier sieht man das Dach vom Amtshaus, wenn die Linde kein Laub hat. Das genügt. Und das "
           "hier ist der Gemeindeschlüssel zum Archiv. Die Hälfte der Akten da drin gehört der Gemeinde. Die andere Hälfte "
           "dem Pfarrer, aber das muss er nicht wissen.", back("Danke.")),
         N("story_3_meet", "Prost. Meine Frau liegt unten auf dem alten Kirchhof bei St. Gallus, wo kein Totengräber mehr "
           "gräbt. Der Efeu ist über den Stein. Ich lasse ihn. Sie mochte Efeu. Ich nicht. Wir waren uns selten einig, und "
           "trotzdem.", back("(Trinken)")),
         N("story_1_turn_in", "Diskret überreicht. Danke. Amtlich hat es nicht stattgefunden.", back("Gern."))])
    nodes.insert(0, hill("mayor", "Ah, Totengräber. Ich bin, sagen wir, dienstlich hier. Halb dienstlich. Der Rest ist meine Sache."))
    nodes.insert(0, N("p8_row3", "Totengräber, die Gemeinde hat getagt. Der Lindenacker ist voll, das haben wir bemerkt. "
                      "Ich gebe Ihnen die dritte Reihe am Südrand, vier Stellen. Ein Stumpf ist da und eine Brombeere, die "
                      "müssen weg, aber geweiht ist der ganze Acker, sagt der Pfarrer. Ich habe es aufgeschrieben.",
                      [C("Danke, Herr Schultheiß.", "menu")], ["p8_open", "!flag:linden_row3_granted"], "p8_robber",
                      ["set_flag:linden_row3_granted", "notify:Die Gemeinde gibt dir die dritte Reihe am Lindenacker.",
                       "talked:mayor"]))
    nodes.insert(1, N("p8_robber", "Den Grell haben wir. Er ist in der Stadt. Die Gemeinde dankt Ihnen, schriftlich folgt. "
                      "Ein Grabräuber in Hollerbrück. Das kommt ins Protokoll, mit Ihrem Namen, auf der guten Seite.",
                      back("Gut."), ["robber_fate:reported", "!flag:p8_fenner_robber"], "p8_robber_watch",
                      ["set_flag:p8_fenner_robber", "talked:mayor"]))
    nodes.insert(2, N("p8_robber_watch", "Drei offene Gräber, Totengräber. Drei. Mein Nachtwächter hat ihn gefangen, am Waldrand, "
                      "mit Sack und Spaten. Er ist in der Stadt. Ich hätte Sie lieber nicht erwähnt.",
                      back("…"), ["robber_fate:caught_watch", "!flag:p8_fenner_robber"], "p8_robber_let_go",
                      ["set_flag:p8_fenner_robber", "talked:mayor"]))
    nodes.insert(3, N("p8_robber_let_go", "Veit sagt, Sie haben ihn laufen lassen. Den Grell. Ich sage dazu nichts. Amtlich "
                      "nicht. Persönlich auch nicht. Das ist mehr, als Sie verdienen.",
                      back("…"), ["robber_fate:let_go", "!flag:p8_fenner_robber"], "p8_hill",
                      ["set_flag:p8_fenner_robber", "talked:mayor"]))
    patch(path("v_mayor"), P, nodes, {"menu": menu}, {}, start="p8_row3")


def surgeon():
    menu, nodes = story_blocks("surgeon", [
        (1, "Unter Kollegen",
         "Die Wöchnerin bei den Siebers braucht Wundsalbe. Zwei Tiegel. Sie können das, hört man. Unter Kollegen, Totengräber. "
         "Wir arbeiten an beiden Enden derselben Sache.",
         "Danke. Ich sage ihr nicht, von wem. Sie würde fragen, wo Sie Ihre Hände sonst haben.", "Über die Wöchnerin",
         "Die Siebers haben einen Sohn. Gesund, laut, hässlich. Die Mutter lebt. Ihre Salbe war gut. Ich habe es aufgeschrieben.",
         [], []),
        (2, "Die Kiste für die Stadt",
         "Diese Kiste muss morgen früh mit Faulhaber in die Stadt. Bis zwanzig vor acht an seinem Karren, an der Bahre. "
         "Sie ist versiegelt. Das Siegel ist für die Stadt, nicht für Sie. Aber ich bitte Sie trotzdem, es zu lassen.",
         "Danke. Faulhaber fragt nicht. Sie fragen. Das ist der Unterschied zwischen Ihnen.", "Über die Kiste",
         "Die Kiste ist angekommen. Die Stadt schreibt, sie sei zufrieden. Die Stadt ist nie zufrieden. Sie schreibt es nur.",
         [], ["give_item:quast_crate:1"]),
        (3, "Was ich nicht aufschreibe",
         "Kommen Sie abends an die Brücke, Totengräber. Ich erzähle Ihnen etwas, das ich nicht aufschreibe. Ich schreibe "
         "sonst alles auf.", "Nach sechs. Ich stehe am Geländer und schaue ins Wasser. Das tue ich immer.",
         "Über den Abend an der Brücke",
         "Ich habe es Ihnen gesagt. Das genügt. Schreiben Sie es auch nicht auf. Einer von uns muss es vergessen dürfen.", [], []),
    ],
        "Heute war ein Kind bei mir, mit Fieber. Ich habe ihm Tropfen gegeben und der Mutter Hoffnung. Die Tropfen helfen "
        "meistens. Die Hoffnung nicht immer. … Danke. Sie hören zu wie ein Arzt. Das ist ein Kompliment, auch wenn es nicht so klingt.",
        "Heute nicht, Totengräber. Morgen. Heute habe ich keine Geduld, nicht einmal für mich.",
        ("Arznei umsonst",
         "Fiebertinktur? Zwei Fläschchen. Umsonst. Ich schreibe es nicht auf, das ist das eigentliche Geschenk.",
         [C("Danke, Doktor.", "favor_done", act=["favor_use:surgeon"])]),
        [("of_quast_return_1", "Kräuterbündel", "Zwei Kräuterbündel. Für die Salben. Von Ihrem Hügel, wenn es geht, da wächst es ruhiger.",
          "Gut.", "Schön getrocknet. Ich rieche den Hügel daran."),
         ("of_quast_return_2", "Weingeist", "Eine Flasche Weingeist. Fragen Sie nicht.", "Danke.", "Danke. Und nein. Nicht zum Trinken.")],
        None,
        [C("Besuchen Sie nie jemanden oben?", "p8_graves", ["p8_open"]),
         C("[Geschichte] Ich bin da.", "story_3_meet", ["order:of_quast_3:accepted", "time_between:1086:1170"], ["meet:v_bridge"]),
         C("[Auftrag] Hier ist die Wundsalbe.", "story_1_turn_in", ["order_ready:of_quast_1"], ["order_turn_in:of_quast_1"])],
        [N("p8_graves", "Nie. Ich sehe die Toten lieber vorher, Totengräber. Hinterher gehören sie Ihnen.", back("Verstehe.")),
         N("story_3_meet", "Ich gehe zu jedem Licht im Fenster, Totengräber. Auch wenn mich keiner holt. Seit dem Fährwinter. "
           "Ich war zu spät damals. Siebzehnmal. Seitdem bin ich lieber zu früh. Manche sagen, das sei verdächtig. Manche "
           "haben recht, nur nicht so, wie sie denken.", [C("Und die stillen Herzen?", "story_3_heart", ["clue_known:c_v_still_heart"]),
                                                          C("(Ins Wasser schauen)", "menu")]),
         N("story_3_heart", "Die stillen Herzen. Gesund, und stehen geblieben. Bei denen mit dem Zeichen. Ich habe sie gezählt, "
           "Totengräber. Ich bin Arzt, ich zähle. Es sind mehr, als ein Zufall erlaubt, und weniger, als ein Mörder braucht. "
           "Das ist das, was ich nicht aufschreibe.", back("(Schweigen)")),
         N("story_1_turn_in", "Zwei Tiegel. Sauber. Ich bringe sie heute noch hin.", back("Gern."))])
    patch(path("v_surgeon"), P, nodes, {"menu": menu}, {})


def washer():
    menu, nodes = story_blocks("washer", [
        (2, "Die Totenwache",
         "Halt einmal mit mir Totenwache. Wenn einer unten liegt, in deiner Gruft, komm ich um halb zehn die Treppe hinunter. "
         "Eine Stunde. Du musst nichts sagen. Du musst nur dableiben.",
         "Halb zehn. Lass die Lampe an.", "Über die Totenwache",
         "Du bist geblieben. Die meisten gehen nach einer Viertelstunde, weil sie es nicht aushalten, wie still es ist. "
         "Es ist nicht still. Man muss nur lange genug sitzen.", [], []),
        (3, "Das Gesangbuch",
         "Komm einmal zu mir, an meine Tür, am Nachmittag. Ich will dir was zeigen. Nicht hier, wo alle stehen.",
         "Nachmittags. Klopf nicht, ich hör dich.", "Über das Gesangbuch",
         "Du hast es versprochen. Ich hab's gehört. Das Buch auch.", [], []),
    ],
        "Heute hab ich eine gewaschen, die hat mich gekannt, als ich klein war. Sie hat mir Äpfel gegeben, wenn Kaspar mir "
        "meine weggenommen hat. Ich hab ihr die Haare gekämmt, wie sie es mochte. … Geh jetzt. Nein, bleib noch.",
        "Heute nicht, Totengräber. Morgen.",
        ("Totenwäsche",
         "Ich wasch dir einen. Morgen, halb zehn, in deiner Gruft. Ich komm runter. Leg Leinen und Hemd hin.",
         [C("Danke, Liesel.", "favor_done", act=["favor_use:washer"])]),
        [("of_liesel_return_1", "Leinen für die Toten", "Zwei Bahnen Leinen. Für die Nächsten.", "Gut.", "Gutes Leinen. Das hält."),
         ("of_liesel_return_2", "Garn für die Spindel", "Vier Strang Garn.", "Gut.", "Vier. Danke.")],
        "Von acht bis neun, Totengräber, nicht länger. Ich tanz nicht gut. Ich tanz nur lang.",
        [C("[Geschichte] Kaspar", "story_1", ["step_offerable:washer", "!step_gte:washer:1", "flag:insight_not_lorenz"]),
         C("[Geschichte] Wiebke", "story_1_alt", ["step_offerable:washer", "!step_gte:washer:1", "!flag:insight_not_lorenz"]),
         C("Über Kaspars Stein", "story_1_done", ["flag:friend_washer_1", "!flag:p8_told_washer_1"], ["set_flag:p8_told_washer_1"]),
         C("[Geschichte] Ich sitz mit dir.", "story_2_vigil", ["order:of_liesel_2:accepted", "region:graveyard",
                                                                "time_between:1290:1439"], ["task:vigil"]),
         C("[Geschichte] Ich bin da.", "story_3_meet", ["order:of_liesel_3:accepted", "region:village"], ["meet:v_dorn_door"])],
        [N("story_1", "Er heißt nicht Lorenz. Er heißt Kaspar. Kaspar Dorn. Setz seinen Namen auf den Stein, Totengräber. "
           "Mit Tinte, ordentlich. Dann weiß wenigstens der Stein, wer er war.",
           [C("Das mache ich.", "story_1_yes", act=["step_accept:washer"]), C("Später.", "menu")],
           ["flag:insight_not_lorenz"], "story_1_alt"),
         N("story_1_alt", "Die Hagedorn. Halt ihr das Grab sauber, drei Morgen, und stell ihr eine Nacht ein Licht hin. Sie hat "
           "im Dunkeln nie schlafen können. Sie hat es keinem gesagt. Mir schon.",
           [C("Das mache ich.", "story_1_yes", act=["step_accept:washer"]), C("Später.", "menu")]),
         N("story_1_yes", "Gut. Ich seh nach. Nicht weil ich dir nicht trau. Weil ich nachseh.", back()),
         N("story_1_done", "Ich war oben. Hab's gesehen. Ich hab nichts gesagt, und du warst nicht da. Das war gut so.", back()),
         N("story_2_vigil", "Setz dich. Da, auf die Stufe. … Die mit dem Zeichen wasch ich anders. Langsamer. Ich fang beim "
           "Herzen an und hör beim Herzen auf. Lorenz hat gesagt, das ist Aberglaube. Ich hab gesagt: Dann wasch du sie.",
           back("(Bleiben)")),
         N("story_3_meet", "Hier stehen sie alle. Die mit dem Zeichen. Ich hab sie gewaschen und hineingeschrieben, damit sie "
           "nicht nur bei mir sind. Wenn ich sterbe, kommt das Buch mit mir hinunter. Versprich es.",
           [C("Ich verspreche es.", "story_3_promise", act=["set_flag:promise_liesel_book"])]),
         N("story_3_promise", "Sie schlägt die letzte Seite auf und wieder zu, bevor du lesen kannst. Dann legt sie das Buch "
           "zurück unter das Kissen. „Gut. Jetzt geh. Und sag es keinem. Auch Lenz nicht.“", back("(Gehen)"),
           ["insight:i_underlined"], "story_3_promise_plain"),
         N("story_3_promise_plain", "Gut. Jetzt geh. Und sag es keinem. Auch Lenz nicht.", back("(Gehen)"))])
    nodes.insert(0, hill("washer", "Ich bin bei meinen. Die Hagedorn und die anderen. Ich hab ihnen einen Faden gebracht. "
                         "Frag nicht, wofür."))
    patch(path("v_washer"), P, nodes, {"menu": menu}, {}, start="p8_hill")


# --- new dialogues ---------------------------------------------------------------------------------------------

def apprentice():
    nodes = [
        N("lights", "Für Vater. Der liegt nicht hier. Ich stell sie trotzdem hin.", back("Stell sie hin."),
          ["fest_today:lights", "region:graveyard"], "first"),
        N("first", "Mutter sagt, ich soll lernen, was die Leute brauchen, auch wenn sie es nicht wollen. Wo fang ich an, Herr "
          "Totengräber? Ich kann lesen. Und schnell laufen. Und ich hab keine Angst. Fast keine.",
          [C("An der Tafel. Da steht, was du tust.", "first_board"), C("Erst mal hörst du zu.", "menu")],
          ["!flag:p8_jakob_met"], "village", ["set_flag_day:p8_jakob_met"]),
        N("first_board", "Laub, Alter Hof. Das kann ich lesen. Das andere zeig ich mir dann, wenn du's mir zeigst.", back("Gut.")),
        N("village", "Morgen wieder? Mutter sagt, ich soll nicht so viel vom Hügel reden. Ich red trotzdem. Hier unten hört eh "
          "keiner zu, außer den Gläsern.", [C("Morgen wieder.", "menu_v"), C("Hilf deiner Mutter.", "")],
          ["region:village"], "early"),
        N("early", "Guten Morgen, Herr Totengräber! Was machen wir heute?", back(), ["!flag_days_gte:p8_jakob_met:3"], "greet"),
        N("greet", "Morgen. Was machen wir heute? Ich hab schon angefangen. Ein bisschen.", back()),
        N("menu", "Ja?", [
            C("Ich zeig dir, wie man Laub harkt.", "teach", ["apprentice_hired", "!apprentice_level_gte:rake:1"],
              ["apprentice_teach:rake"]),
            C("Ich zeig dir, wie man Unkraut jätet.", "teach", ["apprentice_hired", "!apprentice_level_gte:weed:1"],
              ["apprentice_teach:weed"]),
            C("Ich zeig dir, wie man Blumen gießt.", "teach", ["apprentice_hired", "!apprentice_level_gte:water:1"],
              ["apprentice_teach:water"]),
            C("Ich zeig dir, wie man eine Grabkerze anzündet.", "teach", ["apprentice_hired", "!apprentice_level_gte:candle:1"],
              ["apprentice_teach:candle"]),
            C("Gut gemacht.", "praised", ["apprentice_hired", "!flag_today:p8_jakob_judged"],
              ["apprentice_praise", "set_flag_day:p8_jakob_judged"]),
            C("Pass besser auf.", "scolded", ["apprentice_hired", "apprentice_mistake_today", "!flag_today:p8_jakob_judged"],
              ["apprentice_scold", "set_flag_day:p8_jakob_judged"]),
            C("Hilfst du mir mit dem Toten?", "dead"),
            C("Warum willst du das lernen?", "why"),
            C("Weiter so.", "")]),
        N("teach", "Ich schau zu. Ich sag nichts. Ich frag erst hinterher. Vielleicht.", back("Dann schau.")),
        N("praised", "Sag's Mutter. Nein, sag's ihr nicht, sonst wird sie stolz, und dann ist sie unerträglich.", back("Gut.")),
        N("scolded", "Ja, Herr Totengräber.", back("…")),
        N("dead", "Die Toten fasst du an. Das hat Mutter gesagt. Ich mach das Laub.", back("Recht hat sie.")),
        N("why", "Weil Vater kein Grab hat. Und weil oben einer sein muss, der es ordentlich macht, wenn einer eins hat. "
          "Das hab ich mir ausgedacht. Mutter weiß es nicht.", back("Ich sag's ihr nicht.")),
        N("menu_v", "Kann ich morgen früher kommen? Nein? Gut. Dann pünktlich.",
          [C("Hast du heute was gelernt?", "learned"), C("Bis morgen, Jakob.", "")]),
        N("learned", "Dass man das Laub von unten nach oben harkt. Nicht hin und her. Und dass die Kehr nicht weint, wenn man "
          "hinschaut. Nur wenn man weggeht.", [C("Das stimmt.", "menu_v")]),
    ]
    write_new(path("v_apprentice"), "v_apprentice", "Jakob Wackernagel", "lights", nodes)


def beggar():
    nodes = [
        N("first", "Hm. Ammer. Veit. Früher an der Holderfähre. Das Wasser hat siebzehn genommen und mich wieder ausgespuckt. "
          "Du bist der vom Hügel. Ich weiß. Ich seh dich jeden Morgen.", back("(Nicken)"), ["!flag:p8_veit_met"], "grell",
          ["set_flag:p8_veit_met"]),
        N("grell", "Der Grell hat Arbeit in der Ziegelei. Er lässt grüßen. Nicht dich, aber er meint dich.", back("(Nicken)"),
          ["robber_fate:let_go", "!flag:p8_veit_grell"], "lights", ["set_flag:p8_veit_grell"]),
        N("lights", "Ich trag keine. Meine liegen im Wasser. Ich steh am Tor und zähl, wer hinaufgeht. Das ist auch was.",
          back("(Nicken)"), ["fest_today:lights"], "night_ott"),
        N("night_ott", "Bei den Otts brennt Licht. Seit gestern. Heute kommt einer, vielleicht zwei. Setz dich, wenn du willst. "
          "Die Bank ist kalt, aber sie ist eine Bank.", back("(Setzen)"), ["time_between:1260:1410", "sick_light:house_ott",
                                                                            "clue_known:c_n_veit"], "night_kehr"),
        N("night_kehr", "Bei den Kehrs brennt Licht. Der Kleine. Fieber. Der Doktor war schon da, glaub ich. Der Pfarrer kommt "
          "noch. Die Dorn kommt nicht. Die kommt nur, wenn es so weit ist.", back("(Setzen)"),
          ["time_between:1260:1410", "sick_light:house_kehr", "clue_known:c_n_veit"], "night"),
        N("night", "Heute brennt nirgends Licht. Dann schlaf ich vielleicht. Vielleicht auch nicht.", back("(Nicken)"),
          ["time_between:1260:1410"], "greet"),
        N("greet", "Hm.", back()),
        N("menu", "(Veit sieht dich an und wartet.)", [
            C("[Almosen] Eine Münze für Veit.", "alms", ["has_item:coin:1", "!flag_today:p8_veit_alms"],
              ["alms", "set_flag_day:p8_veit_alms"]),
            C("[Zuhören]", "listen", ["mood:beggar:low", "!flag_today:p8_listen_beggar"],
              ["listen:beggar", "set_flag_day:p8_listen_beggar"]),
            C("Was siehst du nachts?", "three_again", ["clue_known:c_n_veit"]),
            C("Erzähl von der Fähre.", "ferry"),
            C("Wer gräbt da nachts?", "robber", ["robber_known"]),
            C("(Gehen)", "")]),
        N("alms", "Du gibst, ohne zu fragen, was ich damit mache. Lorenz hat auch nie gefragt. Setz dich, wenn du willst.",
          [C("(Sich setzen)", "three")], ["clue_known:c_n_veit", "!flag:p8_veit_told"], "alms_plain", ["set_flag:p8_veit_told"]),
        N("alms_plain", "Hm. (Er nickt.)", back("(Nicken)")),
        N("three", "Nachts gehen drei durchs Dorf. Der Pfarrer mit der Laterne, der Doktor mit dem Koffer, die Dorn mit dem Tuch. "
          "Wohin, sieht man am Fenster: wo das Krankenlicht brennt. Lorenz hat mich das auch gefragt. Ich hab's ihm gesagt. "
          "Danach hat er mir nie wieder was gegeben, nur noch genickt.", back("(Nicken)"), act=["add_clue:c_n_veit"]),
        N("three_again", "Drei. Immer dieselben. Der mit der Laterne bleibt am kürzesten. Die mit dem Tuch am längsten. Und der "
          "mit dem Koffer kommt, auch wenn keiner ruft. Das Wasser hat mich gelehrt, wer zu spät kommt. Die drei kommen nie "
          "zu spät.", back("(Nicken)")),
        N("listen", "Heute ist der Tag, an dem mein Bruder unten geblieben ist. Matthias. Er konnte schwimmen. Ich nicht. Das "
          "Wasser hat nicht danach gefragt. … Man sieht viel, wenn man schlecht schläft. Ich seh seitdem alles.", back("(Schweigen)")),
        N("ferry", "Das Wasser hat siebzehn genommen und mich wieder ausgespuckt. Seitdem schlaf ich schlecht. Man sieht viel, "
          "wenn man schlecht schläft. Die Fähre liegt noch unten, bei der Biegung. Bei Niedrigwasser sieht man den Mast.",
          back("(Nicken)")),
        N("robber", "Der Grell. Kommt von unten, durch den Wald hinter dem Lindenacker. Er kommt, wenn die Erde frisch ist und "
          "kein Licht brennt. Ein Licht hält ihn ab. Nicht weil er fromm ist. Weil er gesehen wird.", back("(Nicken)")),
    ]
    write_new(path("beggar"), "beggar", "Veit Ammer", "first", nodes)


def peddler():
    news = [
        "In Ellbach haben sie wieder eins offen gefunden. Leer war es nicht, nur offen. Das macht es nicht besser.",
        "Der Müller in Tannrode hat seine dritte Frau begraben. Die vierte hat schon abgesagt, bevor er gefragt hat. Kluge Frau.",
        "Unten im Tal frieren die Wege schon nachts. Ich geh trotzdem. Wer stehen bleibt, friert schneller.",
        "In der Stadt verkaufen sie Grabkerzen aus Paraffin. Die riechen nach Lampe. Meine riechen nach Biene. Merken Sie sich das.",
        "Der Pfarrer in Ellbach hat einen Hund angeschafft, für den Friedhof. Der Hund schläft. Der Pfarrer auch.",
        "Man sagt, in der Stadt zahlen sie für frische Tote mehr als für lebende Knechte. Ich sag nichts dazu. Ich verkaufe Kerzen.",
        "Die Schäfer kommen dieses Jahr früher von der Höhe. Es wird ein langer Winter, sagen sie. Das sagen sie jedes Jahr.",
        "Ich hab in Tannrode einen Brief für Hollerbrück. Für den Schultheiß. Er wird ihn zweimal lesen und einmal verstehen.",
    ]
    nodes = [
        N("first", "Hanne Vogelsang, mit der Kiepe, aus dem Tal und über den Hügel. Grabkerzen, Blumen, die den Winter "
          "aushalten, Tinte, Blattgold, Herzchen – nein, Sie nicht. Sie sind zu ernst. Totengräber also. Kaufen Sie was, "
          "dann reden wir.", back("Zeig her."), ["!flag:p8_hanne_met"], "gate", ["set_flag:p8_hanne_met"]),
        N("gate", "Grabkerzen, Herzchen – nein, Sie nicht, Sie sind zu ernst. Grabkerzen, Totengräber. Eine Münze das Stück, "
          "und sie brennen bis zum Hahnenschrei.", back(), ["region:graveyard"], "greet"),
        N("greet", "Da ist er ja, der Ernste. Heute hab ich Heide und Christrosen im Topf, und Kerzen, und einen Kranz aus Wachs "
          "für die, die keine Zeit zum Gießen haben. Rechnen Sie mit: zwei, eins, fünf. Ich rechne schneller.", back()),
        N("menu", "Na? Ich hab nicht ewig. Ich hab bis vier.", [
            C("Was hast du in der Kiepe?", "", ["shop_open:peddler"], ["open_shop:peddler"]),
            C("Was gibt's Neues im Tal?", "news_1"),
            C("Der Wachskranz – lohnt der?", "wreath"),
            C("Wohin gehst du von hier?", "where"),
            C("Bis in sechs Tagen.", "")]),
        N("wreath", "Der hält ewig und welkt nie. Aber er riecht nach nichts, und die Toten merken das, sagt man. Wachs riecht "
          "nicht. Ich verkauf ihn trotzdem. Die Lebenden riechen ja auch nicht hin.", back("Verstehe.")),
        N("where", "Über den Hügel, den Waldweg nach Westen hinauf, wo die Händlerin mit dem Karren auch geht. Ich kenn sie "
          "nicht. Ich seh sie nur. Wir grüßen uns nicht. Das ist eine Abmachung.", back("Gute Reise.")),
    ]
    for i, text in enumerate(news):
        k = i + 1
        cond = ["!flag:p8_hanne_news_%d" % k] if k < len(news) else []
        act = ["set_flag:p8_hanne_news_%d" % k] if k < len(news) else ["clear_flag:p8_hanne_news_%d" % j for j in range(1, len(news))]
        nodes.append(N("news_%d" % k, text, back("So."), cond, "news_%d" % (k + 1) if k < len(news) else "", act))
    write_new(path("peddler"), "peddler", "Hanne Vogelsang", "first", nodes)


def robber():
    nodes = [
        N("start", "(Er sitzt im Aushub und hält den Spaten fest, als könnte er ihm helfen.) Ich nehm nichts. Ich hab noch nie "
          "was genommen. Ich komm nicht tief genug, bevor es hell wird. Das weiß er, und er zahlt trotzdem.",
          [C("Wer zahlt dich?", "who"), C("Steh auf. Wir gehen zum Schultheiß.", "reported", act=["robber_resolve:reported"]),
           C("Lauf. Und komm nicht wieder.", "let_go", act=["robber_resolve:let_go"])]),
        N("who", "Ein Herr mit einem Koffer. Er riecht nach Branntwein und zahlt für Frische. Er sagt, für die Wissenschaft. "
          "Mehr weiß ich nicht. Ich frag nicht. Wer fragt, kriegt weniger.",
          [C("Steh auf. Wir gehen zum Schultheiß.", "reported", act=["robber_resolve:reported"]),
           C("Lauf. Und komm nicht wieder.", "let_go", act=["robber_resolve:let_go"])], act=["add_clue:c_n_robber"]),
        N("reported", "Ja. Ist recht. Ich hab's mir gedacht, dass einer wie Sie nicht schläft. Darf ich den Spaten dalassen? "
          "Er gehört mir nicht.", [C("(Ihn hinunterbringen)", "")]),
        N("let_go", "Danke. Ich … danke. Ich komm nicht wieder. Ich weiß nicht, wohin ich soll, aber hierher nicht.",
          [C("(Ihm nachsehen)", "")]),
    ]
    write_new(path("robber"), "robber", "Lambert Grell", "start", nodes)


def kin(kin_id, speaker, first, greet, wish, wish_yes, wish_no, tip, who, extra_first=None):
    nodes = []
    if extra_first:
        nodes.append(extra_first)
    nodes += [
        N("first", first, back(), ["!flag:p8_met_%s" % kin_id], "greet", ["set_flag:p8_met_%s" % kin_id]),
        N("greet", greet, back()),
        N("menu", "(%s wartet.)" % speaker.split(" ")[0], [
            C("[Trinkgeld] …", "tip", ["tip_due"], ["tip_hand"]),
            C("[Wunsch] Kann ich etwas für das Grab tun?", "wish", ["wish_offerable"], ["wish_offer"]),
            C("Wer liegt hier?", "who"),
            C("Ich lass Sie allein.", "")]),
        N("wish", wish, [C("Das mache ich.", "wish_yes", act=["wish_accept"]), C("Ich kann es nicht versprechen.", "wish_no")]),
        N("wish_yes", wish_yes, back()),
        N("wish_no", wish_no, back()),
        N("tip", tip, back("Danke.")),
        N("who", who, back()),
    ]
    start = nodes[0].id
    write_new(path(kin_id), kin_id, speaker, start, nodes)


def kins():
    kin("kin_kehr", "Martha Kehr",
        "Grüß Gott. Ich bleib nicht lange. Bei uns hat nie einer lange gestanden. Kehr. Martha. Sie kennen uns, Sie haben "
        "einen von uns hingelegt.",
        "Grüß Gott. Ich bleib nicht lange.",
        "Ein paar Blumen. Heide, wenn's geht, die hält den Winter. Ich komm in drei Tagen wieder.",
        "Gut. Ich sag's keinem. Dann ist es eine Überraschung, auch für mich.",
        "Na ja. Sie haben viele.",
        "Heide. Sie haben es nicht vergessen. Hier, nimm. Nein, nimm es. Ich hab's schon im Korb gezählt.",
        "Einer von uns. Mehr muss man nicht wissen. Er hat Laub nie leiden können, und jetzt liegt er drunter. So ist das.")
    kin("kin_brandt", "Hinrich Brandt",
        "Guten … Tag. Brandt. Hinrich. Ich – danke. Dass ich hier stehen darf. Danke.",
        "Ich … danke. Ich bleib nur kurz. Danke.",
        "Könnten Sie … wenn es keine Mühe macht … eine Kerze? Eine Nacht. Hier oben ist es so dunkel. Danke. Verzeihung. Danke.",
        "Danke. Wirklich. Danke.",
        "Natürlich. Natürlich. Danke trotzdem.",
        "Für Sie. Nein, nehmen Sie. Danke. Ich weiß nicht, wie man das richtig macht. Danke.",
        "Mein … ja. Unserer. Ich hab ihn gefahren, früher, mit dem Fuhrwerk. Jetzt fährt ihn keiner mehr. Danke, dass er "
        "liegt.")
    kin("kin_ott", "Gesa Ott",
        "War er schwer? Ich mein nicht beim Tragen. Ich mein am Ende. … Sie müssen nicht antworten. Ich frag nur, weil keiner "
        "mir was sagt. Liesel sagt, er hat ruhig geschlafen. Liesel sagt das immer.",
        "Sie schon wieder. Gut. Sie sind der Einzige, der mir antwortet, wenn ich frag.",
        "Strohblumen hab ich gebracht. Die halten länger als er. Machen Sie, dass sie stehen bleiben? Eine Vase, oder ein Stein "
        "dahinter. Und sagen Sie mir, wann der Doktor zuletzt da war. Nein. Sagen Sie's mir nicht.",
        "Danke. Ich frag nicht, wie. Ich frag sonst alles.",
        "Wenigstens sagen Sie es ehrlich.",
        "Für Sie. Vater hätte gesagt, das ist zu viel. Vater hat nie was zu viel gegeben, nur zu wenig Zeit.",
        "Mein Vater. Gerhard Ott. Vierundsiebzig. Drei waren da, in der letzten Woche. Der Pfarrer, der Doktor und die Dorn. "
        "Ich hab sie alle reingelassen. Ich weiß nicht, ob man das darf, sich zu fragen, warum.")
    kin("kin_sieber", "Johann Sieber",
        "(Er redet mit dem Grab, nicht mit dir.) So, Grete. Da ist der Neue. Der gräbt ordentlich, sagen sie. Ich sag nichts. "
        "Ich schau es mir an.",
        "(Zum Grab.) So, Grete. Der Totengräber hat gefegt. Jetzt hast du es besser als ich.",
        "(Zum Grab.) Grete, soll er's dir sauber halten, bis ich wiederkomm? Ja? Sie nickt. Sie hat immer genickt, wenn sie "
        "Nein gemeint hat. Diesmal mein ich, sie meint Ja.",
        "(Zum Grab.) Hörst du, Grete? Er macht's.",
        "(Zum Grab.) Er kann's nicht versprechen, Grete. Ehrlich ist er. Das ist schon was.",
        "(Er legt dir Münzen in die Hand, ohne hinzusehen.) Für dich, Grete. Nein, für ihn. Du brauchst ja nichts mehr.",
        "(Zum Grab.) Er fragt, wer du bist, Grete. Einundfünfzig Jahre, sag ich ihm. Mehr nicht. Den Rest weißt du.")


def lights_lenz():
    nodes = [
        N("speech", "Wir zünden kein Licht für Gott an. Der sieht auch so. Wir zünden es für die an, die den Weg vergessen "
          "haben. Und für die, die noch hier unten sind und ihn suchen.",
          [C("[Geschichte] Die Namen lesen.", "names", ["order:of_lenz_3:accepted"], ["task:lights_names"]),
           C("(Schweigen)", "")], ["fest_running:lights"], "after"),
        N("names", "Dann lesen Sie. Langsam. Jeder Name braucht einen Atemzug, und wir haben genug davon heute Abend. "
          "Ich lese den Tag, Sie lesen den Namen.", [C("(Die Namen lesen)", "names_done")]),
        N("names_done", "… Amen. Das war gut. Hören Sie die Glocke? Die läutet nicht für uns.", [C("(Schweigen)", "")]),
        N("after", "Gehen Sie nach Hause, Totengräber. Ach, Sie sind ja zu Hause. Dann gehe ich. Die Lichter brennen auch "
          "ohne uns.", [C("Gute Nacht, Herr Pfarrer.", "")]),
    ]
    write_new(path("lights_lenz"), "lights_lenz", "Pfarrer Ambrosius Lenz", "speech", nodes)


def main():
    carter()
    carter_village()
    trader()
    innkeeper()
    smith()
    grocer()
    priest()
    mayor()
    surgeon()
    washer()
    apprentice()
    beggar()
    peddler()
    robber()
    kins()
    lights_lenz()
    print("Phase-8 dialogues written to", DLG)


if __name__ == "__main__":
    main()
