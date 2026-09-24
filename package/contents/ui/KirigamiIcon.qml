import QtQuick
import org.kde.kirigami as Kirigami

// ThemeIcon's Kirigami path; loaded only where Kirigami exists.
Kirigami.Icon {
    required property Item host
    source: host.name || host.fallback
    fallback: host.fallback
}
