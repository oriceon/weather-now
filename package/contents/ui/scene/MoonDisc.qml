import QtQuick

/** The moon, lit as much as its phase says. */
Canvas {
    id: moon

    /** Position in the lunar cycle: 0 new moon, 0.5 full moon, see moonPhase() in code/moon.mjs. */
    property real phase: 0.5
    /** Seen from the southern hemisphere, the moon is turned over: a waxing one is lit on the left. */
    property bool south: false

    /** The terminator is an ellipse; a polyline of this many steps is round enough. */
    readonly property int terminatorSteps: 24

    onPaint: {
        const context = getContext("2d");
        const centre = width / 2;
        const radius = width * 0.3;
        const glow = context.createRadialGradient(centre, centre, radius * 0.8, centre, centre, centre);

        glow.addColorStop(0, "rgba(214, 226, 255, 0.3)");
        glow.addColorStop(1, "rgba(214, 226, 255, 0)");

        context.clearRect(0, 0, width, height);
        context.fillStyle = glow;
        context.fillRect(0, 0, width, height);

        // The whole disc, faintly, as the unlit part is seen from Earth.
        context.fillStyle = "rgba(190, 202, 230, 0.16)";
        context.beginPath();
        context.arc(centre, centre, radius, 0, 2 * Math.PI);
        context.fill();

        // The lit part: the limb on one side, the terminator back. A waning moon is the mirror image.
        const mirror = (phase > 0.5 ? -1 : 1) * (south ? -1 : 1);
        const bulge = Math.cos(2 * Math.PI * phase);

        context.fillStyle = "rgba(246, 243, 228, 1)";
        context.beginPath();

        for (let step = 0; step <= terminatorSteps; step++) {
            const angle = -Math.PI / 2 + step * Math.PI / terminatorSteps;

            context.lineTo(centre + mirror * Math.cos(angle) * radius, centre + Math.sin(angle) * radius);
        }

        for (let step = terminatorSteps; step >= 0; step--) {
            const angle = -Math.PI / 2 + step * Math.PI / terminatorSteps;

            context.lineTo(centre + mirror * bulge * Math.cos(angle) * radius, centre + Math.sin(angle) * radius);
        }

        context.closePath();
        context.fill();
    }
    onWidthChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onSouthChanged: requestPaint()
}
