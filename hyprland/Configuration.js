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

// Where the card sits on each screen, in screen coordinates.
function geometry(screen, config, width, height) {
    const w = Math.min(width, screen.width);
    const h = Math.min(height, screen.height);
    const margin = config.screenMargin ?? 24;
    const x = config.hAnchor === "left" ? margin
        : config.hAnchor === "center" ? (screen.width - w) / 2
        : screen.width - w - margin;
    const y = Math.max(0, Math.min(screen.height - h, screen.height * (config.verticalPosition ?? 0.08)));
    return { x: x, y: y, width: w, height: h };
}
