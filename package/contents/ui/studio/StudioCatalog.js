// Tabs, preview wallpapers and the studio palette, shared by both hosts.
var StudioCatalog = {
    "wallpapers": [
        {
            "id": "dusk",
            "label": "Pine lake",
            "file": "pine-lake.png",
            "color": "#15233d"
        },
        {
            "id": "neon",
            "label": "Afterglow",
            "file": "afterglow.png",
            "color": "#142c49"
        },
        {
            "id": "sea",
            "label": "Midnight marina",
            "file": "midnight-marina.svg",
            "color": "#071b28"
        },
        {
            "id": "breeze",
            "label": "Aurora sound",
            "file": "aurora-sound.svg",
            "color": "#0a2035"
        },
        {
            "id": "olive",
            "label": "Moss & mist",
            "file": "moss-mist.svg",
            "color": "#152e2d"
        },
        {
            "id": "day",
            "label": "Silver tide",
            "file": "silver-tide.svg",
            "color": "#c2d4db"
        }
    ],
    "tabs": [
        {"id": "presets", "label": "Presets", "icon": "M3 5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM13 5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2zM3 15a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM17 13v8M13 17h8"},
        {"id": "layout", "label": "Layout", "icon": "M4 4h7v7H4zM13 4h7v4h-7zM13 10h7v10h-7zM4 13h7v7H4z"},
        {"id": "charts", "label": "Charts", "icon": "M3 12h2l2-6 3 12 3-9 2 5 2-2h4"},
        {"id": "card", "label": "Card", "icon": "M7 6h10a4 4 0 0 1 4 4v4a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4v-4a4 4 0 0 1 4-4zM7 10h6"},
        {"id": "colors", "label": "Colours", "icon": "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0zM12 3a9 9 0 0 0 0 18z"},
        {"id": "cpu", "label": "CPU", "icon": "M9 4v2M15 4v2M9 18v2M15 18v2M4 9h2M4 15h2M18 9h2M18 15h2M7 6h10a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1zM10 10h4v4h-4z"},
        {"id": "memory", "label": "Memory", "icon": "M4 7h16v10H4zM8 7v10M12 7v10M16 7v10M6 17v3M18 17v3"},
        {"id": "network", "label": "Network", "icon": "M7 4v16M4 17l3 3 3-3M17 20V4M14 7l3-3 3 3"},
        {"id": "ping", "label": "Ping", "icon": "M3 12h4l3-7 4 14 3-7h4"},
        {"id": "disk", "label": "Disk", "icon": "M4 6c0-1.7 3.6-3 8-3s8 1.3 8 3-3.6 3-8 3-8-1.3-8-3zM4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"},
        {"id": "gpu", "label": "GPU", "icon": "M3 7h18v10H3zM7 17v3M17 17v3M8 12a2 2 0 1 0 4 0 2 2 0 1 0-4 0M15 10h2M15 14h2"},
        {"id": "sensors", "label": "Sensors", "icon": "M10 14.8V5a2 2 0 1 1 4 0v9.8a4 4 0 1 1-4 0zM12 9v7"},
        {"id": "power", "label": "Power", "icon": "M5 7h13a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1zM19 10h2v4h-2M12 9l-2 3h4l-2 3"},
        {"id": "system", "label": "System", "icon": "M4 5h16v11H4zM8 20h8M12 16v4"},
        {"id": "storage", "label": "Storage", "icon": "M4 14h16v5H4zM4 14l2.5-8h11l2.5 8M7 16.5h3"},
        {"id": "processes", "label": "Processes", "icon": "M4 6h9M4 12h13M4 18h6M17 5v3M20 9v11M14 15v5"},
        {"id": "load", "label": "Load", "icon": "M4 19h16M6 16l4-5 3 3 5-7M4 5v14"},
        {"id": "fans", "label": "Fans", "icon": "M12 12m-2 0a2 2 0 1 0 4 0 2 2 0 1 0-4 0M12 10c0-4 1-7 4-7 2 0 2 3 0 5l-2 2M14 12c4 0 7 1 7 4 0 2-3 2-5 0l-2-2M12 14c0 4-1 7-4 7-2 0-2-3 0-5l2-2M10 12c-4 0-7-1-7-4 0-2 3-2 5 0l2 2"},
        {"id": "services", "label": "Services", "icon": "M12 3l8 4.5v9L12 21l-8-4.5v-9zM12 12l8-4.5M12 12v9M12 12L4 7.5"},
        {"id": "containers", "label": "Containers", "icon": "M3 9h18v10H3zM3 9l2-4h14l2 4M8 9v10M13 9v10M18 9v10"},
        {"id": "custom", "label": "Custom", "icon": "M5 8l4 4-4 4M11 16h8"},
        {"id": "performance", "label": "Performance", "icon": "M12 13l4-4M4 17a8 8 0 1 1 16 0M12 13a1 1 0 1 0 0 .1"},
        {"id": "about", "label": "Info", "icon": "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0zM12 11v6M12 7.5v.5"}
    ],
    "theme": {
        "bg": "#0e0f10",
        "panel": "#151718",
        "panelTop": "#17191a",
        "panelBottom": "#131516",
        "sunk": "#0f1112",
        "line": "#10ffffff",
        "line2": "#1cffffff",
        "text": "#eeefeb",
        "muted": "#9da3a5",
        "dim": "#787f82",
        "brand": "#55ffcc",
        "brandInk": "#01121f",
        "sectionTitle": "#b1b7b9",
        "card": "#04ffffff",
        "hover": "#08ffffff",
        "segPressed": "#074f81",
        "segPressedText": "#eeefeb",
        "chipPressed": "#032b40",
        "chipPressedBorder": "#8855ffcc",
        "tileSelectedBorder": "#9955ffcc",
        "tileSelectedRing": "#1455ffcc",
        "tileHoverBorder": "#33ffffff",
        "tilePreview": "#0a0b0c",
        "switchOff": "#3a3e40",
        "switchOnTop": "#55ffcc",
        "switchOnBottom": "#0eadcf",
        "knob": "#f3f5f5",
        "rangeTrack": "#1affffff",
        "rangeThumb": "#f4f6f6",
        "rangeRing": "#1f55ffcc",
        "outputText": "#d0d6d8",
        "noteBg": "#0d22d4ff",
        "noteBorder": "#2622d4ff",
        "noteText": "#c2d9df",
        "ok": "#44ffb1",
        "warn": "#ffe073",
        "fontFamily": "Inter"
    }
};
