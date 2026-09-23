import QtQuick
import "../Probes.js" as Probes

// A country's flag emoji. The colour emoji font is asked for by name:
// without it, the regional-indicator letters show as boxed letters.
Text {
    property string country: ""
    text: Probes.flag(country)
    visible: text !== ""
    font.family: "Noto Color Emoji"
    font.pixelSize: 12
}
