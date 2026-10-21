import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';

const schema = readFileSync(new URL('../package/contents/config/main.xml', import.meta.url), 'utf8');

/** The default of a setting, as main.xml gives it. */
function defaultOf(name) {
    const entry = new RegExp(`<entry name="${name}"[^>]*>[\\s\\S]*?<default>([^<]*)</default>`).exec(schema);

    return entry ? entry[1] : undefined;
}

// Plasma does not save a value equal to the default, so a new default changes every widget that kept it.
test('a widget is transparent unless another background is chosen, with a fifth of the colour of the theme', () => {
    assert.equal(defaultOf('background'), 'none');
    assert.equal(defaultOf('backgroundTransparency'), '80');
});

// Kirigami's FormLayout puts the rows a Repeater makes straight inside it at the very end of the
// page, whatever their place in the file: the places found by a search showed below everything.
test('no settings page has a Repeater straight inside a FormLayout', () => {
    const pages = readdirSync(new URL('../package/contents/ui/config/', import.meta.url))
        .filter((name) => name.endsWith('.qml'))
        .map((name) => new URL(`../package/contents/ui/config/${name}`, import.meta.url))
        .concat([new URL('../wallpaper/package/contents/ui/config.qml', import.meta.url)]);

    for (const page of pages) {
        const lines = readFileSync(page, 'utf8').split('\n');

        lines.forEach((line, at) => {
            if (line.trim() !== 'Repeater {') {
                return;
            }

            const indent = line.length - line.trimStart().length;
            const parent = lines.slice(0, at).reverse().find((above) => above.trim().endsWith('{') && above.length - above.trimStart().length < indent);

            assert.notEqual(parent.trim(), 'Kirigami.FormLayout {', `${page.pathname.split('/').slice(-2).join('/')}:${at + 1}`);
        });
    }
});
