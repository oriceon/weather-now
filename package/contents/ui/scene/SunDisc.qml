import QtQuick

/** The sun: a disc, a halo that breathes and rays that turn slowly. */
Item {
    id: sun

    property bool running: false

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

    Canvas {
        id: halo

        anchors.centerIn: parent
        width: sun.width * 2.4
        height: width

        onPaint: sun.radial(getContext("2d"), width, [[0, "rgba(255, 244, 196, 0.6)"], [0.35, "rgba(255, 226, 140, 0.28)"], [1, "rgba(255, 226, 140, 0)"]])
        onWidthChanged: requestPaint()

        SequentialAnimation on scale {
            running: sun.running
            loops: Animation.Infinite

            NumberAnimation {
                to: 1.1
                duration: 2600
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 2600
                easing.type: Easing.InOutSine
            }
        }
    }

    Canvas {
        id: rays

        readonly property int count: 12

        anchors.centerIn: parent
        width: sun.width * 1.7
        height: width

        onPaint: {
            const context = getContext("2d");
            const centre = width / 2;
            const inner = sun.width * 0.36;

            context.clearRect(0, 0, width, height);
            context.fillStyle = "rgba(255, 236, 160, 0.5)";

            for (let ray = 0; ray < count; ray++) {
                const angle = ray * 2 * Math.PI / count;
                const spread = Math.PI / count * 0.42;
                // Every other ray is shorter.
                const outer = centre * (ray % 2 === 0 ? 1 : 0.8);

                context.beginPath();
                context.moveTo(centre + Math.cos(angle - spread) * inner, centre + Math.sin(angle - spread) * inner);
                context.lineTo(centre + Math.cos(angle) * outer, centre + Math.sin(angle) * outer);
                context.lineTo(centre + Math.cos(angle + spread) * inner, centre + Math.sin(angle + spread) * inner);
                context.closePath();
                context.fill();
            }
        }
        onWidthChanged: requestPaint()

        RotationAnimation on rotation {
            running: sun.running
            from: 0
            to: 360
            duration: 90000
            loops: Animation.Infinite
        }
    }

    Canvas {
        anchors.centerIn: parent
        width: sun.width * 0.62
        height: width

        onPaint: sun.radial(getContext("2d"), width, [[0, "rgba(255, 253, 235, 1)"], [0.7, "rgba(255, 224, 120, 1)"], [0.92, "rgba(255, 205, 80, 0.95)"], [1, "rgba(255, 205, 80, 0)"]])
        onWidthChanged: requestPaint()
    }
}
