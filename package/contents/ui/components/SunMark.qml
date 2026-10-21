import QtQuick

/** A small sun on the horizon, with an arrow up for sunrise or down for sunset. */
Canvas {
    id: mark

    /** sunrise | sunset */
    property string kind: "sunrise"
    property color colour: "#f6b73c"

    implicitWidth: 16
    implicitHeight: 12

    onKindChanged: requestPaint()
    onColourChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        const horizon = height * 0.78;
        const radius = height * 0.36;
        const centre = width * 0.38;

        context.clearRect(0, 0, width, height);
        context.strokeStyle = colour;
        context.fillStyle = colour;
        context.lineWidth = 1.4;
        context.lineCap = "round";

        context.beginPath();
        context.arc(centre, horizon, radius, Math.PI, 0);
        context.fill();

        context.beginPath();
        context.moveTo(0, horizon + 0.5);
        context.lineTo(width, horizon + 0.5);
        context.stroke();

        // The arrow, beside the sun: up for sunrise, down for sunset.
        const x = width * 0.86;
        const top = height * 0.12;
        const bottom = horizon - 2;
        const tip = kind === "sunrise" ? top : bottom;
        const turn = kind === "sunrise" ? 3 : -3;

        context.beginPath();
        context.moveTo(x, top);
        context.lineTo(x, bottom);
        context.moveTo(x - 2.5, tip + turn);
        context.lineTo(x, tip);
        context.lineTo(x + 2.5, tip + turn);
        context.stroke();
    }
}
