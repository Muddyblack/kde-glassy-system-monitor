import QtQuick
import "../package/contents/ui" as Shared

// Bar module for a Quickshell bar: the panel pill for the first section.
// Give it the core from GlassyShell, or its own MonitorCore:
//     MonitorPill { monitor: core; cfg: core.cfg; onActivated: … }
Shared.CompactRepresentation {
    inPanel: true
}
