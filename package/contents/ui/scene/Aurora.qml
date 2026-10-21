pragma ComponentBehavior: Bound

import QtQuick

import "../../code/scene.mjs" as Scene

/**
 * The aurora: a curtain of green light hanging in the sky, violet at its top and brightest along
 * its lower edge, which sways slowly while its rays flicker. Seen from afar, it is a lower, fainter
 * curtain over a glow on the horizon.
 */
Item {
    id: aurora

    /** overhead | horizon */
    property string sight: "overhead"
    property bool running: false
    /** From 0 to 1, over and over: the sway of the curtain and the flicker of its rays. */
    property real phase: 0.3

    readonly property bool overhead: sight === "overhead"
    /** Where the curtain hangs, and how long its rays are. */
    readonly property real curtainTop: height * (overhead ? 0.04 : 0.3)
    readonly property real curtainSpan: height * (overhead ? 0.5 : 0.24)
    readonly property int rays: 48

    NumberAnimation on phase {
        running: aurora.running
        from: 0
        to: 1
        duration: 30000
        loops: Animation.Infinite
    }

    // Seen from afar, the light of the curtain over the horizon.
    Rectangle {
        visible: !aurora.overhead
        y: aurora.curtainTop + aurora.curtainSpan * 0.3
        width: parent.width
        height: aurora.curtainSpan

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#003dffa0"
            }

            GradientStop {
                position: 0.7
                color: "#333dffa0"
            }

            GradientStop {
                position: 1
                color: "#003dffa0"
            }
        }
    }

    Repeater {
        model: aurora.rays

        delegate: Rectangle {
            id: ray

            required property int index

            readonly property real along: (index + 0.5) / aurora.rays
            /** The fold of the curtain where this ray hangs, between -0.75 and 0.75. */
            readonly property real fold: Math.sin((along * 2.2 + aurora.phase * 2) * 2 * Math.PI) * 0.5
                + Math.sin((along * 5.3 - aurora.phase * 3) * 2 * Math.PI) * 0.25

            /** The lower edge of the curtain, which folds; the rays rise from it, each as tall as it happens to be. */
            readonly property real edge: aurora.curtainTop + aurora.curtainSpan * (0.78 + 0.22 * fold)

            x: along * aurora.width - width / 2
            y: edge - height
            // Wider than the gap between two rays: they overlap into a soft sheet.
            width: aurora.width / aurora.rays * 2.2
            height: aurora.curtainSpan * (0.45 + 0.55 * Scene.noise(index, 71))
            opacity: (aurora.overhead ? 0.3 : 0.18) + 0.3 * (0.5 + 0.5 * Math.sin((aurora.phase * 7 + Scene.noise(index, 72)) * 2 * Math.PI))

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#00b46cff"
                }

                GradientStop {
                    position: 0.35
                    color: "#55b46cff"
                }

                GradientStop {
                    position: 0.75
                    color: "#bb3dffa0"
                }

                GradientStop {
                    position: 0.94
                    color: "#ee8dffc8"
                }

                GradientStop {
                    position: 1
                    color: "#003dffa0"
                }
            }
        }
    }
}
