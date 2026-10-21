import QtQuick

import "../../code/scene.mjs" as Scene

/**
 * A cumulus: a flat, shaded base under a heaped top that the light catches on one side. The heap
 * is a few broad masses with many small billows along their upper edge, as a cauliflower has, and
 * lower ones at the ends, so that its outline is ragged, not round. Painted once, then only moved;
 * it is painted again only when its size or its colours change.
 *
 * Its soft edge is a halo painted at a fifth of the size and stretched, which blurs it for nothing.
 * No shadowBlur: the blur of a Canvas is done pixel by pixel on the processor, and a few large
 * clouds took seconds to paint again, which froze Plasma whenever the widget was resized, as on
 * entering the edit mode of the desktop.
 */
Canvas {
    id: cloud

    /** Picks the shape; the same seed always gives the same cloud. */
    property int seed: 0
    /** The side the light comes from, where the top of the cloud is brightest. */
    property bool lightFromLeft: true
    /** The colour of the lit top, and of the shaded base, as #rrggbb. */
    property string lit: "#ffffff"
    property string shade: "#b8c4d6"

    /** The masses and billows of the heap, `{ x, y, radius, kind }`, in pixels of the cloud. */
    readonly property var heap: {
        const base = height * 0.8;
        const room = base - height * 0.1;
        const masses = 3 + seed % 3;
        const all = [];

        for (let mass = 0; mass < masses; mass++) {
            const along = 0.24 + 0.52 * (mass + 0.5 + (Scene.noise(seed * 13 + mass, 41) - 0.5) * 0.6) / masses;
            const middle = 1 - Math.abs(along - 0.5) * 1.3;
            const radius = room * (0.3 + 0.12 * Scene.noise(seed * 13 + mass, 42)) * (0.75 + 0.35 * middle);

            all.push({ x: along * width, y: base - radius * 0.72, radius, kind: "mass" });
        }

        // Billows along the upper edge of the masses: the cauliflower of a cumulus.
        const billows = 10 + Math.round(width / 45);

        for (let billow = 0; billow < billows; billow++) {
            const salt = seed * 31 + billow;
            const host = all[Math.floor(Scene.noise(salt, 43) * masses)];
            const angle = Math.PI * (1.08 + 0.84 * Scene.noise(salt, 44));
            const out = host.radius * (0.82 + 0.2 * Scene.noise(salt, 45));
            const radius = host.radius * (0.2 + 0.24 * Scene.noise(salt, 46));

            all.push({ x: host.x + Math.cos(angle) * out, y: host.y + Math.sin(angle) * out, radius, kind: "billow" });
        }

        // Lower heaps at the two ends, sitting on the base.
        [0.1 + 0.06 * Scene.noise(seed, 47), 0.9 - 0.06 * Scene.noise(seed, 48)].forEach((along, end) => {
            const radius = room * (0.16 + 0.08 * Scene.noise(seed * 3 + end, 49));

            all.push({ x: along * width, y: base - radius * 0.6, radius, kind: "end" });
        });

        return all;
    }

    function rgba(hex: string, alpha: real): string {
        return `rgba(${parseInt(hex.slice(1, 3), 16)}, ${parseInt(hex.slice(3, 5), 16)}, ${parseInt(hex.slice(5, 7), 16)}, ${alpha})`;
    }

    /** Adds the heap to the path, at `scale` of the size and with its billows `grow` times wider. */
    function heapPath(context: var, scale: real, grow: real): void {
        context.beginPath();
        heap.forEach(part => {
            const radius = part.radius * grow * scale;

            context.moveTo(part.x * scale + radius, part.y * scale);
            context.arc(part.x * scale, part.y * scale, radius, 0, 2 * Math.PI);
        });
    }

    onPaint: {
        const context = getContext("2d");
        const base = height * 0.8;
        const top = Math.min(...heap.map(part => part.y - part.radius));

        context.clearRect(0, 0, width, height);
        context.save();

        // The body, from the lit top to the shaded base.
        const fill = context.createLinearGradient(0, top, 0, base);

        fill.addColorStop(0, cloud.rgba(cloud.lit, 1));
        fill.addColorStop(0.55, cloud.rgba(cloud.lit, 0.97));
        fill.addColorStop(1, cloud.rgba(cloud.shade, 0.95));
        context.fillStyle = fill;
        cloud.heapPath(context, 1, 1);
        context.fill();

        // Within the body only: each mass and billow brighter on the side of the light, a little
        // shaded on the other, which sets the billows apart; the side away from the light dims and
        // the base darkens.
        context.globalCompositeOperation = "source-atop";

        const side = cloud.lightFromLeft ? -1 : 1;

        heap.forEach(part => {
            const glowX = part.x + side * part.radius * 0.35;
            const glowY = part.y - part.radius * 0.4;
            const glow = context.createRadialGradient(glowX, glowY, 0, glowX, glowY, part.radius);

            glow.addColorStop(0, `rgba(255, 255, 255, ${part.kind === "billow" ? 0.35 : 0.45})`);
            glow.addColorStop(1, "rgba(255, 255, 255, 0)");
            context.fillStyle = glow;
            context.fillRect(part.x - part.radius * 1.5, part.y - part.radius * 1.5, part.radius * 3, part.radius * 3);

            if (part.kind === "billow") {
                const shadeX = part.x - side * part.radius * 0.45;
                const shadeY = part.y + part.radius * 0.4;
                const fold = context.createRadialGradient(shadeX, shadeY, 0, shadeX, shadeY, part.radius * 0.75);

                // Faint: stronger, they read as spots on a big cloud.
                fold.addColorStop(0, cloud.rgba(cloud.shade, 0.13));
                fold.addColorStop(1, cloud.rgba(cloud.shade, 0));
                context.fillStyle = fold;
                context.fillRect(shadeX - part.radius, shadeY - part.radius, part.radius * 2, part.radius * 2);
            }
        });

        const away = context.createLinearGradient(cloud.lightFromLeft ? 0 : width, 0, cloud.lightFromLeft ? width : 0, 0);

        away.addColorStop(0.45, cloud.rgba(cloud.shade, 0));
        away.addColorStop(1, cloud.rgba(cloud.shade, 0.25));
        context.fillStyle = away;
        context.fillRect(0, 0, width, height);

        const underside = context.createLinearGradient(0, base - (base - top) * 0.35, 0, base);

        underside.addColorStop(0, cloud.rgba(cloud.shade, 0));
        underside.addColorStop(1, cloud.rgba(cloud.shade, 0.45));
        context.fillStyle = underside;
        context.fillRect(0, 0, width, height);

        // The base is flat but soft: the heap fades out just below it, instead of being cut.
        context.globalCompositeOperation = "destination-out";

        const below = context.createLinearGradient(0, base - height * 0.05, 0, base + height * 0.12);

        below.addColorStop(0, "rgba(0, 0, 0, 0)");
        below.addColorStop(1, "rgba(0, 0, 0, 1)");
        context.fillStyle = below;
        context.fillRect(0, base - height * 0.05, width, height);

        context.restore();
        context.globalCompositeOperation = "source-over";
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLitChanged: requestPaint()
    onShadeChanged: requestPaint()
    onSeedChanged: requestPaint()
    onLightFromLeftChanged: requestPaint()

    // The soft edge: the heap a little wider, painted small and stretched back, behind the body.
    Canvas {
        id: halo

        readonly property real scale: 0.2

        z: -1
        width: Math.max(1, cloud.width * scale)
        height: Math.max(1, cloud.height * scale)
        transformOrigin: Item.TopLeft
        smooth: true
        transform: Scale {
            xScale: 1 / halo.scale
            yScale: 1 / halo.scale
        }

        onPaint: {
            const context = getContext("2d");
            const base = cloud.height * 0.8 * scale;

            context.clearRect(0, 0, width, height);
            context.fillStyle = cloud.rgba(cloud.lit, 0.4);
            cloud.heapPath(context, scale, 1.12);
            context.fill();

            // Not under the base, which stays flat.
            context.globalCompositeOperation = "destination-out";

            const below = context.createLinearGradient(0, base - height * 0.04, 0, base + height * 0.08);

            below.addColorStop(0, "rgba(0, 0, 0, 0)");
            below.addColorStop(1, "rgba(0, 0, 0, 1)");
            context.fillStyle = below;
            context.fillRect(0, 0, width, height);
            context.globalCompositeOperation = "source-over";
        }

        Connections {
            target: cloud

            function onPaint(): void {
                halo.requestPaint();
            }
        }
    }
}
