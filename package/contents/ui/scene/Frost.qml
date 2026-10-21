import QtQuick

import "../../code/scene.mjs" as Scene

/** Frost on the glass: a pale rim and ice crystals that grow in from the corners. */
Canvas {
    id: frost

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    /** A crystal: a stem that branches, and its branches branch again, smaller. */
    function crystal(context, x, y, angle, length, depth, seed): void {
        const endX = x + Math.cos(angle) * length;
        const endY = y + Math.sin(angle) * length;

        context.beginPath();
        context.moveTo(x, y);
        context.lineTo(endX, endY);
        context.stroke();

        if (depth === 0) {
            return;
        }

        for (let branch = 1; branch <= 3; branch++) {
            const along = branch / 4;
            const fromX = x + (endX - x) * along;
            const fromY = y + (endY - y) * along;
            const size = length * (0.45 - along * 0.2) * (0.7 + Scene.noise(seed * 5 + branch, 81) * 0.5);

            crystal(context, fromX, fromY, angle - 1.0, size, depth - 1, seed * 3 + branch);
            crystal(context, fromX, fromY, angle + 1.0, size, depth - 1, seed * 3 + branch + 7);
        }
    }

    onPaint: {
        const context = getContext("2d");
        const shortSide = Math.min(width, height);
        const corners = [[0, 0, Math.PI / 4], [width, 0, Math.PI * 3 / 4], [0, height, -Math.PI / 4], [width, height, -Math.PI * 3 / 4]];

        context.clearRect(0, 0, width, height);

        // The rim, frosted most at the edges and corners.
        const rim = shortSide * 0.16;

        [["left", 0, 0, rim, 0], ["right", width, 0, width - rim, 0], ["top", 0, 0, 0, rim], ["bottom", 0, height, 0, height - rim]].forEach(([, x0, y0, x1, y1]) => {
            const gradient = context.createLinearGradient(x0, y0, x1, y1);

            gradient.addColorStop(0, "rgba(235, 245, 255, 0.42)");
            gradient.addColorStop(1, "rgba(235, 245, 255, 0)");
            context.fillStyle = gradient;
            context.fillRect(0, 0, width, height);
        });

        context.strokeStyle = "rgba(240, 248, 255, 0.55)";
        context.lineWidth = 1;
        context.lineCap = "round";

        corners.forEach(([x, y, towards], corner) => {
            for (let stem = 0; stem < 5; stem++) {
                const angle = towards + (Scene.noise(corner * 11 + stem, 82) - 0.5) * 1.3;
                const length = shortSide * (0.08 + Scene.noise(corner * 11 + stem, 83) * 0.1);

                frost.crystal(context, x, y, angle, length, 2, corner * 17 + stem);
            }
        });
    }
}
