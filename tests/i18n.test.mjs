import test from 'node:test';
import assert from 'node:assert/strict';
import { STRINGS, compass, dayLong, dayShort, monthLong, monthShort, resolveLanguage, t } from '../package/contents/code/i18n.mjs';

test('an explicit language setting wins over the language of the system', () => {
    assert.equal(resolveLanguage('ro', ['en-US', 'en']), 'ro');
    assert.equal(resolveLanguage('en', ['ro-RO', 'ro']), 'en');
});

test('auto follows the language of the interface, not the regional formats', () => {
    // The setup of the user: Plasma in American English, dates and numbers in Romanian.
    assert.equal(resolveLanguage('auto', ['en-US', 'en']), 'en');
    assert.equal(resolveLanguage('auto', ['ro-RO', 'ro']), 'ro');
    assert.equal(resolveLanguage('auto', ['ro_RO']), 'ro');
});

test('auto takes the first language of the interface the widget has', () => {
    assert.equal(resolveLanguage('auto', ['sv-SE', 'sv', 'ro-RO']), 'ro');
    assert.equal(resolveLanguage('auto', ['de-DE', 'de', 'ro-RO']), 'de');
    assert.equal(resolveLanguage('auto', ['pl_PL']), 'pl');
});

test('auto falls back to English when the interface is in a language the widget does not have', () => {
    assert.equal(resolveLanguage('auto', ['sv-SE', 'fi']), 'en');
    assert.equal(resolveLanguage('auto', []), 'en');
    assert.equal(resolveLanguage('auto', undefined), 'en');
});

test('an unsupported setting behaves like auto', () => {
    assert.equal(resolveLanguage('', ['ro-RO']), 'ro');
    assert.equal(resolveLanguage('sv', ['en-US']), 'en');
});

test('no text names a national weather service: the name depends on the country', () => {
    // The service that issued a warning comes with the warning itself (`issuer` in alerts.mjs).
    for (const language of Object.keys(STRINGS)) {
        for (const [key, text] of Object.entries(STRINGS[language])) {
            assert.doesNotMatch(text, /\bANM\b/, `${language}.${key}`);
        }
    }
});

test('the source of a warning names the service that issued it', () => {
    assert.equal(t('ro', 'alert.source.meteoalarm', { issuer: 'DWD' }), 'Sursă: DWD, prin MeteoAlarm');
    assert.equal(t('en', 'alert.source.anm', { issuer: 'ANM' }), 'Source: ANM');
});

test('t returns the text in the requested language', () => {
    assert.equal(t('ro', 'tab.today'), 'Azi');
    assert.equal(t('en', 'tab.today'), 'Today');
});

test('t substitutes named parameters', () => {
    assert.equal(t('ro', 'today.feelsLike', { temp: '11°' }), 'Se simte ca 11°');
});

test('t returns the key itself when the key does not exist', () => {
    assert.equal(t('ro', 'nope.missing'), 'nope.missing');
});

test('t falls back to English for an unsupported language', () => {
    assert.equal(t('sv', 'tab.today'), 'Today');
});

test('every language defines exactly the keys of English', () => {
    assert.deepEqual(Object.keys(STRINGS).sort(), ['de', 'en', 'es', 'fr', 'it', 'pl', 'ro']);

    for (const language of Object.keys(STRINGS)) {
        assert.deepEqual(Object.keys(STRINGS[language]).sort(), Object.keys(STRINGS.en).sort(), language);
    }
});

test('every text keeps the placeholders of the English one', () => {
    const placeholders = (text) => (text.match(/\{\w+\}/g) || []).sort();

    for (const language of Object.keys(STRINGS)) {
        for (const [key, text] of Object.entries(STRINGS[language])) {
            // The disclaimer of MeteoAlarm is empty in English: its original wording is used.
            if (key !== 'alert.disclaimer') {
                assert.deepEqual(placeholders(text), placeholders(STRINGS.en[key]), `${language}.${key}`);
            }
        }
    }
});

test('every language has its names of days, months and directions', () => {
    for (const language of Object.keys(STRINGS)) {
        for (let day = 0; day < 7; day++) {
            assert.ok(dayShort(language, day) && dayLong(language, day), `${language} day ${day}`);
        }

        for (let month = 1; month <= 12; month++) {
            assert.ok(monthLong(language, month) && monthShort(language, month), `${language} month ${month}`);
        }

        assert.equal(compass(0, language), 'N', language);
    }
});

test('weekday names are indexed like Date#getDay, Sunday first', () => {
    assert.equal(dayShort('ro', 0), 'Dum');
    assert.equal(dayShort('ro', 1), 'Lun');
    assert.equal(dayShort('ro', 6), 'Sâm');
    assert.equal(dayShort('en', 2), 'Tue');
    assert.equal(dayLong('ro', 2), 'marți');
    assert.equal(dayLong('en', 2), 'Tuesday');
});

test('month names are indexed from 1', () => {
    assert.equal(monthLong('ro', 10), 'octombrie');
    assert.equal(monthLong('en', 1), 'January');
    assert.equal(monthShort('ro', 11), 'nov.');
    assert.equal(monthShort('ro', 5), 'mai');
    assert.equal(monthShort('en', 11), 'Nov');
});

test('compass turns degrees into an 8-point direction in the requested language', () => {
    const cases = [
        [0, 'ro', 'N'], [356, 'ro', 'N'], [360, 'ro', 'N'], [22.4, 'ro', 'N'], [22.6, 'ro', 'NE'],
        [90, 'ro', 'E'], [225, 'ro', 'SV'], [270, 'ro', 'V'], [315, 'ro', 'NV'],
        [225, 'en', 'SW'], [270, 'en', 'W'], [315, 'en', 'NW'],
    ];

    for (const [degrees, language, want] of cases) {
        assert.equal(compass(degrees, language), want, `${degrees}° in ${language}`);
    }
});
