import QtQuick
import org.kde.kirigami as Kirigami

// ThemeIcon's Kirigami path; loaded only where Kirigami exists.
Kirigami.Icon {
    required property Item host
    readonly property string wanted: host.name || host.fallback
    source: wanted.charAt(0) === "/" ? "file://" + wanted : wanted
    fallback: host.fallback
}
