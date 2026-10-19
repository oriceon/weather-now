pragma Singleton

import QtQuick

QtObject {
    property bool dark: true

    readonly property color textColor: dark ? "#fcfcfc" : "#232629"
    readonly property color disabledTextColor: dark ? "#a1a9b1" : "#707d8a"
    readonly property color backgroundColor: dark ? "#2a2738" : "#eff0f1"
    readonly property color alternateBackgroundColor: dark ? "#322f43" : "#e3e5e7"
    readonly property color highlightColor: dark ? "#c217c9" : "#3daee9"
    readonly property color highlightedTextColor: "#ffffff"
    readonly property color linkColor: dark ? "#5cb7f0" : "#2980b9"
    readonly property color positiveTextColor: "#27ae60"
    readonly property color neutralTextColor: "#f67400"
    readonly property color negativeTextColor: "#da4453"
    readonly property font defaultFont: Qt.font({ pointSize: 10 })
    readonly property font smallFont: Qt.font({ pointSize: 8 })
}
