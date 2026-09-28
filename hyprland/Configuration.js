.import "../package/contents/ui/studio/Looks.js" as Looks
.import "../package/contents/ui/Sections.js" as Sections
// Read the same defaults KConfig uses for Plasma; do not maintain a second list.
function defaults(xml) {
    const result = {};
    const entries = /<entry\s+name="([^"]+)"\s+type="([^"]+)"\s*>\s*<default>([^<]*)<\/default>/g;
    let entry;
    while ((entry = entries.exec(xml)) !== null) {
        const type = entry[2];
        const value = entry[3];
        result[entry[1]] = type === "Bool" ? value === "true"
            : type === "Int" || type === "Double" ? Number(value)
            : type === "StringList" ? (value ? value.split(",") : [])
            : value;
    }
    return result;
}

function parsePreferences(text) {
    const value = JSON.parse(text);
    if (!value || typeof value !== "object" || Array.isArray(value))
        throw new Error("expected a settings object");
    return value;
}

function overrides(baseline, draft) {
    const result = {};
    for (const key of Object.keys(draft)) {
        const value = draft[key];
        const original = baseline[key];
        // A saved StringList is a new array after JSON reload. Compare its
        // contents so an unchanged list keeps following declarative defaults.
        const sameList = Array.isArray(value) && Array.isArray(original)
            && value.length === original.length
            && value.every((item, index) => item === original[index]);
        if (value !== original && !sameList)
            result[key] = draft[key];
    }
    return result;
}

function screens(available, monitor) {
    if (monitor === "all") return available;
    const selected = available.find(screen => screen.name === monitor) || available[0];
    return selected ? [selected] : [];
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, Number(v) || 0));
}

// Where the card sits on each screen, in screen coordinates.
function geometry(screen, config, width, height) {
    const w = Math.min(width, screen.width);
    const h = Math.min(height, screen.height);
    // Exact: where the card was dragged to, kept on the screen.
    if (config.hAnchor === "free")
        return { x: clamp(config.cardX ?? 0, 0, screen.width - w), y: clamp(config.cardY ?? 0, 0, screen.height - h), width: w, height: h };
    const margin = config.screenMargin ?? 24;
    const x = config.hAnchor === "left" ? margin
        : config.hAnchor === "center" ? (screen.width - w) / 2
        : screen.width - w - margin;
    const y = Math.max(0, Math.min(screen.height - h, screen.height * (config.verticalPosition ?? 0.08)));
    return { x: x, y: y, width: w, height: h };
}

// ── several cards ───────────────────────────────────────────────────────────
// hyprland.json holds the first card's settings as before, plus "cards": the
// other cards, each only what it changes. A card has its own look, sections,
// layout and placement; what is measured (devices, hosts, commands,
// thresholds, sensor choices) is shared, as one MonitorCore reads for all.
const PLACEMENT = ["monitor", "hAnchor", "verticalPosition", "screenMargin", "widgetWidth", "widgetHeight", "desktopLayer", "cardX", "cardY"];
const CARD_ONLY = ["layoutMode", "sectionPositions"];
// What a card shows and where: always saved for every card, so a card never
// takes the first one's sections or place just because they matched once.
const OWN = PLACEMENT.concat(CARD_ONLY, ["sections", "sectionSizes", "sectionSpans", "sectionStyles", "layoutColumns"]);

function isCardKey(key) {
    return Looks.isLookKey(key) || PLACEMENT.indexOf(key) !== -1 || CARD_ONLY.indexOf(key) !== -1;
}

function pickCard(settings) {
    const out = {};
    for (const key of Object.keys(settings || {}))
        if (isCardKey(key))
            out[key] = settings[key];
    return out;
}

// Saved file → { main: first card's overrides, cards: [other cards' changes] }.
function split(saved) {
    const main = Object.assign({}, saved);
    delete main.cards;
    const cards = Array.isArray(saved.cards) ? saved.cards.filter(c => c && typeof c === "object" && !Array.isArray(c)).map(pickCard) : [];
    return { main: main, cards: cards };
}

function join(main, cards) {
    return cards.length ? Object.assign({}, main, { cards: cards }) : main;
}

// Every card's full settings: the first card, then each other card over it.
function cards(first, others) {
    return [first].concat(others.map(c => Object.assign({}, first, pickCard(c))));
}

// What another card keeps: its own sections, layout and placement, and the
// look settings it changes from the first card (the rest follow that one).
function cardChanges(first, card) {
    const out = {};
    for (const key of Object.keys(card))
        if (isCardKey(key) && (OWN.indexOf(key) !== -1 || JSON.stringify(card[key]) !== JSON.stringify(first[key])))
            out[key] = card[key];
    return out;
}

// Shared settings follow the card edited last: copy them onto the others.
function shareFrom(source, drafts) {
    return drafts.map(d => {
        const next = Object.assign({}, d);
        for (const key of Object.keys(source))
            if (!isCardKey(key))
                next[key] = source[key];
        return next;
    });
}

// The one MonitorCore samples what any card shows.
function coreConfig(all) {
    const ids = [];
    for (const card of all)
        for (const id of Sections.parse(card.sections, card.activeSection))
            if (ids.indexOf(id) === -1)
                ids.push(id);
    return Object.assign({}, all[0], { sections: ids.join(",") });
}
