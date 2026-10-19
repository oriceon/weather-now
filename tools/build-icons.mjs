#!/usr/bin/env node
/**
 * Builds contents/icons from the Meteocons packages (https://meteocons.com, MIT licence).
 *
 *     node tools/build-icons.mjs <canvaskit-wasm> <@meteocons/lottie> <@meteocons/svg-static>
 *
 * The three arguments are the unpacked npm packages. The still pictures are copied as they
 * are. The animations are Lottie files, which Plasma cannot play without an extra module, so
 * each is drawn frame by frame with Skia into one picture the widget plays as a film strip.
 */
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { DETAIL_ICONS, SHEET, moonIcon } from '../package/contents/code/meteocons.mjs';
import { PHASE_KEYS } from '../package/contents/code/moon.mjs';
import { METEOCONS } from '../package/contents/code/wmo.mjs';

const STYLE = 'fill';

const [canvasKitPackage, lottiePackage, staticPackage] = process.argv.slice(2);

if (!staticPackage) {
    console.error('usage: build-icons.mjs <canvaskit-wasm> <@meteocons/lottie> <@meteocons/svg-static>');
    process.exit(1);
}

const icons = join(dirname(fileURLToPath(import.meta.url)), '..', 'package', 'contents', 'icons');
// The full build is the one that has the Lottie player.
const canvasKitBuild = join(canvasKitPackage, 'bin', 'full');
const CanvasKit = await createRequire(import.meta.url)(join(canvasKitBuild, 'canvaskit.js'))({
    locateFile: (file) => join(canvasKitBuild, file),
});

// Starts from nothing, so that an icon that is no longer used does not stay behind.
rmSync(icons, { recursive: true, force: true });
mkdirSync(join(icons, 'static'), { recursive: true });
mkdirSync(join(icons, 'animated'), { recursive: true });
copyFileSync(join(staticPackage, 'LICENSE'), join(icons, 'LICENSE'));

for (const name of [...METEOCONS, ...DETAIL_ICONS, ...PHASE_KEYS.map(moonIcon)]) {
    copyFileSync(join(staticPackage, STYLE, `${name}.svg`), join(icons, 'static', `${name}.svg`));
}

for (const name of METEOCONS) {
    const animation = CanvasKit.MakeManagedAnimation(readFileSync(join(lottiePackage, STYLE, `${name}.json`), 'utf8'), {});
    const surface = CanvasKit.MakeSurface(SHEET.columns * SHEET.frameSize, SHEET.rows * SHEET.frameSize);
    const canvas = surface.getCanvas();

    if (Math.abs(animation.duration() - SHEET.seconds) > 0.01) {
        throw new Error(`${name} lasts ${animation.duration()} s; the film strips assume ${SHEET.seconds} s`);
    }

    canvas.clear(CanvasKit.TRANSPARENT);

    for (let frame = 0; frame < SHEET.frames; frame++) {
        const x = (frame % SHEET.columns) * SHEET.frameSize;
        const y = Math.floor(frame / SHEET.columns) * SHEET.frameSize;

        // A fraction of the loop: frame 0 of the next round is the one after the last.
        animation.seek(frame / SHEET.frames);
        canvas.save();
        canvas.clipRect(CanvasKit.XYWHRect(x, y, SHEET.frameSize, SHEET.frameSize), CanvasKit.ClipOp.Intersect, false);
        animation.render(canvas, CanvasKit.XYWHRect(x, y, SHEET.frameSize, SHEET.frameSize));
        canvas.restore();
    }

    const picture = Buffer.from(surface.makeImageSnapshot().encodeToBytes());

    writeFileSync(join(icons, 'animated', `${name}.png`), picture);
    console.log(`${name}: ${Math.round(picture.length / 1024)} KB`);

    surface.delete();
    animation.delete();
}
