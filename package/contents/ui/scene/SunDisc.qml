import QtQuick

/**
 * The sun: a bright disc in a soft corona, inside a wide bloom of light that breathes. A cloud in
 * front of it, `cover`, dims the bloom more than the disc, as a thin cloud does.
 */
Item {
    id: sun

    property bool running: false
    /** How much a cloud hides it, 0 to 1. */
    property real cover: 0

    function radial(context, size, stops): void {
        const centre = size / 2;
        const gradient = context.createRadialGradient(centre, centre, 0, centre, centre, centre);

        for (const [position, colour] of stops) {
            gradient.addColorStop(position, colour);
        }

        context.clearRect(0, 0, size, size);
        context.fillStyle = gradient;
        context.fillRect(0, 0, size, size);
    }

    // The bloom: the light of the sun spread over the sky around it.
    Canvas {
        anchors.centerIn: parent
        width: sun.width * 3.4
        height: width
        opacity: 1 - 0.8 * sun.cover

        onPaint: sun.radial(getContext("2d"), width, [[0, "rgba(255, 248, 220, 0.55)"], [0.12, "rgba(255, 240, 200, 0.38)"], [0.35, "rgba(255, 228, 170, 0.14)"], [1, "rgba(255, 228, 170, 0)"]])
        onWidthChanged: requestPaint()

        SequentialAnimation on scale {
            running: sun.running
            loops: Animation.Infinite

            NumberAnimation {
                to: 1.06
                duration: 3400
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 3400
                easing.type: Easing.InOutSine
            }
        }
    }

    // The corona, close around the disc.
    Canvas {
        anchors.centerIn: parent
        width: sun.width * 1.15
        height: width
        opacity: 1 - 0.6 * sun.cover

        onPaint: sun.radial(getContext("2d"), width, [[0, "rgba(255, 252, 235, 0.9)"], [0.42, "rgba(255, 246, 210, 0.55)"], [1, "rgba(255, 236, 180, 0)"]])
        onWidthChanged: requestPaint()
    }

    Canvas {
        anchors.centerIn: parent
        width: sun.width * 0.5
        height: width
        opacity: 1 - 0.35 * sun.cover

        onPaint: sun.radial(getContext("2d"), width, [[0, "rgba(255, 255, 250, 1)"], [0.75, "rgba(255, 250, 225, 1)"], [0.9, "rgba(255, 238, 180, 0.9)"], [1, "rgba(255, 230, 160, 0)"]])
        onWidthChanged: requestPaint()
    }
}
