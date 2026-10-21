import QtQuick
import org.kde.kirigami as Kirigami

import "../../code/scene.mjs" as Scene

/** The way of the sun over the day, from sunrise to sunset, with the sun where it is now. */
Item {
    id: sunArc

    /** Wall-clock times of the forecast location. */
    required property string now
    required property string sunrise
    required property string sunset
    /** False puts the sun where it is, without it climbing there. */
    property bool animated: true
    property color colour: "#f6b73c"

    readonly property var position: Scene.celestial(now, sunrise, sunset)
    /** Share of the day gone, 0 at sunrise and 1 at sunset; at night the sun is below the horizon. */
    readonly property real target: position.isDay ? position.progress : 0
    property real shown: animated ? 0 : target
    readonly property real margin: Math.max(4, height * 0.12)
    readonly property real horizon: height - margin * 0.6

    NumberAnimation on shown {
        running: sunArc.animated && sunArc.position.isDay
        to: sunArc.target
        duration: 1300
        easing.type: Easing.OutCubic
    }

    onTargetChanged: shown = target

    /** The sun rises again and climbs to where it is: what the arc does under the mouse. By night, nothing. */
    function replay(): void {
        if (position.isDay && !again.running) {
            again.restart();
        }
    }

    SequentialAnimation {
        id: again

        PropertyAction {
            target: sunArc
            property: "shown"
            value: 0
        }

        NumberAnimation {
            target: sunArc
            property: "shown"
            to: sunArc.target
            duration: 1100
            easing.type: Easing.OutCubic
        }
    }
    onShownChanged: path.requestPaint()

    function pointAt(share: real): point {
        return Qt.point(margin + share * (width - 2 * margin), horizon - Math.sin(Math.PI * share) * (horizon - margin));
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
            context.moveTo(0, sunArc.horizon);
            context.lineTo(width, sunArc.horizon);
            context.stroke();

            // The whole way, dotted; the part gone, solid.
            context.setLineDash([2, 3]);
            context.beginPath();

            for (let step = 0; step <= steps; step++) {
                const point = sunArc.pointAt(step / steps);

                step === 0 ? context.moveTo(point.x, point.y) : context.lineTo(point.x, point.y);
            }

            context.stroke();
            context.setLineDash([]);

            if (!sunArc.position.isDay) {
                return;
            }

            context.lineWidth = 2;
            context.strokeStyle = sunArc.colour;
            context.beginPath();

            for (let step = 0; step <= Math.round(steps * sunArc.shown); step++) {
                const point = sunArc.pointAt(step / steps);

                step === 0 ? context.moveTo(point.x, point.y) : context.lineTo(point.x, point.y);
            }

            context.stroke();

            const sun = sunArc.pointAt(sunArc.shown);
            const radius = Math.max(3, height * 0.1);
            const glow = context.createRadialGradient(sun.x, sun.y, radius * 0.5, sun.x, sun.y, radius * 2.6);

            glow.addColorStop(0, "rgba(255, 210, 90, 0.55)");
            glow.addColorStop(1, "rgba(255, 210, 90, 0)");
            context.fillStyle = glow;
            context.fillRect(sun.x - radius * 3, sun.y - radius * 3, radius * 6, radius * 6);
            context.fillStyle = sunArc.colour;
            context.beginPath();
            context.arc(sun.x, sun.y, radius, 0, 2 * Math.PI);
            context.fill();
        }
    }
}
