import QtQuick
import org.kde.kirigami as Kirigami

import "../../code/instruments.mjs" as Instruments

/** A half-round dial in the colours of its scale, with a needle that swings to the value as it appears. */
Item {
    id: dial

    /** `{ minimum, maximum, segments: [[upper bound, colour]] }`, see code/instruments.mjs. */
    required property var scale
    required property real value
    /** False draws the needle where it ends, without the swing. */
    property bool animated: true

    readonly property real target: Instruments.dialPosition(value, scale)
    /** Where the needle is, 0 at the left end of the dial and 1 at the right one. */
    property real shown: animated ? 0 : target
    readonly property real centreX: width / 2
    readonly property real centreY: height * 0.9
    readonly property real radius: Math.max(1, Math.min(width / 2, height * 0.9) - thickness / 2)
    readonly property real thickness: Math.min(width, height) * 0.13

    NumberAnimation on shown {
        running: dial.animated
        to: dial.target
        duration: 1100
        easing.type: Easing.OutBack
        easing.overshoot: 1.4
    }

    Behavior on shown {
        enabled: dial.animated

        NumberAnimation {
            duration: Kirigami.Units.longDuration
        }
    }

    onTargetChanged: shown = target

    /** The needle drops back and swings to the value again: what the dial does under the mouse. */
    function replay(): void {
        if (!again.running) {
            again.restart();
        }
    }

    SequentialAnimation {
        id: again

        NumberAnimation {
            target: dial
            property: "shown"
            to: 0
            duration: 250
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: dial
            property: "shown"
            to: dial.target
            duration: 900
            easing.type: Easing.OutBack
            easing.overshoot: 1.4
        }
    }

    Canvas {
        id: arc

        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            const span = dial.scale.maximum - dial.scale.minimum;
            const gap = 0.025;
            let from = 0;

            context.clearRect(0, 0, width, height);
            context.lineWidth = dial.thickness;
            context.lineCap = "butt";

            dial.scale.segments.forEach(([upper, colour], index) => {
                const to = (upper - dial.scale.minimum) / span;

                context.strokeStyle = colour;
                context.beginPath();
                context.arc(dial.centreX, dial.centreY, dial.radius, Math.PI + from * Math.PI + (index > 0 ? gap : 0), Math.PI + to * Math.PI);
                context.stroke();
                from = to;
            });
        }
    }

    // The needle turns about the centre of the dial: straight left at 0, straight right at 1.
    Rectangle {
        x: dial.centreX - width / 2
        y: dial.centreY - height
        width: Math.max(2, dial.thickness * 0.32)
        height: dial.radius * 0.92
        radius: width / 2
        antialiasing: true
        color: Kirigami.Theme.textColor
        transformOrigin: Item.Bottom
        rotation: -90 + dial.shown * 180
    }

    Rectangle {
        x: dial.centreX - width / 2
        y: dial.centreY - height / 2
        width: dial.thickness * 0.9
        height: width
        radius: width / 2
        color: Kirigami.Theme.textColor
    }
}
