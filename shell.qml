// Keep the config root here so Quickshell can import the shared Plasma files.
import "hyprland"

GlassyShell {
    // Defaults, below anything saved from the settings window (right-click the
    // widget, or `make settings-hyprland`). Any Plasma setting name works here.
    settings: ({
            sections: "cpu,memory,network",
            hAnchor: "right" // left, center or right
            ,
            verticalPosition: 0.08 // fraction of the screen height from the top
        })
}
