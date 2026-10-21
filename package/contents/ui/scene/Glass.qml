pragma ComponentBehavior: Bound

import QtQuick

import "../../code/scene.mjs" as Scene

/**
 * Rain on the glass in front of the scene: drops that cling, then run down with a trail behind them,
 * and splashes along the bottom edge. Each drop comes back somewhere else once it has run off.
 */
Item {
    id: glass

    /** How many drops there are on the glass at a time. */
    property int drops: 0
    property bool running: false
    /** From 0 to 1, over and over; see fallClock in WeatherScene. */
    property real clock: 0.3

    NumberAnimation on clock {
        running: glass.running && glass.drops > 0
        from: 0
        to: 1
        duration: 14000
        loops: Animation.Infinite
    }

    Repeater {
        model: glass.drops

        delegate: Item {
            id: drop

            required property int index

            /** Each drop runs down `laps` times a round, starting at a moment of its own. */
            readonly property int laps: 1 + Math.floor(Scene.noise(index, 101) * 3)
            readonly property real round: glass.clock * laps + Scene.noise(index, 102)
            readonly property int pass: Math.floor(round)
            readonly property real run: round - pass
            /** It clings for the first part of its run, then gathers speed. */
            readonly property real fall: run < 0.35 ? 0 : Math.pow((run - 0.35) / 0.65, 1.8)
            readonly property real size: 3 + Scene.noise(index * 7 + pass, 103) * 4

            x: Scene.noise(index * 13 + pass, 104) * glass.width
            y: glass.height * (Scene.noise(index * 17 + pass, 105) * 0.5 + fall)
            width: size
            height: size * 1.25
            opacity: run < 0.06 ? run / 0.06 : 1

            // The trail it leaves as it runs, thinning towards the top.
            Rectangle {
                anchors.bottom: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(1, drop.size * 0.35)
                height: Math.min(drop.y, glass.height * 0.25 * drop.fall)
                radius: width / 2

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#00ffffff"
                    }

                    GradientStop {
                        position: 1
                        color: "#40ffffff"
                    }
                }
            }

            // The drop: a lens, darker at its rim, with a glint of light on top.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#26ffffff"
                border.width: 1
                border.color: "#40102030"
            }

            Rectangle {
                x: parent.width * 0.25
                y: parent.height * 0.18
                width: parent.width * 0.3
                height: width
                radius: width / 2
                color: "#b0ffffff"
            }
        }
    }

    // Splashes along the bottom edge: small rings that open and fade.
    Repeater {
        model: Math.round(glass.drops * 0.6)

        delegate: Rectangle {
            id: splash

            required property int index

            readonly property real round: glass.clock * (6 + index % 4) + Scene.noise(index, 111)
            readonly property real burst: round - Math.floor(round)

            x: Scene.noise(index * 19 + Math.floor(round), 112) * glass.width - width / 2
            y: glass.height - 3 - height / 2
            width: 4 + burst * 14
            height: width * 0.35
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: "#ffffff"
            opacity: (1 - burst) * 0.5
        }
    }
}
