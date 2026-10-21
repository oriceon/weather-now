pragma ComponentBehavior: Bound

import QtQuick

import "../../code/land.mjs" as Land
import "../../code/scene.mjs" as Scene
import "../../code/sky.mjs" as Sky

/**
 * The land under the sky, as chosen in the settings: hills under far mountains, a city, the sea, a
 * plain of poppies, a mountain lake or a village. It is drawn in three layers, which the mouse moves
 * each by its depth; see code/land.mjs. It takes the light of the hour, the haze of distance, the
 * colours of the season and the snow that has settled. By night the city lights its windows and the
 * red lights of its towers; the sun, or the moon, draws a path on the water, while the last wave comes
 * and goes on the sand; the poppies sway in the wind, and in the cold the chimneys of the village smoke.
 */
Item {
    id: land

    /** One of KINDS in code/land.mjs, but "none". */
    property string kind: "hills"
    property bool isDay: true
    /** The colours of the sky near the horizon, which the far land fades into. */
    property string horizon: "#a9d4ff"
    /** The warm light of sunrise and sunset, 0 to 1. */
    property real warmth: 0
    /** The snow on the ground, 0 to 1. */
    property real snow: 0
    /** Where the sun or the moon is across the scene, 0 to 1. */
    property real lightAt: 0.5
    /** spring | summer | autumn | winter: the colours of the leaves. */
    property string season: "summer"
    /** The wind in km/h: it raises the swell and breaks it into whitecaps. */
    property real wind: 0
    /** How far the mouse leans the scene, from -1 to 1. */
    property real tilt: 0
    property bool running: false
    /** From 0 to 1, over and over: the glitter on the water, and the red lights of the towers. */
    property real shimmer: 0.4
    /** From 0 to 1 and back: the last wave on the sand. */
    property real swash: 0.5
    /** From 0 to 1 and back: the poppies in the wind. */
    property real sway: 0.5
    /** From 0 to 1, over and over: the smoke rising from the chimneys. */
    property real smoke: 0

    /** `[top, bottom]` of the water, for its glitter, and the layer the water is drawn in. */
    readonly property var water: Land.waterBand(kind)
    readonly property string waterLayer: ({ sea: "back", lake: "front" })[kind] || ""
    /** In the cold months, and under snow, the chimneys smoke. */
    readonly property bool smoky: kind === "village" && (season === "winter" || season === "autumn" || snow > 0)

    /** How much wider than the land each layer is on either side, so that leaning shows no edge. */
    readonly property real margin: 24
    /**
     * How much taller than the land each layer is, below it, where the scene cuts it off: a canvas
     * of a height in fractions of a pixel left its last row empty, a line of sky under the land.
     */
    readonly property real bleed: 3
    /**
     * The size the land was last drawn at. While the widget is being resized, as on entering the
     * edit mode of the desktop, the layers keep it and are only stretched to fit; they are drawn
     * again once the size has settled. Drawn again at every step, thousands of trees froze Plasma.
     */
    property real settledWidth: 0
    property real settledHeight: 0
    /**
     * What the land is drawn with, rounded so that it is drawn again when it would look otherwise,
     * not as often as the light changes: the horizon in steps of colour, the warmth in twentieths,
     * the snow in tenths, the sun in fiftieths of the way across, the wind by 5 km/h. The light of
     * the sky changes every minute, and so the hills of a wallpaper, drawn again with it, held up
     * the desktop for most of a second every minute.
     */
    readonly property string lookKey: [settledWidth, Math.ceil(settledHeight), isDay, Sky.roundedHex(horizon, 8), Math.round(warmth * 20), Math.round(snow * 10), Math.round(lightAt * 50), season, Math.round(wind / 5)].join("|")
    // Set, not bound: a binding would follow every property lookNow() reads, rounded or not.
    property var look: ({ width: 0, height: 0, lightX: 0 })

    function lookNow(): var {
        return {
            width: settledWidth + 2 * margin,
            height: Math.ceil(settledHeight) + bleed,
            isDay: isDay,
            horizon: Sky.roundedHex(horizon, 8),
            warmth: Math.round(warmth * 20) / 20,
            snow: Math.round(snow * 10) / 10,
            lightX: margin + Math.round(lightAt * 50) / 50 * settledWidth,
            season: season,
            wind: Math.round(wind / 5) * 5,
        };
    }

    function settle(): void {
        settledWidth = width;
        settledHeight = height;
    }

    onLookKeyChanged: look = lookNow()
    Component.onCompleted: look = lookNow()

    // The first size is taken at once; the others once they stop changing.
    onWidthChanged: settledWidth > 0 ? settling.restart() : settle()
    onHeightChanged: settledHeight > 0 ? settling.restart() : settle()

    Timer {
        id: settling

        interval: 250

        onTriggered: land.settle()
    }

    NumberAnimation on shimmer {
        running: land.running && (land.water !== null || land.kind === "city")
        from: 0
        to: 1
        duration: 4000
        loops: Animation.Infinite
    }

    SequentialAnimation on swash {
        running: land.running && land.kind === "sea"
        loops: Animation.Infinite

        NumberAnimation {
            from: 0
            to: 1
            duration: 3200
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            from: 1
            to: 0
            duration: 3800
            easing.type: Easing.InOutSine
        }
    }

    SequentialAnimation on sway {
        running: land.running && land.kind === "poppies"
        loops: Animation.Infinite

        NumberAnimation {
            from: 0
            to: 1
            duration: 2600
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            from: 1
            to: 0
            duration: 2900
            easing.type: Easing.InOutSine
        }
    }

    NumberAnimation on smoke {
        running: land.running && land.smoky
        from: 0
        to: 1
        duration: 7000
        loops: Animation.Infinite
    }

    /** One layer of the land, `depth` the pixels it moves when the mouse leans the scene all the way. */
    component Layer: Item {
        id: stratum

        required property string part
        required property real depth

        x: -land.margin + land.tilt * depth
        width: land.look.width
        height: land.look.height
        transform: [
            // Stretched to the land while its size has not settled, see settledWidth.
            Scale {
                origin.x: land.margin
                xScale: land.width / Math.max(1, land.settledWidth)
                yScale: land.height / Math.max(1, land.settledHeight)
            },
            // The poppies in front lean with the wind and back, their feet still.
            Matrix4x4 {
                readonly property real lean: stratum.part === "front" && land.kind === "poppies" ? (land.sway - 0.5) * (1 + Math.min(1, land.wind / 30) * 4) / Math.max(1, stratum.height) : 0

                matrix: Qt.matrix4x4(1, -lean, 0, lean * stratum.height, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        ]

        Canvas {
            id: ground

            anchors.fill: parent

            onPaint: Land.paintLand(getContext("2d"), land.kind, land.look, stratum.part)

            // Its size, its light and its kind come one after another: drawn once they have all come,
            // not once for each, as thousands of trees take a while.
            Timer {
                id: repaint

                interval: 80

                onTriggered: ground.requestPaint()
            }

            Connections {
                target: land

                function onLookChanged(): void {
                    repaint.restart();
                }

                function onKindChanged(): void {
                    repaint.restart();
                }
            }
        }

        // The path of the sun, or of the moon, on the water: short strokes of light that come and go,
        // wider and longer nearer the eye; over the water, in the layer that has it.
        Repeater {
            model: land.water !== null && land.waterLayer === stratum.part ? 34 : 0

            delegate: Rectangle {
                id: glint

                required property int index

                readonly property real near: Math.pow(Scene.noise(index, 71), 0.8)

                x: land.look.lightX + (Scene.noise(index, 72) - 0.5) * land.settledWidth * (0.03 + near * 0.14) - width / 2
                y: land.look.height * (land.water[0] + 0.01 + Math.pow(near, 1.6) * (land.water[1] - land.water[0] - 0.04))
                width: 3 + near * 16
                height: 1 + near
                radius: 1
                color: land.isDay ? Sky.mixHex("#fff6d8", "#ffb36b", land.warmth) : "#dfe6ff"
                opacity: (0.25 + 0.6 * (0.5 + 0.5 * Math.sin((land.shimmer + Scene.noise(glint.index, 73)) * 2 * Math.PI))) * (1 - near * 0.35)
            }
        }

        // The smoke of the chimneys: puffs that rise, grow, drift with the wind and fade.
        Repeater {
            model: land.smoky && stratum.part === "middle" ? Land.chimneys(stratum.width / Math.max(1, land.look.height)) : []

            delegate: Item {
                id: chimney

                required property var modelData
                required property int index

                x: chimney.modelData.x * stratum.width
                y: chimney.modelData.y * land.look.height

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        id: puff

                        required property int index

                        readonly property real age: (land.smoke + puff.index / 3 + Scene.noise(chimney.index, 75)) % 1
                        readonly property real size: chimney.modelData.size * land.look.height * (0.12 + age * 0.45)

                        x: age * (4 + Math.min(1, land.wind / 30) * 22) - size / 2
                        y: -age * chimney.modelData.size * land.look.height * 1.4 - size / 2
                        width: size
                        height: size
                        radius: size / 2
                        color: land.isDay ? "#e6e8ec" : "#5a6274"
                        opacity: (1 - age) * (land.running ? 0.32 : 0.18)
                    }
                }
            }
        }

        // The red lights on the towers, blinking.
        Repeater {
            model: land.kind === "city" ? Land.beacons().filter(beacon => beacon.part === stratum.part) : []

            delegate: Rectangle {
                id: beacon

                required property var modelData
                required property int index

                x: modelData.x * stratum.width - width / 2
                y: modelData.y * land.look.height - height
                width: 2.5
                height: 2.5
                radius: 1.25
                color: "#ff3b30"
                opacity: (land.shimmer * 2 + beacon.index * 0.37) % 1 < 0.5 ? (land.isDay ? 0.6 : 1) : 0.15
            }
        }
    }

    Layer {
        part: "back"
        depth: 4
    }

    Layer {
        part: "middle"
        depth: 10
    }

    Layer {
        part: "front"
        depth: 18

        Canvas {
            id: surf

            width: parent.width
            height: parent.height
            visible: land.kind === "sea"
            y: (land.swash - 0.5) * 5
            opacity: 0.55 + 0.45 * land.swash

            onPaint: Land.paintSurf(getContext("2d"), land.look)

            Timer {
                id: surfRepaint

                interval: 80

                onTriggered: surf.requestPaint()
            }

            Connections {
                target: land

                function onLookChanged(): void {
                    surfRepaint.restart();
                }
            }
        }
    }
}
