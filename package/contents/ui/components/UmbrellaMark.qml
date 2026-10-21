import QtQuick

/** A small open umbrella: rain on its way. */
Canvas {
    id: umbrella

    property color colour: "#5cb7f0"

    implicitWidth: 12
    implicitHeight: 12

    onColourChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        const centre = width / 2;
        const top = height * 0.12;
        const rim = height * 0.52;
        const radius = width * 0.46;

        context.clearRect(0, 0, width, height);
        context.fillStyle = colour;
        context.strokeStyle = colour;
        context.lineWidth = Math.max(1, width * 0.1);
        context.lineCap = "round";

        // The canopy, scalloped along its rim.
        context.beginPath();
        context.moveTo(centre - radius, rim);
        context.quadraticCurveTo(centre - radius, top, centre, top);
        context.quadraticCurveTo(centre + radius, top, centre + radius, rim);
        context.quadraticCurveTo(centre + radius / 2, rim - height * 0.1, centre, rim);
        context.quadraticCurveTo(centre - radius / 2, rim - height * 0.1, centre - radius, rim);
        context.fill();

        // The shaft and its hook.
        context.beginPath();
        context.moveTo(centre, rim);
        context.lineTo(centre, height * 0.82);
        context.arc(centre - width * 0.12, height * 0.82, width * 0.12, 0, Math.PI);
        context.stroke();
    }
}
