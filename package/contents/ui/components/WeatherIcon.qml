import QtQuick
import org.kde.kirigami as Kirigami

import "../../code/meteocons.mjs" as Meteocons
import "../../code/wmo.mjs" as Wmo

/** The icon of a weather condition: a Meteocons icon, animated on request, or the icon of the Plasma theme. */
Item {
    id: icon

    /** A condition code of the parsed forecast; anything else shows the "not available" icon of the theme. */
    required property var code
    property bool isDay: true
    /** `{ set, animated }`, see `iconStyle` in FullRepresentation. */
    required property var iconStyle
    property bool animated: iconStyle.animated

    readonly property string name: Wmo.meteocon(code, isDay)
    /** The Meteocons have no icon that suits an unknown code on a dark theme. */
    readonly property bool themed: iconStyle.set === "breeze" || name === ""

    implicitWidth: Kirigami.Units.iconSizes.medium
    implicitHeight: Kirigami.Units.iconSizes.medium

    Loader {
        anchors.fill: parent
        active: icon.themed

        sourceComponent: Kirigami.Icon {
            source: Wmo.iconName(icon.code, icon.isDay)
        }
    }

    // The still picture; it also stands in until the animation is loaded.
    Image {
        anchors.fill: parent
        visible: !icon.themed && !film.playing
        source: icon.themed ? "" : `../../icons/static/${icon.name}.svg`
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectFit
    }

    /**
     * The animation is a film strip, see SHEET in code/meteocons.mjs: the whole strip is
     * scaled so that one frame fills the icon, and moved so that the current frame shows.
     */
    Loader {
        id: film

        readonly property bool playing: status === Loader.Ready && item.loaded

        anchors.fill: parent
        active: !icon.themed && icon.animated

        sourceComponent: Item {
            id: frames

            property int current: 0
            readonly property bool loaded: strip.status === Image.Ready

            clip: true
            visible: loaded

            NumberAnimation on current {
                // Nothing moves while the widget is not on screen; see the note in TodayTab about `Window.window`.
                running: frames.loaded && frames.Window.window !== null && frames.Window.window.visible
                from: 0
                to: Meteocons.SHEET.frames - 1
                duration: Meteocons.SHEET.seconds * 1000
                loops: Animation.Infinite
            }

            Image {
                id: strip

                x: -(frames.current % Meteocons.SHEET.columns) * frames.width
                y: -Math.floor(frames.current / Meteocons.SHEET.columns) * frames.height
                width: Meteocons.SHEET.columns * frames.width
                height: Meteocons.SHEET.rows * frames.height
                source: `../../icons/animated/${icon.name}.png`
                asynchronous: true
                mipmap: true
            }
        }
    }
}
