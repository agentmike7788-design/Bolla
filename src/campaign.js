import { scenarioById } from './scenarios.js';

// The campaign: the mission maps as one story in chapters. A map opens once the
// one before it is done, and every map done in the campaign lets the player pick
// a keepsake (a small boost) that comes along to all later campaign maps.
//
//   CHAPTERS   id/name/text and the maps of each chapter, in order
//   STORY      per map: brief for the campaign card, radio lines when it starts,
//              when each later mission starts (index = mission), when it is done,
//              and the keepsakes offered at the end
//   VOICES     who talks on the radio
//
// Radio lines are [voice, text]. `npm run balance` checks that every mission map
// is in the campaign once and that the mission lines fit the missions.

export const VOICES = {
  mara: { name: 'Mara', role: 'Leitstelle', icon: '📻', color: '#ffd34d' },
  okke: { name: 'Okke', role: 'Chefingenieur', icon: '🔧', color: '#7fd4ff' },
  sanna: { name: 'Sanna', role: 'Kundschafterin', icon: '🛩️', color: '#7ee08a' },
  lind: { name: 'Prof. Lind', role: 'Raumfahrt', icon: '🔭', color: '#ff8a5c' },
};

export const CHAPTERS = [
  {
    id: 'arrival',
    name: 'Ankunft',
    text: 'Der Große Sturm hat die Funkmasten des Archipels umgeworfen. Keine Verbindung, keine Lieferungen. Die Leitstelle schickt dich mit einem Bohrer und einer Kiste Bänder los.',
    maps: ['ironHills', 'copperDesert'],
  },
  {
    id: 'steel',
    name: 'Feuer und Stahl',
    text: 'Eisen und Kupfer laufen. Für Brücken, Kräne und Masten braucht das Archipel Stahl, und für Stahl braucht es Kohle und Strom.',
    maps: ['coalIsland', 'frostFjord'],
  },
  {
    id: 'mainland',
    name: 'Das Festland',
    text: 'Auf dem Festland liegt alles, was die Inseln brauchen, nur weit auseinander. Schaltkreise, Öl und Eisenbahnen machen aus einzelnen Werken ein Netz.',
    maps: ['mainland', 'oilCoast', 'railLands'],
  },
  {
    id: 'unrest',
    name: 'Unruhige Erde',
    text: 'Das Netz wächst, und die Erde wehrt sich. Ein Vulkan grollt, Drohnen schwirren, und im Süden regt sich etwas in den Hügeln.',
    maps: ['hub', 'volcano', 'bugLands'],
  },
  {
    id: 'beacon',
    name: 'Leuchtfeuer',
    text: 'Professorin Lind hat einen Plan: ein Satellit, der alle Inseln wieder verbindet. Das Leuchtfeuer. Dafür braucht es saubere Energie und eine Rakete.',
    maps: ['sunCoast', 'starport'],
  },
];

// Keepsakes: small boosts that stack, one picked per map done in the campaign.
export const PERKS = {
  drill: { name: 'Gehärtete Bohrköpfe', text: 'Bohrer +10 %', icon: '⛏️', boosts: { drill: 1.1 } },
  belt: { name: 'Geölte Rollen', text: 'Bänder +10 %', icon: '🔄', boosts: { belt: 1.1 } },
  furnace: { name: 'Schamottziegel', text: 'Öfen +10 %', icon: '🔥', boosts: { furnace: 1.1 } },
  workshop: { name: 'Präzisionswerkzeug', text: 'Pressen und Konstruktoren +10 %', icon: '🛠️', boosts: { assembler: 1.1, constructor: 1.1 } },
  power: { name: 'Neue Turbinenschaufeln', text: 'Kraftwerke +15 %', icon: '⚡', boosts: { power: 1.15 } },
  oil: { name: 'Druckventile', text: 'Pumpen und Raffinerien +15 %', icon: '🛢️', boosts: { pump: 1.15, refinery: 1.15 } },
  train: { name: 'Leichtbauwaggons', text: 'Züge +15 %', icon: '🚂', boosts: { train: 1.15 } },
  drone: { name: 'Kohlefaserrotoren', text: 'Drohnen +15 %', icon: '🚁', boosts: { drone: 1.15 } },
  weapons: { name: 'Panzerbrechende Munition', text: 'Türme +15 % Schaden', icon: '🎯', boosts: { weapons: 1.15 } },
  green: { name: 'Spiegelglas', text: 'Solar und Wind +15 %', icon: '☀️', boosts: { renewable: 1.15 } },
  battery: { name: 'Dichte Zellen', text: 'Akkus +20 %', icon: '🔋', boosts: { battery: 1.2 } },
};

export const STORY = {
  ironHills: {
    brief: 'Ein felsiges Tal voller Eisen. Hier beginnt alles: Bohrer, Bänder, ein Lager.',
    intro: [
      ['mara', 'Leitstelle an Werksleitung, hörst du mich? Gut. Willkommen in den Eisenbergen.'],
      ['mara', 'Seit dem Sturm ist das Archipel abgeschnitten. Wir bauen von vorn auf, und du fängst an.'],
      ['okke', 'Okke hier, Werkstatt. Setz zwei Bohrer aufs Eisen und leg ein Band zum Lager. Der Rest kommt von allein.'],
    ],
    missions: [
      null,
      [['okke', 'Erz allein baut keine Brücke. Ich schick dir einen Schmelzofen. Band rein, Barren raus.']],
      [['okke', 'Barren sind gut, Platten sind besser. Die Presse kann beides, Platten aus Eisen und Beton aus Kalkstein.']],
      [['okke', 'Der Konstruktor ist da. Klick ihn an und stell das Rezept auf Zahnrad. Zwei Platten, ein Zahnrad.']],
      [['mara', 'Die Leitstelle braucht einen stetigen Strom an Zahnrädern und Beton. Verteiler helfen, ein Ofen allein schafft das nicht.']],
    ],
    outro: [
      ['mara', 'Die Eisenberge laufen! Das erste Werk seit dem Sturm.'],
      ['okke', 'Nimm etwas mit auf die Reise. Ich hab dir was zurückgelegt.'],
    ],
    perks: ['drill', 'belt', 'furnace'],
  },
  copperDesert: {
    brief: 'Heißer Sand und Kupfer, so weit das Auge reicht. Für Funkmasten braucht es Draht, viel Draht.',
    intro: [
      ['sanna', 'Sanna hier, ich überfliege gerade die Kupferwüste. Rote Adern im Sand, überall.'],
      ['mara', 'Jeder Funkmast braucht kilometerweise Kupferdraht. Der Ofen steht schon, leg los.'],
    ],
    missions: [
      null,
      [['okke', 'Die Presse zieht Draht aus Kupferbarren. Und der Beton wird für die Mastfundamente gebraucht.']],
      [['sanna', 'Im Süden zieht ein Sandsturm auf. Bau mehrere Linien, eine allein bringt keine 45 Draht in der Minute.']],
      [['mara', 'Die großen Masten sind bestellt. Drei Drahtlinien und Beton dazu, dann steht die erste Funkstrecke.']],
    ],
    outro: [
      ['mara', 'Funkstrecke eins steht! Ich höre die Kohleinsel, schwach, aber ich höre sie.'],
      ['okke', 'Da drüben gibt es Kohle. Kohle heißt Stahl. Pack ein, wir ziehen weiter.'],
    ],
    perks: ['furnace', 'workshop', 'belt'],
  },
  coalIsland: {
    brief: 'Eine enge Insel mit Kohle und Eisen. Wenig Platz, aber genug für das erste Stahlwerk.',
    intro: [
      ['sanna', 'Landung auf der Kohleinsel. Eng hier, plan deine Bänder gut.'],
      ['okke', 'Kohle und Eisen in einen Konstruktor, und raus kommt Stahl. Der Stoff, aus dem Brücken sind.'],
    ],
    missions: [
      null,
      [['okke', 'Zwei Eisenbarren, eine Kohle, ein Stahlträger. Stell den Konstruktor auf Stahl.']],
      [['okke', 'Jetzt wird es ernst: ein Kraftwerk. Kohle rein, Masten ziehen. Am Netz arbeiten Maschinen doppelt so schnell.']],
      [['mara', 'Der Hafen will Kräne bauen. Stahl und Zahnräder, bitte.']],
      [['mara', 'Die Inseln brauchen Stahl am laufenden Band. Zwanzig Träger in der Minute, dann verschiffen wir.']],
    ],
    outro: [
      ['mara', 'Das erste Stahlwerk des Archipels. Die Fähren fahren wieder!'],
      ['sanna', 'Im Norden ist es kalt geworden. Der Frostfjord braucht Hilfe.'],
    ],
    perks: ['power', 'drill', 'workshop'],
  },
  frostFjord: {
    brief: 'Schnee und gefrorene Seen. Ohne Strom laufen die Maschinen nur halb so gut, und Schneestürme bremsen die Bänder.',
    intro: [
      ['sanna', 'Frostfjord. Minus zwanzig Grad und Schnee bis zu den Knien. Die Polarstation ist dunkel.'],
      ['okke', 'In der Kälte laufen die Maschinen nur mit 60 Prozent. Erst Eisen und Kohle, dann machen wir Wärme.'],
    ],
    missions: [
      null,
      [['okke', 'Kraftwerk an, Masten ziehen. Mit Strom laufen die Hallen warm und die Maschinen schnell.']],
      [['mara', 'Die Station braucht Platten und Draht für neue Leitungen über das Eis.']],
      [['okke', 'Schaltkreise! Platte und Draht in den Konstruktor. Die Polarstation braucht ein neues Gehirn.']],
      [['mara', 'Die Station hört wieder zu. Halt die Schaltkreise und den Stahl am Laufen, dann kann sie senden.']],
    ],
    outro: [
      ['mara', 'Die Polarstation sendet wieder! Polarlicht über dem ganzen Fjord.'],
      ['mara', 'Und weißt du was? Wir haben Kontakt zum Festland. Kapitel zwei ist geschafft.'],
    ],
    perks: ['power', 'furnace', 'belt'],
  },
  mainland: {
    brief: 'Das Festland: alle Erze, aber weit verstreut. Die Meisterprüfung für jede Werksleitung.',
    intro: [
      ['sanna', 'Das Festland liegt unter mir. Eisen, Kupfer, Kohle, Kalkstein, alles da, nur weit auseinander.'],
      ['mara', 'Erkunde zuerst. Bring von jedem Erz eine Probe ins Lager.'],
    ],
    missions: [
      null,
      [['okke', 'Grundstoffe zuerst: Platten und Draht. Ohne die geht hier nichts.']],
      [['okke', 'Jetzt die ersten Schaltkreise. Das Festland soll denken lernen.']],
      [['mara', 'Das große Bauprogramm: Zahnräder, Stahl, Beton, und alles mit Strom.']],
      [['okke', 'Die Meisterprüfung. Schaltkreise und Stahl in Massen. Ich weiß, dass du das kannst.']],
    ],
    outro: [
      ['okke', 'Bestanden. Mit Auszeichnung, wenn du mich fragst.'],
      ['sanna', 'An der Westküste blubbert etwas Schwarzes aus dem Boden. Das solltest du dir ansehen.'],
    ],
    perks: ['workshop', 'drill', 'power'],
  },
  oilCoast: {
    brief: 'Schwarze Pfützen an der Küste. Pumpen, Rohre und eine Raffinerie machen Kunststoff für Prozessoren.',
    intro: [
      ['sanna', 'Öl! Die ganze Küste glänzt schwarz.'],
      ['okke', 'Pumpen brauchen Strom. Erst ein Kraftwerk, dann sehen wir weiter.'],
    ],
    missions: [
      null,
      [['okke', 'Pumpen auf die Ölfelder, Rohre zum Tank. Schwarzes Gold, Werksleitung.']],
      [['okke', 'Die Raffinerie macht aus Öl Kunststoff und Treibstoff. Klick sie an und wähl das Rezept.']],
      [['mara', 'Kunststoff und Schaltkreise ergeben Prozessoren. Das sind die Gehirne für alles, was noch kommt.']],
      [['mara', 'Die Petrochemie soll laufen, ohne dass wir hinsehen müssen. Kunststoff und Prozessoren am laufenden Band.']],
    ],
    outro: [
      ['mara', 'Prozessoren aus eigener Produktion. Das Archipel kann wieder rechnen.'],
      ['sanna', 'Das Land im Osten ist riesig. Zu Fuß kommst du da nicht weit.'],
    ],
    perks: ['oil', 'power', 'workshop'],
  },
  railLands: {
    brief: 'Eine große Insel mit Erzen an beiden Enden. Ohne Eisenbahn geht hier nichts.',
    intro: [
      ['sanna', 'Weites Land. Eisen und Kohle im Nordwesten, Kupfer und Kalkstein im Südosten. Dazwischen nur Gras.'],
      ['okke', 'Bänder schaffen diese Strecken nicht. Wir bauen eine Eisenbahn. Zwei Bahnhöfe und Gleise dazwischen.'],
    ],
    missions: [
      null,
      [['okke', 'Gleise liegen. Jetzt einen Zug drauf und die erste Fracht ausladen.']],
      [['mara', 'Die Züge rollen! Mit dem Erz von beiden Enden kannst du Schaltkreise bauen.']],
      [['mara', 'Der Stahlexpress: Stahl und Zahnräder für neue Brücken.']],
      [['okke', 'Jetzt muss der Güterverkehr richtig laufen. Viele Teile, viele Fahrten.']],
    ],
    outro: [
      ['mara', 'Das Weite Land ist verbunden. Kapitel drei ist geschafft!'],
      ['sanna', 'Aber ich sehe Rauch über dem Süden. Und Bewegung in den Hügeln. Das gefällt mir nicht.'],
    ],
    perks: ['train', 'belt', 'oil'],
  },
  hub: {
    brief: 'Vier Erze in vier Ecken, die Fabrik in der Mitte. Viele Züge brauchen Signale, und die letzten Meter fliegen Drohnen.',
    intro: [
      ['mara', 'Das Drehkreuz soll alle Linien des Südens bündeln. Vier Ecken, eine Mitte.'],
      ['okke', 'Mehrere Züge auf denselben Gleisen. Fang mit drei Bahnhöfen und zwei Zügen an.'],
    ],
    missions: [
      null,
      [['okke', 'Ohne Signale krachen die Züge zusammen. Setz Signale, dann fahren sie hintereinander.']],
      [['sanna', 'Für die letzten Meter gibt es jetzt Drohnen. Ein Hafen, Angebotskisten, Anfragekisten, und los.']],
      [['mara', 'Schaltkreise aus der Mitte, geliefert von Drohnen. So soll ein Drehkreuz aussehen.']],
      [['mara', 'Das Drehkreuz läuft im Dauerbetrieb. Schaltkreise und Züge, Tag und Nacht.']],
    ],
    outro: [
      ['mara', 'Das Drehkreuz summt wie ein Bienenstock. Wunderbar.'],
      ['lind', 'Lind hier, Sternwarte. Ich habe einen Vorschlag, aber dafür braucht ihr erst die Glutinsel.'],
    ],
    perks: ['drone', 'train', 'workshop'],
  },
  volcano: {
    brief: 'Eine Vulkaninsel mit reichen Erzen. Dampfende Quellen liefern Strom ohne Kohle, und manchmal regnet es Asche.',
    intro: [
      ['lind', 'Unter dem Glutkessel kocht die Erde. Diese Wärme können wir nutzen.'],
      ['okke', 'Erst die Grundlagen: Eisen und Kupfer schmelzen. Bei der Hitze geht das fast von selbst.'],
    ],
    missions: [
      null,
      [['lind', 'Setz Erdwärmekraftwerke auf die dampfenden Quellen. Strom ohne Kohle, solange der Berg atmet.']],
      [['okke', 'Vulkanstahl und Beton. Hart wie Basalt.']],
      [['mara', 'Schaltkreise und Zahnräder für die Sternwarte. Professorin Lind baut etwas Großes.']],
      [['sanna', 'Der Berg grollt. Halt die Produktion am Laufen, egal was vom Himmel fällt.']],
    ],
    outro: [
      ['lind', 'Hervorragend. Mit dieser Energie können wir an mein Projekt denken.'],
      ['sanna', 'Werksleitung, dringend! Im Käferland haben sich Nester ausgebreitet. Sie greifen alles an, was raucht.'],
    ],
    perks: ['power', 'weapons', 'furnace'],
  },
  bugLands: {
    brief: 'Grüne Hügel voller Nester. Jeder Bohrer macht Smog, und Smog lockt die Krabbler an. Erst Türme, dann zurückschlagen.',
    intro: [
      ['sanna', 'Käferland. Überall Nester, und die Viecher hassen unseren Smog.'],
      ['okke', 'Wir brauchen erst Platten und Kupfer. Dann bauen wir Türme. Beeil dich, bevor die erste Welle kommt.'],
    ],
    missions: [
      null,
      [['okke', 'Geschütztürme, und der Konstruktor macht Munition. Mauern davor schaden auch nicht.']],
      [['sanna', 'Da kommen sie! Halt die Linie, Werksleitung!']],
      [['mara', 'Genug verteidigt. Bring Türme an die Nester heran und räum auf.']],
    ],
    outro: [
      ['sanna', 'Die Hügel sind ruhig. Die Krabbler ziehen sich zurück.'],
      ['mara', 'Kapitel vier ist geschafft. Ab jetzt bauen wir sauberer, damit wir sie nicht wieder wecken.'],
    ],
    perks: ['weapons', 'green', 'drill'],
  },
  sunCoast: {
    brief: 'Eine sonnige Wüstenküste mit wenig Kohle und wachsamen Nestern. Hier läuft die Fabrik auf Sonne, Wind und Akkus.',
    intro: [
      ['lind', 'Das Leuchtfeuer wird ein Satellit, der alle Inseln verbindet. Aber eine Raketenfabrik voller Schornsteine weckt die Nester.'],
      ['lind', 'Die Sonnenküste ist der Versuch: eine Fabrik ganz ohne Kohle.'],
      ['okke', 'Erst Platten und Draht, dann kommen die Solarpanels.'],
    ],
    missions: [
      null,
      [['okke', 'Solarpanels an die Masten. Mittags liefern sie voll, nachts gar nichts.']],
      [['lind', 'Windräder drehen sich auch nachts. Stell sie nicht zu dicht, sonst nehmen sie sich den Wind.']],
      [['okke', 'Akkus speichern den Strom vom Tag für die Nacht. Und nebenbei brauchen wir Schaltkreise.']],
      [['lind', 'Jetzt muss die ganze Fabrik grün laufen. Das ist die Probe für den Sternenhafen.']],
    ],
    outro: [
      ['lind', 'Die Wüste ist grün, die Nester schlafen. Wir sind bereit.'],
      ['mara', 'Letzte Station, Werksleitung: der Sternenhafen.'],
    ],
    perks: ['green', 'battery', 'oil'],
  },
  starport: {
    brief: 'Das Finale: eine weite Küste mit allem, was die Erde hergibt. Hier baust du die Rakete für das Leuchtfeuer.',
    intro: [
      ['mara', 'Alle Inseln hören heute zu. Das ganze Archipel wartet auf das Leuchtfeuer.'],
      ['lind', 'Wir brauchen ein Fundament: Stahl, Beton und Strom.'],
    ],
    missions: [
      null,
      [['lind', 'Kunststoff und Prozessoren für die Bordelektronik. Der Satellit muss allein im All zurechtkommen.']],
      [['okke', 'Das Raketensilo. Das größte Ding, das wir je gebaut haben.']],
      [['lind', 'Rumpf und Bordcomputer. Jede Etappe braucht ihre Teile.']],
      [['mara', 'Treibstoff ist in den Tanks. Klick das Silo an und drück auf Start. Wir zählen mit.']],
    ],
    outro: [
      ['lind', 'Satellit getrennt. Antennen offen. Das Leuchtfeuer sendet!'],
      ['mara', 'Ich höre sie alle. Die Eisenberge, die Wüste, den Fjord, das Festland. Das ganze Archipel.'],
      ['okke', 'Gute Arbeit, Werksleitung. Wirklich gute Arbeit.'],
    ],
    perks: [],
  },
};

// All campaign maps in order, each with its chapter.
export const CAMPAIGN = CHAPTERS.flatMap((c, chapter) => c.maps.map((id) => ({ id, chapter })));
export const campaignIndex = (id) => CAMPAIGN.findIndex((m) => m.id === id);
export const chapterIndexOf = (id) => CAMPAIGN[campaignIndex(id)]?.chapter ?? -1;
// True for the first map of a chapter: it opens with the chapter's title card.
export const opensChapter = (id) => CHAPTERS.some((c) => c.maps[0] === id);
export const nextCampaignMap = (id) => {
  const next = CAMPAIGN[campaignIndex(id) + 1];
  return next ? scenarioById(next.id) : null;
};

// Progress, kept in this browser: maps done in the campaign and the keepsake
// picked on each.
const KEY = 'bolla.campaign';
export function loadCampaign() {
  let data = null;
  try {
    data = JSON.parse(localStorage.getItem(KEY));
  } catch {}
  return { done: data?.done ?? {}, perks: data?.perks ?? {} };
}
function store(progress) {
  try {
    localStorage.setItem(KEY, JSON.stringify(progress));
  } catch {
    // Storage blocked: progress lasts for this session only.
  }
  return progress;
}
export function finishCampaignMap(id) {
  const p = loadCampaign();
  p.done[id] = true;
  return store(p);
}
export function pickPerk(id, perk) {
  const p = loadCampaign();
  if (!p.perks[id] && STORY[id]?.perks.includes(perk)) p.perks[id] = perk;
  return store(p);
}

// A map opens once the map before it is done, in the campaign or on its own.
export function isUnlocked(id, progress, records) {
  const i = campaignIndex(id);
  if (i <= 0) return i === 0;
  const prev = CAMPAIGN[i - 1].id;
  return !!(progress.done[prev] || records[prev]);
}

// Keepsakes picked on the maps before `id`: they come along to that map.
export function perksFor(id, progress) {
  const i = campaignIndex(id);
  return CAMPAIGN.slice(0, Math.max(0, i))
    .map((m) => progress.perks[m.id])
    .filter((p) => PERKS[p]);
}
