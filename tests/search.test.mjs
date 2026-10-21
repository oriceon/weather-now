import test from 'node:test';
import assert from 'node:assert/strict';
import { folded, placesFound, searchPlan, similarWords } from '../package/contents/code/search.mjs';

const place = (name, region, country = 'România') => ({ name, region, country, countryCode: 'RO', latitude: 44, longitude: 28, label: `${name}, ${region}, ${country}` });
const valu = place('Valu lui Traian', 'Constanţa');
const traians = [place('Traian', 'Județul Bacău'), place('Traian', 'Județul Brăila'), place('Traian', 'Județul Tulcea'), place('Traian', 'Județul Olt')];

/**
 * Open-Meteo as it answered on 2026-10-21: a place by the start of its name as written, and with
 * many places asked for, more of them; "Valul" and the name with its county after it find nothing.
 */
function openMeteo(name, count) {
    const answers = {
        'valu lui traian': [valu],
        'valu lui': [valu],
        // Among the Traians, a village of the county, but not Valu lui Traian: that is found by "Valu".
        traian: traians.slice(0, count > 8 ? 4 : 3).concat([place('Traian', 'Constanţa')]),
        valu: count > 20 ? [place('Valu', 'Statul Adamawa', 'Nigeria'), valu] : [place('Valu', 'Statul Adamawa', 'Nigeria')],
        bucharest: [place('București', 'București')],
    };

    return answers[folded(name)] || [];
}

/** What the search shows, asking in turn as PlaceSearch.qml does. */
function search(text) {
    const plan = searchPlan(text);

    for (const query of plan.queries) {
        const found = placesFound(openMeteo(query.name, query.count), query, plan);

        if (found.length > 0) {
            return found;
        }
    }

    return [];
}

test('letters are compared without their diacritics, of either form of ș and ț', () => {
    assert.equal(folded('Constanța'), 'constanta');
    assert.equal(folded('Constanţa'), 'constanta');
    assert.equal(folded('Ştefăneşti'), 'stefanesti');
    assert.equal(folded('Łódź'), 'lodz');
});

test('a word typed is a word of a name when it is the same, its start, or a letter off', () => {
    assert.ok(similarWords('traian', 'traian'));
    assert.ok(similarWords('valul', 'valu'));
    assert.ok(similarWords('const', 'constanta'));
    assert.ok(!similarWords('lu', 'lui'));
    assert.ok(!similarWords('cluj', 'brasov'));
});

test('the place is found as it is written, in any case', () => {
    assert.deepEqual(search('Valu lui Traian'), [valu]);
    assert.deepEqual(search('valu lui traian'), [valu]);
    assert.deepEqual(search('Valu lui traian'), [valu]);
});

test('it is found with its county and country after it, with commas or without', () => {
    assert.deepEqual(search('Valu lui Traian, Constanta, Romania'), [valu]);
    assert.deepEqual(search('Valu lui Traian Constanta'), [valu]);
});

test('it is found with a letter off and without its little words', () => {
    assert.deepEqual(search('Valul lui Traian'), [valu]);
    assert.deepEqual(search('Valu Traian'), [valu]);
});

test('the county after a comma brings its places first', () => {
    assert.equal(search('Traian, Tulcea')[0].region, 'Județul Tulcea');
    assert.equal(search('Traian').length, 4);
});

test('a name in another language, which Open-Meteo knows, is not thrown out', () => {
    assert.equal(search('Bucharest')[0].name, 'București');
});

test('the lookups go from the name as typed to its longer words alone', () => {
    const { queries } = searchPlan('Valul lui Traian');

    assert.deepEqual(queries.map((query) => query.name), ['Valul lui Traian', 'Valul lui', 'Valul', 'Traian', 'Valul', 'Traia', 'Valu']);
    assert.deepEqual(queries.map((query) => query.every), [false, false, false, true, true, true, true]);
});
