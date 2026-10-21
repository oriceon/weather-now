import QtQuick
import org.kde.kirigami as Kirigami

import "../../code/i18n.mjs" as I18n

/** A compass rose with an arrow that swings round to where the wind blows, as it appears. */
Item {
    id: compass

    /** Where the wind comes from, in degrees: 0 north, 90 east. */
    required property real direction
    required property string language
    required property var typography
    /** False draws the arrow where it ends, without the swing. */
    property bool animated: true
    property color accent: "#5cb7f0"

    /** The arrow points where the wind goes, as on a weather map. */
    readonly property real target: direction + 180
    property real shown: animated ? target - 160 : target

    NumberAnimation on shown {
        running: compass.animated
        to: compass.target
        duration: 1400
        easing.type: Easing.OutElastic
        easing.amplitude: 1
        easing.period: 0.55
    }

    onTargetChanged: shown = target

    /** The arrow is caught by a gust and swings back round: what the compass does under the mouse. */
    function replay(): void {
        if (!again.running) {
            again.restart();
        }
    }

    SequentialAnimation {
        id: again

        NumberAnimation {
            target: compass
            property: "shown"
            to: compass.target - 120
            duration: 300
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: compass
            property: "shown"
            to: compass.target
            duration: 1300
            easing.type: Easing.OutElastic
            easing.amplitude: 1
            easing.period: 0.55
        }
    }

    Canvas {
        id: rose

        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            const centre = width / 2;
            const radius = width / 2 - 1.5;

            context.clearRect(0, 0, width, height);
            context.strokeStyle = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.35);
            context.lineWidth = 1.5;
            context.beginPath();
            context.arc(centre, centre, radius, 0, 2 * Math.PI);
            context.stroke();

            for (let tick = 0; tick < 12; tick++) {
                const angle = tick * Math.PI / 6;
                const length = tick % 3 === 0 ? radius * 0.16 : radius * 0.08;

                context.beginPath();
                context.moveTo(centre + Math.sin(angle) * radius, centre - Math.cos(angle) * radius);
                context.lineTo(centre + Math.sin(angle) * (radius - length), centre - Math.cos(angle) * (radius - length));
                context.stroke();
            }
        }
    }

    Repeater {
        model: [0, 90, 180, 270]

        delegate: Text {
            required property int modelData

            readonly property real angle: modelData * Math.PI / 180
            readonly property real distance: compass.width * 0.3

            x: compass.width / 2 + Math.sin(angle) * distance - width / 2
            y: compass.height / 2 - Math.cos(angle) * distance - height / 2
            font.family: compass.typography.family
            font.pointSize: Math.max(6, compass.typography.size * 0.7)
            font.weight: modelData === 0 ? Font.Bold : Font.Normal
            color: Kirigami.Theme.textColor
            opacity: modelData === 0 ? 0.9 : 0.6
            text: I18n.compass(modelData, compass.language)
        }
    }

    Canvas {
        id: arrow

        anchors.fill: parent
        rotation: compass.shown

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            const centre = width / 2;
            const length = width * 0.36;

            context.clearRect(0, 0, width, height);
            context.fillStyle = compass.accent;
            context.beginPath();
            context.moveTo(centre, centre - length);
            context.lineTo(centre + length * 0.3, centre - length * 0.25);
            context.lineTo(centre + length * 0.09, centre - length * 0.3);
            context.lineTo(centre + length * 0.09, centre + length * 0.75);
            context.lineTo(centre - length * 0.09, centre + length * 0.75);
            context.lineTo(centre - length * 0.09, centre - length * 0.3);
            context.lineTo(centre - length * 0.3, centre - length * 0.25);
            context.closePath();
            context.fill();
        }
    }
}
