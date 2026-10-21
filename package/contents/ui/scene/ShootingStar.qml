import QtQuick

import "../../code/scene.mjs" as Scene

/** Now and then, a shooting star across the upper sky. */
Item {
    id: shootingStar

    property bool running: false
    /** Counts the stars; each one starts somewhere else. */
    property int count: 0

    Rectangle {
        id: streak

        property real progress: 0

        readonly property real startX: shootingStar.width * (0.15 + Scene.noise(shootingStar.count, 71) * 0.6)
        readonly property real startY: shootingStar.height * (0.05 + Scene.noise(shootingStar.count, 72) * 0.25)

        width: shootingStar.width * 0.16
        height: 1.6
        radius: 1
        rotation: 24
        transformOrigin: Item.Right
        x: startX + progress * shootingStar.width * 0.28 - width
        y: startY + progress * shootingStar.width * 0.28 * Math.tan(rotation * Math.PI / 180)
        opacity: 0

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "#00ffffff"
            }

            GradientStop {
                position: 1
                color: "#ffffffff"
            }
        }
    }

    Timer {
        running: shootingStar.running
        interval: 5000 + Scene.noise(shootingStar.count, 73) * 9000
        repeat: true

        onTriggered: {
            shootingStar.count++;
            flight.restart();
        }
    }

    SequentialAnimation {
        id: flight

        PropertyAction {
            target: streak
            property: "progress"
            value: 0
        }

        ParallelAnimation {
            NumberAnimation {
                target: streak
                property: "progress"
                to: 1
                duration: 700
                easing.type: Easing.InQuad
            }

            SequentialAnimation {
                NumberAnimation {
                    target: streak
                    property: "opacity"
                    to: 0.9
                    duration: 150
                }

                NumberAnimation {
                    target: streak
                    property: "opacity"
                    to: 0
                    duration: 550
                }
            }
        }
    }
}
