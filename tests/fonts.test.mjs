import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const fonts = new URL('../package/contents/fonts/', import.meta.url);
const loader = readFileSync(new URL('../package/contents/ui/WidgetFonts.qml', import.meta.url), 'utf8');

test('every font the widget loads comes with it', () => {
    const sources = [...loader.matchAll(/source: "\.\.\/fonts\/([^"]+)"/g)].map(match => match[1]);

    assert.ok(sources.length > 0);
    sources.forEach(source => assert.ok(existsSync(new URL(source, fonts)), source));
});

// The SIL Open Font License asks for the licence to go along with the fonts.
test('the licence of Inter comes with it', () => {
    assert.match(readFileSync(new URL('Inter-LICENSE.txt', fonts), 'utf8'), /SIL Open Font License, Version 1\.1/);
});
