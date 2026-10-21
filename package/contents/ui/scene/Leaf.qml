import QtQuick

/** A leaf, blown by the wind. */
Canvas {
    id: leaf

    property color colour: "#d9822b"

    onColourChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");

        context.clearRect(0, 0, width, height);
        context.fillStyle = colour;
        context.beginPath();
        context.moveTo(0, height / 2);
        context.quadraticCurveTo(width * 0.5, -height * 0.25, width, height / 2);
        context.quadraticCurveTo(width * 0.5, height * 1.25, 0, height / 2);
        context.fill();
        context.strokeStyle = "rgba(0, 0, 0, 0.25)";
        context.lineWidth = 0.8;
        context.beginPath();
        context.moveTo(0, height / 2);
        context.lineTo(width, height / 2);
        context.stroke();
    }
}
