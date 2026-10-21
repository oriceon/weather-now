// The land under the sky of the Today tab, and of the wallpaper, drawn as the eye sees it from
// afar: the farther, the paler and bluer, in the colours of the season, the light of the hour and
// the snow that has settled. Each kind of land has a module of its own in land/; the shapes stay
// the same for each, so that the picture does not change from one refresh to the next.
//
// The land is drawn in three layers, from the farthest, which the mouse moves each by its depth.
// The painting functions take the 2D context of a Canvas and `look`:
// `{ width, height, isDay, horizon, warmth, snow, lightX, season, wind }`, where `lightX` is where
// the sun or the moon is across the layer, in pixels, `snow` and `warmth` go from 0 to 1, and
// `wind` is in km/h.

import { paintCity } from './land/city.mjs';
import { paintHills } from './land/hills.mjs';
import { NEAR_SHORE, SHORE, paintLake } from './land/lake.mjs';
import { paintPoppies } from './land/poppies.mjs';
import { BEACH, HORIZON, paintSea } from './land/sea.mjs';
import { paintVillage } from './land/village.mjs';

export { CITY_LAYERS, beacons, skyline } from './land/city.mjs';
export { HILL_RANGES, crest } from './land/hills.mjs';
export { BEACH, HORIZON, paintSurf, shoreline } from './land/sea.mjs';
export { chimneys, houses } from './land/village.mjs';
export { fractal, landColour, seasonOf, smoothNoise } from './land/shared.mjs';

/** The layers of the land, from the farthest. */
export const PARTS = ['back', 'middle', 'front'];
/** Every kind of land, in the order of the settings; "none" is no land at all. */
export const KINDS = ['none', 'hills', 'city', 'sea', 'poppies', 'lake', 'village'];

const PAINTERS = { hills: paintHills, city: paintCity, sea: paintSea, poppies: paintPoppies, lake: paintLake, village: paintVillage };

/** Where the water of a kind of land lies, `[top, bottom]` as shares of the height of the land, for the glitter of the sun and the moon on it; null for land without water. */
export function waterBand(kind) {
    return { sea: [HORIZON, BEACH], lake: [SHORE, NEAR_SHORE] }[kind] || null;
}

/** Paints one layer of the land of kind `kind`. */
export function paintLand(context, kind, look, part) {
    context.clearRect(0, 0, look.width, look.height);

    if (PAINTERS[kind]) {
        PAINTERS[kind](context, look, part);
    }
}
