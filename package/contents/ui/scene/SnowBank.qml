import QtQuick

import "../../code/scene.mjs" as Scene

/** Snow that has settled along the bottom, in soft drifts. */
Canvas {
    id: bank

    /** How high the drifts are, as a share of the height of the scene. */
    property real depth: 0

    onDepthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        const top = height * (1 - depth);
        const steps = 12;

        context.clearRect(0, 0, width, height);

        if (depth <= 0) {
            return;
        }

        const fill = context.createLinearGradient(0, top - height * depth * 0.4, 0, height);

        fill.addColorStop(0, "rgba(246, 250, 255, 0.95)");
        fill.addColorStop(1, "rgba(206, 220, 238, 0.95)");
        context.fillStyle = fill;
        context.beginPath();
        context.moveTo(0, height);
        context.lineTo(0, top);

        for (let step = 1; step <= steps; step++) {
            const x = width * step / steps;
            const swell = (Scene.noise(step, 101) - 0.5) * height * depth * 0.6;

            context.quadraticCurveTo(x - width / steps / 2, top + swell - height * depth * 0.25, x, top + swell * 0.4);
        }

        context.lineTo(width, height);
        context.closePath();
        context.fill();
    }
}
