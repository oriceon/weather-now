import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { METEOALARM_DISCLAIMER, NOWCASTING_ALLOWED, activeAlerts, issuerSite, meteoalarmDisclaimer, alertInterval, alertIssued, alertTitle, alertsOn, distinctAlerts, feedUrl, hasMeteoalarm, inLeadOrder, leadAlert, normalizeRegion, nowcastUrl, parseCap, parseFeed, parseNowcast, parsePublicAlert, parsePublicAlertIds, publicAlertsUrl, worstLevel } from '../package/contents/code/alerts.mjs';

const fixture = (name) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');

const ATOM = fixture('alerts-meteoalarm-romania.xml');
const CAP = fixture('alerts-cap-wind.xml');
const NOWCAST = fixture('alerts-anm-nowcasting.xml');

/** Bucharest in summer time, as Open-Meteo reports it for the fixtures. */
const OFFSET = 10800;
const NOW = '2026-10-13T17:00';

function feed(entries) {
    return `<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom" xmlns:cap="urn:oasis:names:tc:emergency:cap:1.2">${entries.join('')}</feed>`;
}

function entry({ area = 'Cluj', type = 1, level = 2, sent = '2026-10-13T20:30:00+00:00', onset = '2026-10-14T07:00:00+00:00', expires = '2026-10-14T15:00:00+00:00', messageType = 'Alert', status = 'Actual', cap = 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/1' } = {}) {
    return `<entry>
        <cap:areaDesc>${area}</cap:areaDesc>
        <cap:sent>${sent}</cap:sent>
        <cap:event>awareness_type=${type}, awareness_level=${level}</cap:event>
        <cap:expires>${expires}</cap:expires>
        <cap:onset>${onset}</cap:onset>
        <cap:message_type>${messageType}</cap:message_type>
        <cap:status>${status}</cap:status>
        <link type="application/cap+xml" href="${cap}"/>
        <title>Warning issued for Romania - ${area}</title>
    </entry>`;
}

function alert(overrides) {
    return { kind: 'wind', level: 'yellow', onset: '2026-10-13T10:00', expires: '2026-10-14T10:00', ...overrides };
}

test('normalizeRegion makes county names comparable across spellings', () => {
    const cases = [
        ['Constanța', 'constanta'], ['Constanţa', 'constanta'], ['CONSTANTA', 'constanta'], ['Județul Constanța', 'constanta'],
        ['Judeţul Ialomiţa', 'ialomita'], ['Municipiul București', 'bucuresti'], ['Bucureşti', 'bucuresti'],
        ['  Vâlcea ', 'valcea'], ['Dâmbovița', 'dambovita'], ['Bistrița-Năsăud', 'bistrita-nasaud'], [null, ''], [undefined, ''],
        // How the geocoder names them in English.
        ['Constanța County', 'constanta'], ['Bistrița-Năsăud County', 'bistrita-nasaud'], ['Bucharest', 'bucuresti'],
        // In German, French and Spanish, kept from before the search asked for the Romanian name.
        ['Kreis Constanța', 'constanta'], ['Județ de Iași', 'iasi'], ['Condado de Iași', 'iasi'], ['Bukarest', 'bucuresti'], ['Bucarest', 'bucuresti'],
    ];

    for (const [name, want] of cases) {
        assert.equal(normalizeRegion(name), want, String(name));
    }
});

test('warnings are available for Romania only', () => {
    assert.equal(feedUrl('RO'), 'https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-romania');
    assert.equal(feedUrl('ro'), 'https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-romania');
    assert.equal(nowcastUrl('RO'), 'https://www.meteoromania.ro/avertizari-nowcasting-xml.php');
    assert.equal(feedUrl('DE'), '');
    assert.equal(nowcastUrl('DE'), '');
    assert.equal(feedUrl(undefined), '');
});

test('the site of the service that issued a warning, for the link in the footer', () => {
    assert.equal(issuerSite('ANM'), 'https://www.meteoromania.ro/');
    assert.equal(issuerSite('DWD'), '');
    assert.equal(issuerSite(''), '');
});

test('nowcasting stays switched off until ANM gives its written consent', () => {
    // The terms of meteoromania.ro forbid taking its warnings without it; the code waits behind this switch.
    assert.equal(NOWCASTING_ALLOWED, false);
});

test('parseFeed keeps the warnings of the county, in the local time of the forecast', () => {
    const alerts = parseFeed(ATOM, 'Constanţa', OFFSET);

    assert.deepEqual(alerts.map(({ source, issuer, kind, level, issued, onset, expires, capUrl }) => ({ source, issuer, kind, level, issued, onset, expires, capUrl })), [
        {
            source: 'meteoalarm',
            issuer: 'ANM',
            kind: 'wind',
            level: 'yellow',
            issued: '2026-10-13T10:01',
            onset: '2026-10-13T10:00',
            expires: '2026-10-14T10:00',
            capUrl: 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/e26814e8-1689-447a-88eb-5860a8fd2ba6',
        },
        {
            source: 'meteoalarm',
            issuer: 'ANM',
            kind: 'wind',
            level: 'yellow',
            issued: '2026-10-13T10:01',
            onset: '2026-10-14T10:00',
            expires: '2026-10-14T18:00',
            capUrl: 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/36933e02-8245-4ea3-8b74-ae381f5e549a',
        },
    ]);
    assert.notEqual(alerts[0].id, alerts[1].id);
});

test('parseFeed finds the county however it is spelled in the settings', () => {
    for (const region of ['Constanta', 'constanța', 'Județul Constanța', 'Constanța County']) {
        assert.equal(parseFeed(ATOM, region, OFFSET).length, 2, region);
    }
});

test('parseFeed returns nothing for a county without warnings, or without a county', () => {
    assert.deepEqual(parseFeed(ATOM, 'Cluj', OFFSET), []);
    assert.deepEqual(parseFeed(ATOM, '', OFFSET), []);
    assert.deepEqual(parseFeed('', 'Cluj', OFFSET), []);
});

test('parseFeed reads the kind of phenomenon and the colour code', () => {
    const kinds = [[1, 'wind'], [2, 'snow'], [3, 'thunderstorm'], [4, 'fog'], [5, 'heat'], [6, 'cold'], [7, 'coastal'], [8, 'fire'], [9, 'avalanche'], [10, 'rain'], [12, 'flood'], [13, 'rainFlood'], [99, 'other']];

    for (const [type, want] of kinds) {
        assert.equal(parseFeed(feed([entry({ type })]), 'Cluj', 0)[0].kind, want, `type ${type}`);
    }

    for (const [level, want] of [[2, 'yellow'], [3, 'orange'], [4, 'red']]) {
        assert.equal(parseFeed(feed([entry({ level })]), 'Cluj', 0)[0].level, want, `level ${level}`);
    }
});

test('parseFeed names no issuer for a feed that does not say its country', () => {
    assert.equal(parseFeed(feed([entry()]), 'Cluj', 0)[0].issuer, '');
});

test('parseFeed skips entries that warn of nothing', () => {
    const entries = [entry({ level: 1 }), entry({ messageType: 'Cancel' }), entry({ status: 'Test' }), entry({ area: 'Sibiu' })];

    assert.deepEqual(parseFeed(feed(entries), 'Cluj', 0), []);
});

test('parseFeed lists a warning once even when the feed repeats it', () => {
    assert.equal(parseFeed(feed([entry(), entry()]), 'Cluj', 0).length, 1);
});

test('parseFeed keeps only the newest of the warnings that say the same for the same hours', () => {
    const older = entry({ sent: '2026-10-13T07:01:17+00:00', cap: 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/older' });
    const newer = entry({ sent: '2026-10-14T07:32:08+00:00', cap: 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/newer' });

    for (const entries of [[older, newer], [newer, older]]) {
        const alerts = parseFeed(feed(entries), 'Cluj', 10800);

        assert.deepEqual(alerts.map(({ capUrl, issued }) => ({ capUrl, issued })), [{ capUrl: 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/newer', issued: '2026-10-14T10:32' }]);
    }

    assert.equal(parseFeed(feed([older, entry({ level: 3, cap: 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/orange' })]), 'Cluj', 0).length, 2);
});

// The texts are fetched from the address the feed gives: only MeteoAlarm's own is asked.
test('parseFeed keeps only the CAP documents of MeteoAlarm', () => {
    const [elsewhere] = parseFeed(feed([entry({ cap: 'http://192.168.1.1/admin?reboot=1' })]), 'Cluj', 0);
    const [plain] = parseFeed(feed([entry({ cap: 'http://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/1' })]), 'Cluj', 0);

    assert.equal(elsewhere.capUrl, '');
    assert.equal(plain.capUrl, '');
});

test('parseFeed orders the warnings by when they start', () => {
    const entries = [
        entry({ onset: '2026-10-15T07:00:00+00:00', expires: '2026-10-15T15:00:00+00:00', cap: 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/later' }),
        entry({ onset: '2026-10-14T07:00:00+00:00', cap: 'https://feeds.meteoalarm.org/api/v1/warnings/feeds-romania/sooner' }),
    ];

    assert.deepEqual(parseFeed(feed(entries), 'Cluj', 0).map((item) => item.onset), ['2026-10-14T07:00', '2026-10-15T07:00']);
});

test('parseFeed converts times written with any UTC offset', () => {
    const [item] = parseFeed(feed([entry({ onset: '2026-10-14T10:00:00+03:00', expires: '2026-10-14T23:30:00+03:00' })]), 'Cluj', 7200);

    assert.equal(item.onset, '2026-10-14T09:00');
    assert.equal(item.expires, '2026-10-14T22:30');
});

test('parseCap reads the text of the warning in the requested language', () => {
    assert.deepEqual(parseCap(CAP, 'ro'), {
        headline: 'Intensificări ale vântului cu viteze de 50...70 km/h.',
        description: 'Intensificări ale vântului cu viteze de 50...70 km/h.',
    });
    assert.equal(parseCap(CAP, 'en').description, 'Wind gusts of 50...70 km/h.');
});

test('parseCap falls back to the first language of the warning', () => {
    assert.equal(parseCap(CAP, 'de').description, 'Intensificări ale vântului cu viteze de 50...70 km/h.');
    assert.deepEqual(parseCap('', 'ro'), { headline: '', description: '' });
});

test('parseCap decodes XML entities', () => {
    const cap = '<alert><info><language>ro-RO</language><headline>Ploi &amp; v&#226;nt</headline><description>Rafale &lt;90 km/h&gt; &#x21B;</description></info></alert>';

    assert.deepEqual(parseCap(cap, 'ro'), { headline: 'Ploi & vânt', description: 'Rafale <90 km/h> ț' });
});

test('parseNowcast keeps the immediate warnings whose zone names the locality', () => {
    const alerts = parseNowcast(NOWCAST, 'Ialomiţa', 'Slobozia');

    assert.equal(alerts.length, 1);
    assert.deepEqual({ ...alerts[0], id: undefined }, {
        id: undefined,
        source: 'anm',
        issuer: 'ANM',
        kind: 'nowcast',
        level: 'yellow',
        issued: '2026-10-13T15:54',
        onset: '2026-10-13T16:00',
        expires: '2026-10-13T18:00',
        capUrl: '',
        headline: '',
        description: 'Local intensificări ale vântului cu viteze la rafală de 50...70 km/h.',
    });
});

test('parseNowcast leaves out the warnings that name only other localities', () => {
    assert.deepEqual(parseNowcast(NOWCAST, 'Ialomița', 'Urziceni'), []);
    assert.deepEqual(parseNowcast(NOWCAST, 'Brăila', 'Slobozia'), []);
    assert.equal(parseNowcast(NOWCAST, 'Ialomița', 'slobozia').length, 1);
    assert.equal(parseNowcast(NOWCAST, 'Călărași', 'Ștefan cel Mare').length, 1);
});

test('parseNowcast returns nothing for a county that is not named', () => {
    assert.deepEqual(parseNowcast(NOWCAST, 'Constanța', 'Constanța'), []);
    assert.deepEqual(parseNowcast('<avertizariNowcasting/>', 'Ialomița', 'Slobozia'), []);
    assert.deepEqual(parseNowcast('', 'Ialomița', 'Slobozia'), []);
});

test('parseNowcast reads the colour code', () => {
    const nowcast = (colour) => `<avertizariNowcasting><avertizare dataInceput="2026-10-13T16:00" dataSfarsit="2026-10-13T18:00" zona="Jude&#x21B;ul Cluj: Turda;&lt;br&gt;" semnalare="Grindin&#x103;." numeCuloare="${colour}"/></avertizariNowcasting>`;

    for (const [colour, want] of [['galben', 'yellow'], ['portocaliu', 'orange'], ['ro&#x219;u', 'red'], ['rosu', 'red']]) {
        assert.equal(parseNowcast(nowcast(colour), 'Cluj', 'Turda')[0].level, want, colour);
    }

    assert.equal(parseNowcast(nowcast('galben'), 'Cluj', 'Turda')[0].description, 'Grindină.');
});

test('activeAlerts drops the warnings that have expired', () => {
    const alerts = [alert({ expires: '2026-10-13T16:59' }), alert({ expires: '2026-10-13T17:00' }), alert({ expires: '2026-10-13T17:01' }), alert({ onset: '2026-10-15T10:00', expires: '2026-10-15T18:00' })];

    assert.deepEqual(activeAlerts(alerts, NOW).map((item) => item.expires), ['2026-10-13T17:01', '2026-10-15T18:00']);
});

test('alertsOn finds the warnings that touch a day', () => {
    const alerts = [alert()];

    assert.equal(alertsOn(alerts, '2026-10-12').length, 0);
    assert.equal(alertsOn(alerts, '2026-10-13').length, 1);
    assert.equal(alertsOn(alerts, '2026-10-14').length, 1);
    assert.equal(alertsOn(alerts, '2026-10-15').length, 0);
});

test('a warning that ends at midnight does not touch the day that begins then', () => {
    assert.equal(alertsOn([alert({ expires: '2026-10-14T00:00' })], '2026-10-14').length, 0);
    assert.equal(alertsOn([alert({ expires: '2026-10-14T00:00' })], '2026-10-13').length, 1);
});

test('worstLevel is the most severe colour among the warnings', () => {
    assert.equal(worstLevel([]), null);
    assert.equal(worstLevel([alert()]), 'yellow');
    assert.equal(worstLevel([alert(), alert({ level: 'red' }), alert({ level: 'orange' })]), 'red');
    assert.equal(worstLevel([alert(), alert({ level: 'orange' })]), 'orange');
});

test('alertTitle names the colour code and the phenomenon', () => {
    assert.equal(alertTitle(alert(), 'ro'), 'Cod galben · vânt');
    assert.equal(alertTitle(alert(), 'en'), 'Yellow warning · wind');
    assert.equal(alertTitle(alert({ level: 'orange', kind: 'rain' }), 'ro'), 'Cod portocaliu · ploi');
    assert.equal(alertTitle(alert({ level: 'red', kind: 'nowcast' }), 'ro'), 'Cod roșu · nowcasting');
});

test('alertInterval says until when a warning in force lasts', () => {
    assert.equal(alertInterval(alert({ expires: '2026-10-13T18:00' }), NOW, 'ro'), 'până la 18:00');
    assert.equal(alertInterval(alert({ expires: '2026-10-14T10:00' }), NOW, 'ro'), 'până mâine la 10:00');
    assert.equal(alertInterval(alert({ expires: '2026-10-15T06:00' }), NOW, 'ro'), 'până joi la 06:00');
    assert.equal(alertInterval(alert({ expires: '2026-10-13T18:00' }), NOW, 'en'), 'until 18:00');
    assert.equal(alertInterval(alert({ expires: '2026-10-14T10:00' }), NOW, 'en'), 'until tomorrow 10:00');
    assert.equal(alertInterval(alert({ expires: '2026-10-15T06:00' }), NOW, 'en'), 'until Thursday 06:00');
});

test('alertInterval gives the interval of a warning that has not started', () => {
    assert.equal(alertInterval(alert({ onset: '2026-10-13T20:00', expires: '2026-10-13T23:00' }), NOW, 'ro'), 'azi, 20:00 – 23:00');
    assert.equal(alertInterval(alert({ onset: '2026-10-14T10:00', expires: '2026-10-14T18:00' }), NOW, 'ro'), 'mâine, 10:00 – 18:00');
    assert.equal(alertInterval(alert({ onset: '2026-10-14T10:00', expires: '2026-10-15T06:00' }), NOW, 'ro'), 'mâine 10:00 – joi 06:00');
    assert.equal(alertInterval(alert({ onset: '2026-10-15T10:00', expires: '2026-10-16T06:00' }), NOW, 'ro'), 'joi 10:00 – vineri 06:00');
    assert.equal(alertInterval(alert({ onset: '2026-10-14T10:00', expires: '2026-10-14T18:00' }), NOW, 'en'), 'tomorrow, 10:00 – 18:00');
    assert.equal(alertInterval(alert({ onset: '2026-10-15T10:00', expires: '2026-10-16T06:00' }), NOW, 'en'), 'Thursday 10:00 – Friday 06:00');
});

test('leadAlert is the warning to show when there is room for one only', () => {
    const inForce = alert({ onset: '2026-10-13T10:00', expires: '2026-10-14T10:00' });
    const later = alert({ level: 'red', onset: '2026-10-14T10:00', expires: '2026-10-14T18:00' });

    assert.equal(leadAlert([], NOW), null);
    assert.equal(leadAlert([later], NOW), later);
    assert.equal(leadAlert([later, inForce], NOW), inForce, 'one in force comes before one to come, however severe');
});

test('leadAlert prefers the more severe of the warnings in force, then the one that started first', () => {
    const yellow = alert({ onset: '2026-10-13T08:00' });
    const orange = alert({ level: 'orange', onset: '2026-10-13T12:00' });
    const alsoOrange = alert({ level: 'orange', onset: '2026-10-13T15:00' });

    const red = alert({ level: 'red', onset: '2026-10-13T16:00' });

    assert.equal(leadAlert([yellow, orange, alsoOrange], NOW), orange);
    assert.equal(leadAlert([alsoOrange, yellow, orange], NOW), orange);
    assert.equal(leadAlert([orange, red, yellow], NOW), red);
    assert.equal(leadAlert([red, orange], NOW), red);
});

// Where only the first few have room, as on the Days tab and in the tooltip, a red one must not be left out.
test('the warnings are listed in force first, then the most severe, then the earliest', () => {
    const later = alert({ id: 'later', level: 'red', onset: '2026-10-14T06:00' });
    const yellow = alert({ id: 'yellow', level: 'yellow', onset: '2026-10-13T08:00' });
    const red = alert({ id: 'red', level: 'red', onset: '2026-10-13T12:00' });

    assert.deepEqual(inLeadOrder([later, yellow, red], NOW).map((warning) => warning.id), ['red', 'yellow', 'later']);
});

test('alertIssued says when the warning was issued', () => {
    assert.equal(alertIssued(alert({ issued: '2026-10-13T10:01' }), NOW, 'ro'), 'emisă azi, 10:01');
    assert.equal(alertIssued(alert({ issued: '2026-10-13T10:01' }), NOW, 'en'), 'issued today, 10:01');
    assert.equal(alertIssued(alert({ issued: '2026-10-12T22:00' }), NOW, 'ro'), 'emisă luni, 22:00');
    assert.equal(alertIssued(alert({ issued: '2026-10-12T22:00' }), NOW, 'en'), 'issued Monday, 22:00');
});

test('alertIssued says nothing when the issue time is not known', () => {
    assert.equal(alertIssued(alert({ issued: '' }), NOW, 'ro'), '');
    assert.equal(alertIssued(alert({}), NOW, 'en'), '');
});

test('the MeteoAlarm disclaimer comes in the language of the widget', () => {
    assert.equal(meteoalarmDisclaimer('en'), METEOALARM_DISCLAIMER);
    assert.equal(meteoalarmDisclaimer('ro'), 'Între datele de aici și site-ul www.meteoalarm.org pot exista întârzieri. Pentru cele mai noi informații de avertizare, așa cum le publică serviciile naționale de meteorologie și hidrologie participante, consultă www.meteoalarm.org.');
});

test('the MeteoAlarm disclaimer is the wording its terms require, word for word', () => {
    assert.equal(METEOALARM_DISCLAIMER, 'Time delays between this website and the www.meteoalarm.org website are possible. For the most up-to-date awareness information as published by the participating National Meteorological and Hydrological Services, please refer to www.meteoalarm.org.');
});

const publicFixture = (name) => readFileSync(new URL(`./fixtures/alerts-public-${name}`, import.meta.url), 'utf8');

test('outside the countries of MeteoAlarm, the warnings come from the public alert server', () => {
    assert.equal(hasMeteoalarm('RO'), true);
    assert.equal(hasMeteoalarm('NL'), false);
});

test('the public alert server is asked about some five kilometres around the place, rounded', () => {
    assert.equal(publicAlertsUrl(52.37403, 4.88969), 'https://alerts.kde.org/alert/area?min_lat=52.32&max_lat=52.42&min_lon=4.84&max_lon=4.94');
});

test('the ids of an area are read, the first ten at most', () => {
    assert.deepEqual(parsePublicAlertIds(JSON.parse(publicFixture('area.json'))).length, 5);
    assert.deepEqual(parsePublicAlertIds(Array.from({ length: 30 }, (_, index) => `id-${index}`)).length, 10);
    assert.deepEqual(parsePublicAlertIds({ error: 'no' }), []);
});

test('a weather warning of the public alert server is read in the language of the widget, else in English', () => {
    const alert = parsePublicAlert(publicFixture('knmi.xml'), 'ro', 7200);

    assert.equal(alert.source, 'public');
    assert.equal(alert.issuer, 'KNMI Royal Netherlands Meteorological Institute');
    assert.equal(alert.event, 'Moderate Wind');
    assert.equal(alert.level, 'yellow');
    assert.equal(alert.onset, '2026-10-19T11:40');
    assert.equal(alert.expires, '2026-10-22T05:18');
    assert.match(alert.headline, /^From Monday 19 October onwards/);
});

test('the first level of a national service shows as yellow, in the language asked for', () => {
    const alert = parsePublicAlert(publicFixture('dwd.xml'), 'de', 7200);

    assert.equal(alert.issuer, 'Deutscher Wetterdienst');
    assert.equal(alert.level, 'yellow');
    assert.equal(alert.event, 'LEICHTER SCHNEEFALL');
});

// Whoever runs a feed writes its links: one to a file or to another program must not open from a click.
test('the link of a warning leads to a website, or to nothing', () => {
    const knmi = publicFixture('knmi.xml');
    const withWeb = (web) => parsePublicAlert(knmi.replaceAll(/<web>[^<]*<\/web>/g, `<web>${web}</web>`), 'en', 7200).web;

    assert.match(parsePublicAlert(knmi, 'en', 7200).web, /^https:\/\/www\.knmi\.nl\//);
    assert.equal(withWeb('www.boebrach.de'), 'https://www.boebrach.de');
    assert.equal(withWeb('smb://somewhere/share'), '');
    assert.equal(withWeb('file:///home/someone/start.desktop'), '');
});

test('a warning that says nothing of when it holds is left out, without an error', () => {
    const knmi = publicFixture('knmi.xml').replaceAll(/<(sent|onset|effective|expires)>[^<]*<\/\1>/g, '');

    assert.equal(parsePublicAlert(knmi, 'en', 7200), null);
});

test('a severity named like a property of every object is no severity', () => {
    const knmi = publicFixture('knmi.xml').replaceAll(/<severity>[^<]*<\/severity>/g, '<severity>constructor</severity>');

    assert.equal(parsePublicAlert(knmi, 'en', 7200), null);
});

// Parsed where the desktop runs: a long document left open must not hold it up.
test('a long document with its elements left open is read at once', () => {
    const started = Date.now();

    assert.equal(parsePublicAlert('<alert>' + '<info>'.repeat(200000), 'en', 0), null);
    assert.deepEqual(parseFeed(`<feed>${'<entry><link '.repeat(100000)}`, 'Cluj', 0), []);
    assert.ok(Date.now() - started < 1000, `took ${Date.now() - started} ms`);
});

// A weather widget passes on the weather; the server also carries health and fire notices.
test('a warning that is not about the weather is left out', () => {
    assert.equal(parsePublicAlert(publicFixture('health.xml'), 'en', 7200), null);
});

test('a warning of the public alert server is named by its own event', () => {
    assert.equal(alertTitle({ level: 'yellow', event: 'LEICHTER SCHNEEFALL' }, 'ro'), 'Cod galben · Leichter schneefall');
    assert.equal(alertTitle({ level: 'yellow', event: 'Leichter Schneefall' }, 'ro'), 'Cod galben · Leichter Schneefall');
    assert.equal(alertTitle({ level: 'orange', event: 'storm surge' }, 'en'), 'Orange warning · Storm surge');
});

test('the same warning for several regions shows once', () => {
    const warning = { issuer: 'MeteoSwiss', event: 'Strong rainfall', level: 'yellow', onset: '2026-10-21T12:00', expires: '2026-10-22T00:00' };

    assert.equal(distinctAlerts([warning, Object.assign({}, warning, { id: 'other region' })]).length, 1);
});

test('a warning published again in a language the widget does not speak gives way', () => {
    const english = { issuer: 'web@mecom.ru', event: 'Snow', level: 'yellow', onset: '2026-10-21T09:00', expires: '2026-10-21T21:00', languageRank: 1 };
    const russian = Object.assign({}, english, { event: 'Снег', languageRank: 2 });

    assert.deepEqual(distinctAlerts([russian, english]).map((warning) => warning.event), ['Snow']);
    assert.equal(distinctAlerts([russian]).length, 1);
});

test('a warning with no twin in a language the widget speaks stays, untranslated', () => {
    const english = { id: 'snow-en', issuer: 'web@mecom.ru', event: 'Snow', level: 'yellow', onset: '2026-10-21T09:00', expires: '2026-10-21T21:00', languageRank: 1 };
    const snow = Object.assign({}, english, { id: 'snow-ru', event: 'Снег', languageRank: 2 });
    const wind = Object.assign({}, english, { id: 'wind-ru', event: 'Ветер', languageRank: 2 });

    assert.deepEqual(distinctAlerts([snow, wind, english]).map((warning) => warning.id).sort(), ['snow-en', 'snow-ru', 'wind-ru']);
});

test('the warning kept stands for the copies left out', () => {
    const english = { id: 'snow-en', issuer: 'web@mecom.ru', event: 'Snow', level: 'yellow', onset: '2026-10-21T09:00', expires: '2026-10-21T21:00', languageRank: 1 };
    const russian = Object.assign({}, english, { id: 'snow-ru', event: 'Снег', languageRank: 2 });
    const region = Object.assign({}, english, { id: 'snow-en-2' });

    assert.deepEqual(distinctAlerts([russian, english, region]).map((warning) => [warning.id, warning.sameAs]), [['snow-en', ['snow-en-2', 'snow-ru']]]);
});
