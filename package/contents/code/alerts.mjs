import { dateOf, dayWord, timeShown } from './dates.mjs';
import { t } from './i18n.mjs';
import { webAddress } from './links.mjs';

/**
 * Official weather warnings. In Romania they are issued by ANM and reach the widget two ways:
 * the general ones, per county, through the MeteoAlarm feed ANM publishes them to, and the
 * immediate ("nowcasting") ones straight from ANM, which names the localities concerned. Of these,
 * the widget keeps only the ones that name its own locality.
 *
 * Elsewhere they come from the FOSS Public Alert Server that KDE runs, which gathers the CAP feeds
 * of alerting authorities around the world. Its terms: do not abuse the API, do not change the
 * warnings, link to the server, and name the official source of each warning.
 */

/** Country code => name of the country in the address of its MeteoAlarm feed. */
const METEOALARM_FEEDS = { RO: 'romania' };
/**
 * Country code => the weather service that issues its warnings. The MeteoAlarm terms
 * require its name to be shown with warnings that concern a single country.
 */
const ISSUERS = { RO: 'ANM' };
/** Service => its website, linked from the source line of the widget. */
const ISSUER_SITES = { ANM: 'https://www.meteoromania.ro/' };

/** The MeteoAlarm terms require every redistributor to publish this, word for word. */
export const METEOALARM_DISCLAIMER = 'Time delays between this website and the www.meteoalarm.org website are possible. For the most up-to-date awareness information as published by the participating National Meteorological and Hydrological Services, please refer to www.meteoalarm.org.';

const NOWCAST_FEEDS = { RO: 'https://www.meteoromania.ro/avertizari-nowcasting-xml.php' };
/** The CAP documents of the MeteoAlarm feed are fetched from MeteoAlarm only, whatever its links name. */
const METEOALARM_DOCUMENTS = /^https:\/\/feeds\.meteoalarm\.org\/[^\s]*$/;

export const PUBLIC_ALERT_SERVER = 'https://alerts.kde.org';
/** Half the side of the square asked about, in degrees: some five kilometres around the place. */
const PUBLIC_ALERT_REACH = 0.05;
/** No more than this many warnings are fetched at a time, so as not to burden the server. */
const PUBLIC_ALERT_MOST = 10;
/** CAP severity => level of the widget. "Minor" is the first level of a national service, as yellow is. */
const PUBLIC_LEVELS = { Extreme: 'red', Severe: 'orange', Moderate: 'yellow', Minor: 'yellow' };
/** A warning without an end is taken to last a day. */
const DAY_MS = 24 * 60 * 60 * 1000;
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

/** What a table holds under a name from a feed; "constructor" or "toString" are not its own. */
function own(table, name) {
    return Object.prototype.hasOwnProperty.call(table, name) ? table[name] : undefined;
}

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

/** Whether the tag opened at `at` is named `name` and not only begins so: `<info>`, not `<infoX>`. */
function namedAt(xml, at, name) {
    return /[\s>/]/.test(xml.charAt(at + name.length + 1));
}

/**
 * The feeds are machine-written and flat, so their elements are read as text rather than through a
 * DOM. Read by scanning forward, never back: a lazy pattern took a minute over a long document with
 * elements left open, and the widget runs where the desktop does.
 */
function elements(xml, name) {
    const close = `</${name}>`;
    const found = [];
    let at = xml.indexOf(`<${name}`);

    while (at !== -1) {
        if (namedAt(xml, at, name)) {
            const start = xml.indexOf('>', at) + 1;
            const end = start === 0 ? -1 : xml.indexOf(close, start);

            if (end === -1) {
                break;
            }

            found.push(xml.slice(start, end));
            at = end + close.length;
        } else {
            at += name.length + 1;
        }

        at = xml.indexOf(`<${name}`, at);
    }

    return found;
}

/** The opening tags named `name`, as `<link href="…" type="…">`, for their attributes. */
function openingTags(xml, name) {
    const found = [];
    let at = xml.indexOf(`<${name}`);

    while (at !== -1) {
        const end = xml.indexOf('>', at);

        if (end === -1) {
            break;
        }

        if (namedAt(xml, at, name)) {
            found.push(xml.slice(at, end + 1));
        }

        at = xml.indexOf(`<${name}`, end);
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
    // A place kept from a search in another language, before the search asked for the Romanian name:
    // "Kreis Constanța", "Județ de Iași", "Condado de Iași". Italian and Polish translate the name itself.
    const county = plain(name)
        .replace(/^(judetul|municipiul|judet de|kreis|condado de)\s+/, '')
        .replace(/\s+county$/, '');

    return ['bucharest', 'bukarest', 'bucarest', 'bukareszt'].includes(county) ? 'bucuresti' : county;
}

export function feedUrl(countryCode) {
    const country = METEOALARM_FEEDS[String(countryCode || '').toUpperCase()];

    return country ? `https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-${country}` : '';
}

/** Whether the warnings of a country come through MeteoAlarm; the others come from the public alert server. */
export function hasMeteoalarm(countryCode) {
    return feedUrl(countryCode) !== '';
}

/** The warnings in a square around the place, as ids. The place is rounded to about a kilometre, as everywhere else. */
export function publicAlertsUrl(latitude, longitude) {
    const round = (value) => Math.round(value * 100) / 100;
    const box = [round(latitude) - PUBLIC_ALERT_REACH, round(latitude) + PUBLIC_ALERT_REACH, round(longitude) - PUBLIC_ALERT_REACH, round(longitude) + PUBLIC_ALERT_REACH]
        .map((value) => value.toFixed(2));

    return `${PUBLIC_ALERT_SERVER}/alert/area?min_lat=${box[0]}&max_lat=${box[1]}&min_lon=${box[2]}&max_lon=${box[3]}`;
}

export function publicAlertUrl(id) {
    return `${PUBLIC_ALERT_SERVER}/alert/${encodeURIComponent(id)}`;
}

/** The ids of the warnings the server lists for an area, the first few. */
export function parsePublicAlertIds(json) {
    return Array.isArray(json) ? json.filter((id) => typeof id === 'string').slice(0, PUBLIC_ALERT_MOST) : [];
}

/**
 * A weather warning from the CAP document of the public alert server, in the language of the
 * widget if it has it, else in English; null for one that is not about the weather, not actual,
 * cancelled or of no known severity.
 */
export function parsePublicAlert(xml, language, utcOffsetSeconds) {
    const text = String(xml || '');
    const infos = elements(text, 'info');
    const speaks = (candidate, wanted) => element(candidate, 'language').toLowerCase().startsWith(wanted);
    const info = infos.find((candidate) => speaks(candidate, language)) || infos.find((candidate) => speaks(candidate, 'en')) || infos[0];

    if (!info || element(text, 'status') !== 'Actual' || element(text, 'msgType') === 'Cancel') {
        return null;
    }

    const level = own(PUBLIC_LEVELS, element(info, 'severity'));

    if (!level || !elements(info, 'category').map((category) => category.trim()).includes('Met')) {
        return null;
    }

    const sent = element(text, 'sent');
    const onset = toLocalTime(element(info, 'onset') || element(info, 'effective') || sent, utcOffsetSeconds);
    // A warning that says nothing of when it holds cannot be placed: it is left out, not the others with it.
    const expires = toLocalTime(element(info, 'expires'), utcOffsetSeconds)
        || (onset !== '' ? new Date(Date.parse(`${onset}:00Z`) + DAY_MS).toISOString().slice(0, 16) : '');

    if (onset === '' || expires === '') {
        return null;
    }

    return {
        id: element(text, 'identifier'),
        source: 'public',
        issuer: element(info, 'senderName') || element(text, 'sender'),
        kind: 'other',
        event: element(info, 'event'),
        level,
        issued: toLocalTime(sent, utcOffsetSeconds),
        onset,
        expires,
        capUrl: '',
        // 0 in the language of the widget, 1 in English, 2 in another: see distinctAlerts().
        languageRank: speaks(info, language) ? 0 : speaks(info, 'en') ? 1 : 2,
        web: webAddress(element(info, 'web')),
        headline: element(info, 'headline'),
        description: element(info, 'description'),
    };
}

/**
 * Warnings that say the same for the same hours, as regions of one service often get, shown once.
 * A service that publishes each warning in several languages, as separate documents, has the one
 * in a language the widget does not speak give way to the one in a language it does, but only as
 * long as each has such a twin: a warning without one stays, untranslated, rather than go unseen.
 * Each warning kept lists, in `sameAs`, the ids of those it stands for, so that a notification is
 * not sent again for one of them.
 */
export function distinctAlerts(alerts) {
    const when = (alert) => [alert.issuer, alert.level, alert.onset, alert.expires].join('|');
    const count = (included) => {
        const counts = {};

        alerts.filter(included).forEach((alert) => {
            counts[when(alert)] = (counts[when(alert)] || 0) + 1;
        });

        return counts;
    };
    const understood = count((alert) => alert.languageRank !== undefined && alert.languageRank < 2);
    const foreign = count((alert) => alert.languageRank === 2);
    const translated = (alert) => alert.languageRank === 2 && foreign[when(alert)] <= (understood[when(alert)] || 0);
    const kept = [];
    const byText = {};

    alerts.filter((alert) => !translated(alert)).forEach((alert) => {
        const key = [alert.issuer, alert.event || alert.kind, alert.level, alert.onset, alert.expires].join('|');

        if (byText[key]) {
            byText[key].sameAs.push(alert.id);

            return;
        }

        byText[key] = Object.assign({}, alert, { sameAs: [] });
        kept.push(byText[key]);
    });

    alerts.filter(translated).forEach((alert) => {
        const twin = kept.find((candidate) => when(candidate) === when(alert));

        if (twin) {
            twin.sameAs.push(alert.id);
        }
    });

    return kept;
}

/** The website of the service that issued a warning; empty when it is not known. */
export function issuerSite(issuer) {
    return own(ISSUER_SITES, issuer) || '';
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

        const capLink = openingTags(entry, 'link').find((tag) => attribute(tag, 'type') === 'application/cap+xml');
        const capUrl = capLink && METEOALARM_DOCUMENTS.test(attribute(capLink, 'href')) ? attribute(capLink, 'href') : '';
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
    const alerts = [];

    if (!wanted || !place) {
        return alerts;
    }

    for (const tag of openingTags(String(xml || ''), 'avertizare')) {
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
            level: own(NOWCAST_LEVELS, plain(attribute(tag, 'numeCuloare'))) || 'yellow',
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

/**
 * "Cod galben · vânt"; a warning from the public alert server is named by its own event, as its
 * service wrote it, the German nouns with their capitals; only one shouted in capitals is calmed.
 */
export function alertTitle(alert, language) {
    const event = alert.event || '';
    const written = event === event.toUpperCase() ? event.toLowerCase() : event;
    const what = event !== '' ? written.charAt(0).toUpperCase() + written.slice(1) : t(language, `alert.kind.${alert.kind}`);

    return `${t(language, `alert.level.${alert.level}`)} · ${what}`;
}

/** "până mâine la 10:00" for a warning in force, "mâine, 10:00 – 18:00" for one to come. */
export function alertInterval(alert, nowIso, language) {
    const start = timeShown(alert.onset);
    const end = timeShown(alert.expires);
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

/** The warnings in the order they are shown: in force before upcoming, then the more severe, then the earlier. */
export function inLeadOrder(alerts, nowIso) {
    return alerts.slice().sort((first, second) => (leads(first, second, nowIso) ? -1 : leads(second, first, nowIso) ? 1 : 0));
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

    return t(language, 'alert.issued', { day: dayWord(alert.issued, nowIso, language), time: timeShown(alert.issued) });
}
