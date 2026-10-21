import QtQuick

/** A rainbow, faint as a real one, across the part of the sky opposite the sun. */
Canvas {
    id: rainbow

    /** True when the sun is on the left, low in the morning: the rainbow stands on the right. */
    property bool sunOnLeft: true

    readonly property var bands: ["#ff4b4b", "#ff9a3c", "#ffe14d", "#58d36a", "#4aa8ff", "#5a62ff", "#a35bff"]

    onSunOnLeftChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        const centreX = sunOnLeft ? width * 0.78 : width * 0.22;
        const centreY = height * 1.08;
        const outer = height * 0.98;
        const band = outer * 0.035;

        context.clearRect(0, 0, width, height);
        context.lineWidth = band * 1.15;

        bands.forEach((colour, index) => {
            context.strokeStyle = colour;
            context.globalAlpha = 0.22;
            context.beginPath();
            context.arc(centreX, centreY, outer - index * band, Math.PI, 2 * Math.PI);
            context.stroke();
        });

        // The sky inside the bow is a touch brighter, as it is in nature.
        const glow = context.createRadialGradient(centreX, centreY, 0, centreX, centreY, outer - bands.length * band);

        glow.addColorStop(0.6, "rgba(255, 255, 255, 0)");
        glow.addColorStop(1, "rgba(255, 255, 255, 0.07)");
        context.globalAlpha = 1;
        context.fillStyle = glow;
        context.beginPath();
        context.arc(centreX, centreY, outer - bands.length * band, Math.PI, 2 * Math.PI);
        context.fill();
    }
}
