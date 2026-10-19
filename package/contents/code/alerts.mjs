import { dateOf, dayWord, timeLabel } from './dates.mjs';
import { t } from './i18n.mjs';

/**
 * Official weather warnings. In Romania they are issued by ANM and reach the widget two ways:
 * the general ones, per county, through the MeteoAlarm feed ANM publishes them to, and the
 * immediate ("nowcasting") ones straight from ANM, which names the localities concerned. Of these,
 * the widget keeps only the ones that name its own locality.
 */

/** Country code => name of the country in the address of its MeteoAlarm feed. */
const METEOALARM_FEEDS = { RO: 'romania' };
/**
 * Country code => the weather service that issues its warnings. The MeteoAlarm terms
 * require its name to be shown with warnings that concern a single country.
 */
const ISSUERS = { RO: 'ANM' };

/** The MeteoAlarm terms require every redistributor to publish this, word for word. */
export const METEOALARM_DISCLAIMER = 'Time delays between this website and the www.meteoalarm.org website are possible. For the most up-to-date awareness information as published by the participating National Meteorological and Hydrological Services, please refer to www.meteoalarm.org.';

const NOWCAST_FEEDS = { RO: 'https://www.meteoromania.ro/avertizari-nowcasting-xml.php' };
/**
 * Whether nowcasting may be used at all. The terms of meteoromania.ro forbid taking its warnings
 * without the written consent of ANM, so it stays off, whatever the settings hold, until that comes.
 */
export const NOWCASTING_ALLOWED = false;

/** MeteoAlarm awareness types and levels. Level 1 is green: nothing to warn of. */
const KINDS = { 1: 'wind', 2: 'snow', 3: 'thunderstorm', 4: 'fog', 5: 'heat', 6: 'cold', 7: 'coastal', 8: 'fire', 9: 'avalanche', 10: 'rain', 12: 'flood', 13: 'rainFlood' };
const LEVELS = { 2: 'yellow', 3: 'orange', 4: 'red' };
const NOWCAST_LEVELS = { galben: 'yellow', portocaliu: 'orange', rosu: 'red' };
/** From the least to the most severe. */
const SEVERITY = ['yellow', 'orange', 'red'];

const DIACRITICS = { ă: 'a', â: 'a', î: 'i', ș: 's', ş: 's', ț: 't', ţ: 't' };
const ENTITIES = { lt: '<', gt: '>', quot: '"', apos: "'", amp: '&' };

function plain(text) {
    return String(text || '')
        .toLowerCase()
        .replace(/[ăâîșşțţ]/g, (letter) => DIACRITICS[letter])
        .trim();
}

function decode(text) {
    return text
        .replace(/&#x([0-9a-f]+);/gi, (entity, hex) => String.fromCharCode(parseInt(hex, 16)))
        .replace(/&#(\d+);/g, (entity, decimal) => String.fromCharCode(Number(decimal)))
        .replace(/&(lt|gt|quot|apos|amp);/g, (entity, name) => ENTITIES[name]);
}

/** The feeds are machine-written and flat, so their elements are read as text rather than through a DOM. */
function elements(xml, name) {
    const pattern = new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, 'g');
    const found = [];
    let match;

    while ((match = pattern.exec(xml)) !== null) {
        found.push(match[1]);
    }

    return found;
}

function element(xml, name) {
    const [first] = elements(xml, name);

    return first === undefined ? '' : decode(first.trim());
}

function attribute(tag, name) {
    const match = new RegExp(`\\s${name}="([^"]*)"`).exec(tag);

    return match ? decode(match[1]) : '';
}

/** "2026-10-14T07:00:00+00:00" as the wall-clock time of the forecast location, "2026-10-14T10:00". */
function toLocalTime(text, utcOffsetSeconds) {
    const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2})?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/.exec(text.trim());

    if (!match) {
        return '';
    }

    const [, year, month, day, hours, minutes, zone] = match;
    let utc = Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hours), Number(minutes));

    if (zone && zone !== 'Z') {
        const digits = zone.replace(/\D/g, '');
        const zoneMinutes = Number(digits.slice(0, 2)) * 60 + Number(digits.slice(2, 4));

        utc -= (zone[0] === '-' ? -zoneMinutes : zoneMinutes) * 60 * 1000;
    }

    return new Date(utc + utcOffsetSeconds * 1000).toISOString().slice(0, 16);
}

function byOnset(first, second) {
    if (first.onset === second.onset) {
        return 0;
    }

    return first.onset < second.onset ? -1 : 1;
}

/**
 * The disclaimer in the language of the widget. The original wording is published anyway, in the
 * tooltip of every MeteoAlarm warning and in the description of the widget in the store.
 */
export function meteoalarmDisclaimer(language) {
    return t(language, 'alert.disclaimer') || METEOALARM_DISCLAIMER;
}

/**
 * A county name without diacritics, case, "Județul" or "County", so that the spellings of different
 * sources compare equal. The geocoder names counties in the language of the widget: "Județul
 * Constanța" in Romanian, "Constanța County" in English, while the warnings always use Romanian.
 */
export function normalizeRegion(name) {
    const county = plain(name).replace(/^(judetul|municipiul)\s+/, '').replace(/\s+county$/, '');

    return county === 'bucharest' ? 'bucuresti' : county;
}

export function feedUrl(countryCode) {
    const country = METEOALARM_FEEDS[String(countryCode || '').toUpperCase()];

    return country ? `https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-${country}` : '';
}

export function nowcastUrl(countryCode) {
    return NOWCAST_FEEDS[String(countryCode || '').toUpperCase()] || '';
}

/**
 * The warnings of a county from a MeteoAlarm Atom feed, soonest first, with times at the
 * forecast location. The text of a warning is not in the feed: see `capUrl` and parseCap().
 */
export function parseFeed(xml, region, utcOffsetSeconds) {
    const wanted = normalizeRegion(region);
    // ANM issues a new warning instead of updating the old one, and the feed keeps both until
    // they expire. Of those saying the same thing for the same hours, only the newest is kept.
    const newest = {};
    // "tag:meteoalarm.org,2021-02-19:RO": the feed says which country it covers.
    const country = /<id>tag:meteoalarm\.org,[^:<]*:([A-Z]{2})<\/id>/.exec(String(xml || ''));

    if (!wanted) {
        return [];
    }

    for (const entry of elements(String(xml || ''), 'entry')) {
        const event = /awareness_type=(\d+),\s*awareness_level=(\d+)/.exec(element(entry, 'cap:event'));
        const level = event ? LEVELS[event[2]] : undefined;

        if (!level || normalizeRegion(element(entry, 'cap:areaDesc')) !== wanted) {
            continue;
        }

        if (element(entry, 'cap:status') !== 'Actual' || element(entry, 'cap:message_type') === 'Cancel') {
            continue;
        }

        const capLink = /<link\b[^>]*type="application\/cap\+xml"[^>]*>/.exec(entry);
        const capUrl = capLink ? attribute(capLink[0], 'href') : '';
        const onset = toLocalTime(element(entry, 'cap:onset') || element(entry, 'cap:effective'), utcOffsetSeconds);
        const alert = {
            id: `${capUrl}#${onset}`,
            source: 'meteoalarm',
            issuer: (country && ISSUERS[country[1]]) || '',
            kind: KINDS[event[1]] || 'other',
            level,
            issued: toLocalTime(element(entry, 'cap:sent'), utcOffsetSeconds),
            onset,
            expires: toLocalTime(element(entry, 'cap:expires'), utcOffsetSeconds),
            capUrl,
            headline: '',
            description: '',
        };
        const sameWarning = [alert.kind, alert.level, alert.onset, alert.expires].join('|');

        if (!newest[sameWarning] || newest[sameWarning].issued < alert.issued) {
            newest[sameWarning] = alert;
        }
    }

    return Object.keys(newest).map((key) => newest[key]).sort(byOnset);
}

/** The text of a warning from its CAP document, in the given language if the warning has it. */
export function parseCap(xml, language) {
    const infos = elements(String(xml || ''), 'info');
    const info = infos.find((candidate) => element(candidate, 'language').toLowerCase().startsWith(language)) || infos[0];

    return info ? { headline: element(info, 'headline'), description: element(info, 'description') } : { headline: '', description: '' };
}

/**
 * The immediate warnings of ANM that name the locality, among the localities of its county.
 * Locality names go through normalizeRegion() too: the geocoder names Bucharest in English.
 */
export function parseNowcast(xml, region, locality) {
    const wanted = normalizeRegion(region);
    const place = normalizeRegion(locality);
    const pattern = /<avertizare\b[^>]*>/g;
    const alerts = [];
    let match;

    if (!wanted || !place) {
        return alerts;
    }

    while ((match = pattern.exec(String(xml || ''))) !== null) {
        const tag = match[0];
        // "Județul Ialomița: Slobozia, Fetești;<br>Județul Călărași: Dragalina;<br>"
        const county = attribute(tag, 'zona')
            .split(/<br\s*\/?>/i)
            .map((part) => /^\s*([^:]+):([\s\S]*)$/.exec(part))
            .find((part) => part && normalizeRegion(part[1]) === wanted);

        if (!county || !county[2].split(/[,;]/).map(normalizeRegion).includes(place)) {
            continue;
        }

        const onset = attribute(tag, 'dataInceput').slice(0, 16);
        const description = attribute(tag, 'semnalare');

        alerts.push({
            id: `anm#${onset}#${description}`,
            source: 'anm',
            issuer: ISSUERS.RO,
            kind: 'nowcast',
            level: NOWCAST_LEVELS[plain(attribute(tag, 'numeCuloare'))] || 'yellow',
            // "2026-10-13 15:54:01", the last change of the warning.
            issued: (attribute(tag, 'modificat') || attribute(tag, 'creat')).slice(0, 16).replace(' ', 'T'),
            onset,
            expires: attribute(tag, 'dataSfarsit').slice(0, 16),
            capUrl: '',
            headline: '',
            description,
        });
    }

    return alerts.sort(byOnset);
}

export function activeAlerts(alerts, nowIso) {
    return alerts.filter((alert) => alert.expires > nowIso);
}

/** The warnings in force at some moment of a calendar day. */
export function alertsOn(alerts, isoDate) {
    const day = dateOf(isoDate);

    return alerts.filter((alert) => dateOf(alert.onset) <= day && alert.expires > `${day}T00:00`);
}

export function worstLevel(alerts) {
    const worst = Math.max(-1, ...alerts.map((alert) => SEVERITY.indexOf(alert.level)));

    return worst === -1 ? null : SEVERITY[worst];
}

export function alertTitle(alert, language) {
    return `${t(language, `alert.level.${alert.level}`)} · ${t(language, `alert.kind.${alert.kind}`)}`;
}

/** "până mâine la 10:00" for a warning in force, "mâine, 10:00 – 18:00" for one to come. */
export function alertInterval(alert, nowIso, language) {
    const start = timeLabel(alert.onset);
    const end = timeLabel(alert.expires);
    const endDay = dayWord(alert.expires, nowIso, language);

    if (alert.onset <= nowIso) {
        return dateOf(alert.expires) === dateOf(nowIso) ? t(language, 'alert.until', { time: end }) : t(language, 'alert.untilDay', { day: endDay, time: end });
    }

    const startDay = dayWord(alert.onset, nowIso, language);

    return dateOf(alert.onset) === dateOf(alert.expires)
        ? t(language, 'alert.sameDay', { day: startDay, start, end })
        : t(language, 'alert.span', { startDay, start, endDay, end });
}

/** Whether `first` is to be shown before `second`: in force before upcoming, then the more severe, then the earlier. */
function leads(first, second, nowIso) {
    const firstInForce = first.onset <= nowIso;

    if (firstInForce !== (second.onset <= nowIso)) {
        return firstInForce;
    }

    if (first.level !== second.level) {
        return SEVERITY.indexOf(first.level) > SEVERITY.indexOf(second.level);
    }

    return first.onset < second.onset;
}

/** The one warning to show where there is room for one only. */
export function leadAlert(alerts, nowIso) {
    let lead = null;

    for (const alert of alerts) {
        if (lead === null || leads(alert, lead, nowIso)) {
            lead = alert;
        }
    }

    return lead;
}

/** "emisă azi, 10:01": when the warning was issued, which the MeteoAlarm terms require to be shown. */
export function alertIssued(alert, nowIso, language) {
    if (!alert.issued) {
        return '';
    }

    return t(language, 'alert.issued', { day: dayWord(alert.issued, nowIso, language), time: timeLabel(alert.issued) });
}
