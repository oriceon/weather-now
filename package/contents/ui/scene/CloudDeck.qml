import QtQuick

import "../../code/scene.mjs" as Scene

/**
 * A covered sky: a deck of cloud across the whole top of the scene, lumpy underneath, thinning
 * towards the horizon. Two copies side by side drift with the wind, so that it never ends.
 */
Item {
    id: deck

    /** The drift, from 0 to 1, over and over; see driftClock in WeatherScene. */
    property real drift: 0
    property int windSign: 1
    property string lit: "#e4e8ee"
    property string shade: "#8c97a8"

    clip: true

    Repeater {
        model: 2

        delegate: Canvas {
            id: sheet

            required property int index

            width: deck.width
            height: deck.height
            // On whole pixels: at a fraction of one, the two sheets overlapped in a dark line.
            x: Math.round(((deck.windSign > 0 ? deck.drift : 1 - deck.drift) + sheet.index - 1) * deck.width)

            function rgba(hex: string, alpha: real): string {
                return `rgba(${parseInt(hex.slice(1, 3), 16)}, ${parseInt(hex.slice(3, 5), 16)}, ${parseInt(hex.slice(5, 7), 16)}, ${alpha})`;
            }

            onPaint: {
                const context = getContext("2d");
                const rows = 4;
                const across = 5;

                context.clearRect(0, 0, width, height);

                // Row after row of long, flat puffs, the lower rows fainter: a deck of stratus is
                // drawn out by the wind, not heaped. A puff across an edge is drawn again on the
                // other side, where the next sheet carries it on, so that two sheets meet without
                // a seam.
                for (let row = 0; row < rows; row++) {
                    for (let column = 0; column < across; column++) {
                        const seed = row * 31 + column;
                        const x = (column + (row % 2) * 0.5 + (Scene.noise(seed, 91) - 0.5) * 0.5) / across * width;
                        const y = height * (0.01 + row * 0.11 + Scene.noise(seed, 92) * 0.05);
                        const tall = height * (0.1 + 0.06 * Scene.noise(seed, 94));
                        const wide = width / across * (0.8 + 0.5 * Scene.noise(seed, 93));
                        const alpha = 0.75 - row * 0.15;

                        [0, -width, width].filter(shift => x + shift + wide > 0 && x + shift - wide < width).forEach(shift => {
                            const puff = context.createRadialGradient(0, -tall * 0.25, 0, 0, 0, tall);

                            puff.addColorStop(0, sheet.rgba(deck.lit, alpha));
                            puff.addColorStop(0.55, sheet.rgba(deck.shade, alpha * 0.85));
                            puff.addColorStop(1, sheet.rgba(deck.shade, 0));
                            context.save();
                            context.translate(x + shift, y);
                            context.scale(wide / tall, 1);
                            context.fillStyle = puff;
                            context.fillRect(-tall, -tall, tall * 2, tall * 2);
                            context.restore();
                        });
                    }
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: deck

                function onLitChanged(): void {
                    sheet.requestPaint();
                }

                function onShadeChanged(): void {
                    sheet.requestPaint();
                }
            }
        }
    }
}
