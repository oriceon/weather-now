import test from 'node:test';
import assert from 'node:assert/strict';
import { STRINGS } from '../package/contents/code/i18n.mjs';
import { PHASE_KEYS, moonPhase } from '../package/contents/code/moon.mjs';

test('moonPhase names the phase on the dates of known new, quarter and full moons', () => {
    const cases = [
        ['2026-08-12', 'moon.new'],
        ['2026-08-20', 'moon.firstQuarter'],
        ['2026-08-28', 'moon.full'],
        ['2026-03-03', 'moon.full'],
        ['2026-09-04', 'moon.lastQuarter'],
        ['2026-10-10', 'moon.new'],
        ['2026-10-26', 'moon.full'],
    ];

    for (const [date, want] of cases) {
        assert.equal(moonPhase(date).key, want, date);
    }
});

test('moonPhase names the phases in between', () => {
    assert.equal(moonPhase('2026-10-14').key, 'moon.waxingCrescent');
    assert.equal(moonPhase('2026-10-22').key, 'moon.waxingGibbous');
    assert.equal(moonPhase('2026-10-30').key, 'moon.waningGibbous');
    assert.equal(moonPhase('2026-11-06').key, 'moon.waningCrescent');
});

test('moonPhase reports how much of the disc is lit', () => {
    assert.ok(moonPhase('2026-08-12').illumination < 0.03, 'new moon');
    assert.ok(moonPhase('2026-08-28').illumination > 0.97, 'full moon');
    assert.ok(Math.abs(moonPhase('2026-08-20').illumination - 0.5) < 0.1, 'first quarter');
});

test('moonPhase reports the position in the cycle, from 0 at new moon to 0.5 at full moon', () => {
    assert.ok(Math.abs(moonPhase('2026-08-28').fraction - 0.5) < 0.03);
    assert.ok(moonPhase('2026-08-20').fraction > 0.2 && moonPhase('2026-08-20').fraction < 0.3);
});

test('every phase has a name in every language', () => {
    assert.equal(PHASE_KEYS.length, 8);

    for (const key of PHASE_KEYS) {
        for (const language of Object.keys(STRINGS)) {
            assert.ok(STRINGS[language][key], `${key} in ${language}`);
        }
    }
});
