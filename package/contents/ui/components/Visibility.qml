import QtQuick
import org.kde.kirigami as Kirigami

/**
 * How far one sees, as three ranges of hills, 1, 5 and 20 km away: each fades into the haze as the
 * visibility falls short of it. Under the mouse, a bank of mist drifts across them.
 */
Item {
    id: view

    /** In metres; null when not known, which shows the hills faint. */
    required property var metres
    property bool animated: true

    /** How far each range of hills is, nearest first, in metres. */
    readonly property var ranges: [1000, 5000, 20000]
    /** Where the mist is, from 0, before the hills, to 1, past them. */
    property real mist: -1

    /** How much of a range at `distance` shows: all of it at twice the visibility, none beyond it. */
    function clearness(distance: real): real {
        if (metres === null || metres === undefined) {
            return 0.25;
        }

        return Math.max(0.08, Math.min(1, (metres - distance * 0.5) / distance));
    }

    /** A bank of mist drifts across the hills: what the instrument does under the mouse. */
    function replay(): void {
        if (animated && !drift.running) {
            drift.restart();
        }
    }

    onMetresChanged: hills.requestPaint()

    Canvas {
        id: hills

        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            const ink = Kirigami.Theme.textColor;
            const base = height * 0.95;

            context.clearRect(0, 0, width, height);

            // Farthest first, so that the nearer ranges stand in front of it.
            for (let index = view.ranges.length - 1; index >= 0; index--) {
                // The farther, the higher it rises behind the others.
                const top = height * (0.15 + (2 - index) * 0.22);
                const waves = 2 + index;
                const phase = index * 1.7;

                context.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, view.clearness(view.ranges[index]) * (0.35 + (2 - index) * 0.2));
                context.beginPath();
                context.moveTo(0, base);

                for (let step = 0; step <= 32; step++) {
                    const x = step / 32 * width;
                    const swell = (Math.sin(step / 32 * waves * Math.PI + phase) + 1) / 2;

                    context.lineTo(x, top + (1 - swell) * (base - top) * 0.45);
                }

                context.lineTo(width, base);
                context.closePath();
                context.fill();
            }

            context.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.35);
            context.lineWidth = 1.2;
            context.beginPath();
            context.moveTo(0, base + 0.5);
            context.lineTo(width, base + 0.5);
            context.stroke();
        }
    }

    // The mist, a soft band wider than the instrument, which crosses it from left to right.
    Rectangle {
        visible: view.mist >= 0
        x: -width + view.mist * (view.width + width)
        y: view.height * 0.2
        width: view.width * 0.8
        height: view.height * 0.75
        opacity: 0.55

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "transparent"
            }

            GradientStop {
                position: 0.5
                color: Qt.alpha(Kirigami.Theme.textColor, 0.5)
            }

            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    SequentialAnimation {
        id: drift

        NumberAnimation {
            target: view
            property: "mist"
            from: 0
            to: 1
            duration: 1600
            easing.type: Easing.InOutSine
        }

        PropertyAction {
            target: view
            property: "mist"
            value: -1
        }
    }
}
