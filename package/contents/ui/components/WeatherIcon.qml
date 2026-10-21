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
    /** The white clouds of the Meteocons all but vanish on a light theme: a soft shadow sets them off there. */
    readonly property bool onLight: !themed && Kirigami.Theme.backgroundColor.hslLightness > 0.6

    implicitWidth: Kirigami.Units.iconSizes.medium
    implicitHeight: Kirigami.Units.iconSizes.medium

    Loader {
        anchors.fill: parent
        active: icon.themed

        sourceComponent: Kirigami.Icon {
            source: Wmo.iconName(icon.code, icon.isDay)
        }
    }

    /**
     * The shadow, painted once behind the icon, from its still picture: only the shadow lands on the
     * Canvas, the picture is drawn beyond its edge. A Canvas, as small as the icon, and not a shader
     * effect, which draws nothing at all where Plasma renders in software.
     */
    Loader {
        anchors.fill: parent
        active: icon.onLight

        sourceComponent: Canvas {
            id: shadow

            readonly property url picture: Qt.resolvedUrl(`../../icons/static/${icon.name}.svg`)

            onPictureChanged: loadImage(picture)
            onImageLoaded: requestPaint()
            onWidthChanged: requestPaint()
            Component.onCompleted: loadImage(picture)

            onPaint: {
                const context = getContext("2d");

                context.clearRect(0, 0, width, height);

                if (!isImageLoaded(picture)) {
                    return;
                }

                context.save();
                context.shadowColor = "rgba(30, 45, 70, 0.5)";
                context.shadowBlur = Math.max(2, width * 0.08);
                context.shadowOffsetX = width * 2;
                context.shadowOffsetY = Math.max(1, width * 0.03);
                context.drawImage(picture, -width * 2, 0, width, height);
                context.restore();
            }
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
                // Nothing moves while the widget is not on screen, nor in a tab kept out of sight; see the
                // note in TodayTab about `Window.window`. `visible` reads false while a parent is hidden.
                running: frames.loaded && frames.visible && frames.Window.window !== null && frames.Window.window.visible
                from: 0
                to: Meteocons.SHEET.frames - 1
                duration: Meteocons.SHEET.seconds * 1000
                loops: Animation.Infinite
            }

            Image {
                id: strip

                /**
                 * The side of a frame as it is decoded: as shown on the screen, in steps of 32 pixels,
                 * so that the icons of one size share the picture. At its own 128 pixels, each icon
                 * took 4.7 MB, and the tab of hours shows dozens.
                 */
                readonly property int side: Math.min(Meteocons.SHEET.frameSize, Math.max(32, Math.ceil(Math.max(frames.width, frames.height) * Screen.devicePixelRatio / 32) * 32))

                x: -(frames.current % Meteocons.SHEET.columns) * frames.width
                y: -Math.floor(frames.current / Meteocons.SHEET.columns) * frames.height
                width: Meteocons.SHEET.columns * frames.width
                height: Meteocons.SHEET.rows * frames.height
                source: `../../icons/animated/${icon.name}.png`
                sourceSize: Qt.size(Meteocons.SHEET.columns * side, Meteocons.SHEET.rows * side)
                asynchronous: true
                smooth: true
            }
        }
    }
}
