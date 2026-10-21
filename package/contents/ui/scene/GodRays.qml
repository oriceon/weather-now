import QtQuick

import "../../code/scene.mjs" as Scene

/**
 * Crepuscular rays: beams of sunlight fanning down from the sun through the gaps in the clouds. The
 * item hangs from the sun, its top in the middle; the beams sway a little as the clouds move.
 */
Canvas {
    id: rays

    property bool running: false
    readonly property int beams: 11

    transformOrigin: Item.Top

    onPaint: {
        const context = getContext("2d");
        const origin = width / 2;

        context.clearRect(0, 0, width, height);

        for (let beam = 0; beam < beams; beam++) {
            const angle = (beam / (beams - 1) - 0.5) * 1.6 + (Scene.noise(beam, 81) - 0.5) * 0.15;
            const spread = 0.025 + Scene.noise(beam, 82) * 0.035;
            const length = height * (0.6 + 0.4 * Scene.noise(beam, 83));
            const fade = context.createLinearGradient(0, 0, 0, length);

            fade.addColorStop(0, "rgba(255, 246, 215, 0.3)");
            fade.addColorStop(0.45, "rgba(255, 246, 215, 0.1)");
            fade.addColorStop(1, "rgba(255, 246, 215, 0)");
            context.fillStyle = fade;
            context.beginPath();
            context.moveTo(origin, 0);
            context.lineTo(origin + Math.sin(angle - spread) * length, Math.cos(angle - spread) * length);
            context.lineTo(origin + Math.sin(angle + spread) * length, Math.cos(angle + spread) * length);
            context.closePath();
            context.fill();
        }
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    SequentialAnimation on rotation {
        running: rays.running
        loops: Animation.Infinite

        NumberAnimation {
            to: 4
            duration: 9000
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            to: -4
            duration: 9000
            easing.type: Easing.InOutSine
        }
    }
}
