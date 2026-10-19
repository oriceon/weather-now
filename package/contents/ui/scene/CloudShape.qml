import QtQuick

import "../../code/scene.mjs" as Scene

/** A cloud: soft puffs along a flat base, painted once and then only moved. */
Canvas {
    id: cloud

    /** Picks the shape; the same seed always gives the same cloud. */
    property int seed: 0
    /** Red, green and blue of the cloud, 0..255. */
    property var tone: [255, 255, 255]

    readonly property int puffs: 6

    onPaint: {
        const context = getContext("2d");
        const [red, green, blue] = tone;

        context.clearRect(0, 0, width, height);

        for (let puff = 0; puff < puffs; puff++) {
            const along = puff / (puffs - 1);
            // Puffs are bigger towards the middle of the cloud.
            const radius = height * (0.28 + 0.2 * Scene.noise(seed * 7 + puff, 2)) * (1 - 0.4 * Math.abs(along - 0.5) * 2);
            const x = width * (0.16 + 0.68 * along) + (Scene.noise(seed * 7 + puff, 1) - 0.5) * width * 0.06;
            const y = height * 0.66 - radius * 0.3;
            const gradient = context.createRadialGradient(x, y, 0, x, y, radius);

            gradient.addColorStop(0, `rgba(${red}, ${green}, ${blue}, 0.95)`);
            gradient.addColorStop(0.6, `rgba(${red}, ${green}, ${blue}, 0.7)`);
            gradient.addColorStop(1, `rgba(${red}, ${green}, ${blue}, 0)`);

            context.fillStyle = gradient;
            context.beginPath();
            context.arc(x, y, radius, 0, 2 * Math.PI);
            context.fill();
        }
    }
    onWidthChanged: requestPaint()
    onToneChanged: requestPaint()
    onSeedChanged: requestPaint()
}
