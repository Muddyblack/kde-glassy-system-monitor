.pragma library
.import "../studio/Theme.js" as Theme

// The studio's palette (dark) and a light twin for the network window.
var dark = {
    dark: true,
    bg: Theme.bg,
    panel: Theme.panel,
    panelTop: Theme.panelTop,
    panelBottom: Theme.panelBottom,
    sunk: Theme.sunk,
    line: Theme.line,
    line2: Theme.line2,
    text: Theme.text,
    muted: Theme.muted,
    dim: Theme.dim,
    brand: Theme.brand,
    brandInk: Theme.brandInk,
    card: Theme.card,
    hover: Theme.hover,
    selected: "#1455ffcc",
    selectedBorder: Theme.tileSelectedBorder,
    segPressed: Theme.segPressed,
    segPressedText: Theme.segPressedText,
    popup: "#1a1c1e",
    ok: Theme.ok,
    warn: Theme.warn,
    danger: "#ff7b72",
    rx: "#22aaff",
    tx: "#ff9933",
    grid: "#14ffffff",
    // Theme icons through image://icon (Plasma and Quickshell provide it).
    icons: true,
    fontFamily: Theme.fontFamily
};

var light = {
    dark: false,
    bg: "#eef1f2",
    panel: "#ffffff",
    panelTop: "#ffffff",
    panelBottom: "#f6f8f8",
    sunk: "#e6eaeb",
    line: "#14000000",
    line2: "#22000000",
    text: "#15191b",
    muted: "#4f5a5e",
    dim: "#6f7a7e",
    brand: "#0a9e7c",
    brandInk: "#ffffff",
    card: "#05000000",
    hover: "#0c000000",
    selected: "#1a0a9e7c",
    selectedBorder: "#990a9e7c",
    segPressed: "#cde9f7",
    segPressedText: "#0b3a55",
    popup: "#ffffff",
    ok: "#0a8f5a",
    warn: "#a86b00",
    danger: "#c62f28",
    rx: "#0a7fd0",
    tx: "#d86a00",
    grid: "#12000000",
    // Theme icons through image://icon (Plasma and Quickshell provide it).
    icons: true,
    fontFamily: Theme.fontFamily
};
