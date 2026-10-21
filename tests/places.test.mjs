import test from 'node:test';
import assert from 'node:assert/strict';
import { addPlace, neighbourPlace, parsePlaces, placeRing, removePlace, samePlace, serializePlaces, switchPlaces } from '../package/contents/code/places.mjs';

const constanta = { name: 'Constanța', latitude: 44.18073, longitude: 28.63432, region: 'Constanța', countryCode: 'RO' };
const cluj = { name: 'Cluj-Napoca', latitude: 46.76667, longitude: 23.6, region: 'Cluj', countryCode: 'RO' };
const rome = { name: 'Rome', latitude: 41.89193, longitude: 12.51133, region: 'Lazio', countryCode: 'IT' };

test('the kept places go to the settings as JSON and come back the same', () => {
    assert.deepEqual(parsePlaces(serializePlaces([cluj, rome])), [cluj, rome]);
});

// A setting edited by hand should not take the other places with it.
test('a kept place that cannot be read is skipped', () => {
    assert.deepEqual(parsePlaces(['{broken', JSON.stringify(rome), '{"name": 3}']), [rome]);
    assert.deepEqual(parsePlaces(undefined), []);
});

test('a place is the same place by its name and its position to about a kilometre', () => {
    assert.equal(samePlace(cluj, Object.assign({}, cluj, { latitude: 46.7701 })), true);
    assert.equal(samePlace(cluj, Object.assign({}, cluj, { latitude: 46.9 })), false);
});

test('a place is added once, and not when it is the one on show', () => {
    assert.deepEqual(addPlace([cluj], rome, constanta), [cluj, rome]);
    assert.deepEqual(addPlace([cluj], cluj, constanta), [cluj]);
    assert.deepEqual(addPlace([cluj], constanta, constanta), [cluj]);
});

test('a place is removed from the kept ones', () => {
    assert.deepEqual(removePlace([cluj, rome], cluj), [rome]);
});

test('switching puts the place that was on show where the chosen one was', () => {
    assert.deepEqual(switchPlaces([cluj, rome], cluj, constanta), [constanta, rome]);
    assert.deepEqual(switchPlaces([constanta, rome], constanta, cluj), [cluj, rome]);
});

test('the place on show and the kept ones go round a ring, by name', () => {
    const iasi = { name: 'Iași', latitude: 47.16, longitude: 27.58 };
    const cluj = { name: 'Cluj-Napoca', latitude: 46.77, longitude: 23.6 };
    const constanta = { name: 'Constanța', latitude: 44.18, longitude: 28.63 };

    assert.deepEqual(placeRing(constanta, [iasi, cluj]).map((place) => place.name), ['Cluj-Napoca', 'Constanța', 'Iași']);
    assert.equal(neighbourPlace(constanta, [iasi, cluj], 1).name, 'Iași');
    assert.equal(neighbourPlace(constanta, [iasi, cluj], -1).name, 'Cluj-Napoca');
    assert.equal(neighbourPlace(iasi, [constanta, cluj], 1).name, 'Cluj-Napoca');
    assert.equal(neighbourPlace(constanta, [], 1), null);
});
