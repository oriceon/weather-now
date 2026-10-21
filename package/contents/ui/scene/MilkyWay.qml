import QtQuick

import "../../code/scene.mjs" as Scene

/** The Milky Way: a faint band of light across a clear, moonless night, dense with small stars. */
Canvas {
    id: milkyWay

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        const length = Math.hypot(width, height);

        context.clearRect(0, 0, width, height);
        context.save();
        context.translate(width / 2, height * 0.35);
        context.rotate(-0.42);

        // The band itself, brightest along its middle.
        const band = context.createLinearGradient(0, -height * 0.18, 0, height * 0.18);

        band.addColorStop(0, "rgba(200, 210, 255, 0)");
        band.addColorStop(0.45, "rgba(214, 220, 255, 0.10)");
        band.addColorStop(0.55, "rgba(255, 240, 225, 0.12)");
        band.addColorStop(1, "rgba(200, 210, 255, 0)");
        context.fillStyle = band;
        context.fillRect(-length / 2, -height * 0.18, length, height * 0.36);

        // Small stars, thicker towards the middle of the band.
        for (let index = 0; index < 220; index++) {
            const along = (Scene.noise(index, 61) - 0.5) * length;
            const across = (Scene.noise(index, 62) + Scene.noise(index, 63) - 1) * height * 0.16;
            const size = 0.4 + Scene.noise(index, 64) * 0.9;

            context.fillStyle = `rgba(255, 255, 255, ${0.25 + Scene.noise(index, 65) * 0.5})`;
            context.fillRect(along, across, size, size);
        }

        context.restore();
    }
}
