import QtQuick

import "../../code/scene.mjs" as Scene

/**
 * The faint stars of a night sky, hundreds of them, painted once: most of them tiny, some brighter
 * with a glow, bluish, white or warm, thinning out towards the horizon, where the air dims them.
 */
Canvas {
    id: field

    property int count: 0

    onPaint: {
        const context = getContext("2d");
        const colours = ["207, 224, 255", "255, 255, 255", "255, 233, 196"];

        context.clearRect(0, 0, width, height);

        for (let star = 0; star < count; star++) {
            const x = Scene.noise(star, 51) * width;
            // More of them high up: the square favours small values.
            const y = Math.pow(Scene.noise(star, 52), 1.4) * height * 0.85;
            const bright = Scene.noise(star, 53);
            const size = bright > 0.9 ? 1.8 + Scene.noise(star, 54) * 0.8 : bright > 0.55 ? 1.5 : 1;
            const alpha = (0.55 + 0.45 * Scene.noise(star, 55)) * Math.pow(1 - y / height, 0.5);
            const colour = colours[Math.floor(Scene.noise(star, 56) * colours.length)];

            if (size > 1.5) {
                const glow = context.createRadialGradient(x, y, 0, x, y, size * 3);

                glow.addColorStop(0, `rgba(${colour}, ${alpha * 0.5})`);
                glow.addColorStop(1, `rgba(${colour}, 0)`);
                context.fillStyle = glow;
                context.fillRect(x - size * 3, y - size * 3, size * 6, size * 6);
            }

            context.fillStyle = `rgba(${colour}, ${alpha})`;

            // A point of light a pixel or so wide: a circle that small would not show at all.
            if (size > 1.5) {
                context.beginPath();
                context.arc(x, y, size / 2, 0, 2 * Math.PI);
                context.fill();
            } else {
                context.fillRect(Math.round(x), Math.round(y), size, size);
            }
        }
    }
    // None left, as the night ends: the last of them stay painted while their layer fades out.
    onCountChanged: {
        if (count > 0) {
            requestPaint();
        }
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
