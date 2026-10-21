import QtQuick

import "../../code/scene.mjs" as Scene

/** Heat haze: a warm glow over the horizon and air that rises and shimmers in it. */
Item {
    id: haze

    property bool running: false

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.45

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#00ffb347"
            }

            GradientStop {
                position: 1
                color: "#5cffb347"
            }
        }
    }

    Repeater {
        model: 5

        delegate: Rectangle {
            id: wave

            required property int index

            property real rise: Scene.noise(index, 91)

            width: haze.width * (0.5 + Scene.noise(index, 92) * 0.4)
            height: Math.max(3, haze.height * 0.035)
            radius: height / 2
            x: haze.width * Scene.noise(index, 93) * 0.5 + Math.sin((rise * 3 + index) * Math.PI) * haze.width * 0.03
            y: haze.height * (0.95 - rise * 0.4)
            opacity: 0.1 + Math.sin(Math.PI * rise) * 0.45

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "#00fff4e0"
                }

                GradientStop {
                    position: 0.5
                    color: "#88fff4e0"
                }

                GradientStop {
                    position: 1
                    color: "#00fff4e0"
                }
            }

            NumberAnimation on rise {
                running: haze.running
                from: 0
                to: 1
                duration: 3800 + Scene.noise(wave.index, 94) * 2400
                loops: Animation.Infinite
            }
        }
    }
}
