import QtQuick
import org.kde.kirigami as Kirigami

import "../scene" as Scenery

/**
 * The way of the moon across the sky, from its rising to its setting, with the moon, lit as its
 * phase says, where it is now. While it is down, it waits at the horizon, faint.
 */
Item {
    id: moonArc

    /** Position in the lunar cycle, see moonPhase() in code/moon.mjs. */
    required property real phase
    /** `{ up, progress }`, see moonWay() in code/moon.mjs. */
    required property var way
    /** False puts the moon where it is, without it climbing there. */
    property bool animated: true

    readonly property real target: way.up ? way.progress : 0
    property real shown: animated ? 0 : target
    readonly property real margin: Math.max(4, height * 0.16)
    readonly property real horizon: height - margin * 0.5
    readonly property real discSize: Math.max(14, height * 0.62)

    function pointAt(share: real): point {
        return Qt.point(margin + share * (width - 2 * margin), horizon - Math.sin(Math.PI * share) * (horizon - margin));
    }

    /** The moon sets out again from the horizon: what the arc does under the mouse. */
    function replay(): void {
        if (!again.running) {
            again.restart();
        }
    }

    NumberAnimation on shown {
        running: moonArc.animated && moonArc.way.up
        to: moonArc.target
        duration: 1300
        easing.type: Easing.OutCubic
    }

    onTargetChanged: shown = target
    onShownChanged: path.requestPaint()

    SequentialAnimation {
        id: again

        PropertyAction {
            target: moonArc
            property: "shown"
            value: 0
        }

        NumberAnimation {
            target: moonArc
            property: "shown"
            to: moonArc.target
            duration: 1100
            easing.type: Easing.OutCubic
        }
    }

    Canvas {
        id: path

        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            const steps = 48;
            const text = Kirigami.Theme.textColor;

            context.clearRect(0, 0, width, height);
            context.lineWidth = 1.2;
            context.strokeStyle = Qt.rgba(text.r, text.g, text.b, 0.35);
            context.beginPath();
            context.moveTo(0, moonArc.horizon);
            context.lineTo(width, moonArc.horizon);
            context.stroke();

            context.setLineDash([2, 3]);
            context.beginPath();

            for (let step = 0; step <= steps; step++) {
                const point = moonArc.pointAt(step / steps);

                step === 0 ? context.moveTo(point.x, point.y) : context.lineTo(point.x, point.y);
            }

            context.stroke();
            context.setLineDash([]);
        }
    }

    // A patch of night under the moon, so that it shows under a light theme too.
    Rectangle {
        readonly property point centre: moonArc.pointAt(moonArc.shown)

        x: centre.x - width / 2
        y: centre.y - height / 2
        width: moonArc.discSize * 0.62
        height: width
        radius: width / 2
        color: "#1b2236"
        opacity: moonArc.way.up ? 1 : 0.45
    }

    Scenery.MoonDisc {
        readonly property point centre: moonArc.pointAt(moonArc.shown)

        x: centre.x - width / 2
        y: centre.y - height / 2
        width: moonArc.discSize
        height: width
        phase: moonArc.phase
        opacity: moonArc.way.up ? 1 : 0.45
    }
}
