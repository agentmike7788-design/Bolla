// Save games, kept in this browser's localStorage: a small index with a
// preview picture per game, and the game data itself under its own key.
// A save can also leave the browser as a .json file and come back in.

const INDEX_KEY = 'bolla.saves';
const dataKey = (id) => `bolla.save.${id}`;
const FORMAT = 'bolla-save';
export const SAVE_VERSION = 7; // 2: power plants and poles, 3: oil fields, pumps and pipes, 4: railways and trains, 5: rocket silo and statistics, 6: signals and drones, 7: biomes and geothermal plants

export const newSaveId = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 6);

// All saves, newest first.
export function listSaves() {
  try {
    const list = JSON.parse(localStorage.getItem(INDEX_KEY));
    return Array.isArray(list) ? list.sort((a, b) => b.savedAt - a.savedAt) : [];
  } catch {
    return [];
  }
}

// Returns false when the browser refuses (storage full or blocked).
export function writeSave(meta, data) {
  try {
    localStorage.setItem(dataKey(meta.id), JSON.stringify(data));
    const list = listSaves().filter((s) => s.id !== meta.id);
    list.push(meta);
    localStorage.setItem(INDEX_KEY, JSON.stringify(list));
    return true;
  } catch {
    return false;
  }
}

export function readSave(id) {
  try {
    const data = JSON.parse(localStorage.getItem(dataKey(id)));
    return data?.v ? data : null;
  } catch {
    return null;
  }
}

export function deleteSave(id) {
  try {
    localStorage.removeItem(dataKey(id));
    localStorage.setItem(INDEX_KEY, JSON.stringify(listSaves().filter((s) => s.id !== id)));
  } catch {}
}

// Offers the save as a file download. Resolves false when it could not be read
// or the viewer declined. Inside a claude.ai artifact the page may not download
// on its own, so the viewer's download prompt is used there.
export async function exportSave(id) {
  const meta = listSaves().find((s) => s.id === id);
  const data = readSave(id);
  if (!meta || !data) return false;
  const text = JSON.stringify({ format: FORMAT, meta, data });
  const name = meta.name.replace(/[^\wäöüÄÖÜß-]+/g, '-').replace(/^-|-$/g, '');
  const filename = `bolla-${name || 'spielstand'}.json`;
  const downloads = window.claude?.use ? await window.claude.use('downloads').catch(() => null) : null;
  if (downloads) {
    try {
      await downloads.save({ filename, data: text });
      return true;
    } catch {
      return false;
    }
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([text], { type: 'application/json' }));
  a.download = filename;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  return true;
}

// Reads an exported file back in as a new save. Throws with a message for the player.
export function importSave(text) {
  let file;
  try {
    file = JSON.parse(text);
  } catch {
    throw new Error('Das ist keine Spielstand-Datei.');
  }
  if (file?.format !== FORMAT || !file.meta || !file.data?.v) throw new Error('Das ist keine Spielstand-Datei.');
  if (file.data.v > SAVE_VERSION) throw new Error('Der Spielstand ist von einer neueren Version des Spiels.');
  const meta = { ...file.meta, id: newSaveId(), savedAt: Date.now() };
  if (!writeSave(meta, file.data)) throw new Error('Kein Platz mehr im Browser. Lösche einen alten Spielstand.');
  return meta;
}

// "Heute, 14:02", "Gestern, 09:15" or "03.10., 14:02".
export function whenText(ms) {
  const d = new Date(ms);
  const time = d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  const day = new Date();
  day.setHours(0, 0, 0, 0);
  if (d >= day) return `Heute, ${time}`;
  if (d >= day - 86400000) return `Gestern, ${time}`;
  return `${d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' })}, ${time}`;
}

// "8 min" or "2 h 05 min".
export function playTimeText(seconds) {
  const m = Math.floor(seconds / 60);
  return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')} min`;
}
