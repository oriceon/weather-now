import QtQuick

// The product picture of Weather Now: a sun behind a cloud that rains, on a day sky, drawn like the
// one of Solar Now. With `phase` stepped from 0 to 1 it is an animation that loops.
Canvas {
    width: 512
    height: 512

    /**
     * 0…1 along the loop of the animated picture; 0 is the still one. The rays turn by one ray, the
     * glow breathes, the cloud sways and three drops fall, one after the other.
     */
    property real phase: 0
    readonly property real wave: Math.cos(2 * Math.PI * phase)
    readonly property real sway: 12 * Math.sin(2 * Math.PI * phase)

    onPhaseChanged: requestPaint()

    /** The round parts of the cloud, as centre and radius, before it sways. */
    readonly property var puffs: [[178, 300, 62], [250, 262, 84], [330, 286, 70], [382, 318, 46]]

    function cloud(c, dx, dy) {
        for (const puff of puffs) {
            c.beginPath();
            c.arc(puff[0] + dx, puff[1] + dy, puff[2], 0, Math.PI * 2);
            c.fill();
        }

        c.beginPath();
        c.roundedRect(130 + dx, 300 + dy, 290, 76, 38, 38);
        c.fill();
    }

    onPaint: {
        const c = getContext("2d");
        c.reset();

        // The rounded square, a day sky.
        c.beginPath();
        c.roundedRect(0, 0, width, height, 112, 112);
        const sky = c.createLinearGradient(0, 0, 0, height);
        sky.addColorStop(0, "#1f4fd8");
        sky.addColorStop(1, "#7cc8ff");
        c.fillStyle = sky;
        c.fill();
        c.save();
        c.clip();

        // The sun, high on the right, with its glow and twelve rays turned by one of them over the loop.
        const glow = c.createRadialGradient(340, 170, 60, 340, 170, 230);
        glow.addColorStop(0, `rgba(255, 244, 214, ${0.40 + 0.12 * wave})`);
        glow.addColorStop(1, "rgba(255, 244, 214, 0)");
        c.fillStyle = glow;
        c.fillRect(0, 0, width, height);

        c.save();
        c.translate(340, 170);
        c.rotate(phase * Math.PI / 6);
        c.fillStyle = "rgba(255, 206, 64, 0.9)";

        for (let ray = 0; ray < 12; ray++) {
            c.rotate(Math.PI / 6);
            c.beginPath();
            c.moveTo(-10, -98); c.lineTo(0, -146); c.lineTo(10, -98); c.closePath();
            c.fill();
        }

        c.restore();

        const sun = c.createRadialGradient(322, 150, 10, 340, 170, 86);
        sun.addColorStop(0, "#fff6c8");
        sun.addColorStop(0.6, "#ffd23f");
        sun.addColorStop(1, "#ffab00");
        c.beginPath();
        c.arc(340, 170, 84, 0, Math.PI * 2);
        c.fillStyle = sun;
        c.fill();

        // Three drops under the cloud, each a third of the loop behind the one before; they fade in
        // as they leave the cloud and out as they fall.
        c.lineCap = "round";
        c.lineWidth = 14;

        for (let drop = 0; drop < 3; drop++) {
            const fall = (phase + drop / 3) % 1;
            const x = 200 + drop * 66 + sway * 0.5;
            const y = 384 + fall * 96;
            c.strokeStyle = `rgba(232, 246, 255, ${Math.sin(Math.PI * fall)})`;
            c.beginPath();
            c.moveTo(x, y);
            c.lineTo(x - 6, y + 26);
            c.stroke();
        }

        // The cloud, swaying, with a soft shadow under it.
        c.fillStyle = "rgba(10, 40, 110, 0.18)";
        cloud(c, sway, 12);
        const white = c.createLinearGradient(0, 180, 0, 376);
        white.addColorStop(0, "#ffffff");
        white.addColorStop(1, "#d9e6f7");
        c.fillStyle = white;
        cloud(c, sway, 0);

        c.restore();
    }
}
