import de from './strings/de.mjs';
import en from './strings/en.mjs';
import es from './strings/es.mjs';
import fr from './strings/fr.mjs';
import it from './strings/it.mjs';
import pl from './strings/pl.mjs';
import ro from './strings/ro.mjs';

/** Each language in a file of its own, under strings/. */
const BY_LANGUAGE = { ro, en, de, es, fr, it, pl };

export const LANGUAGES = Object.keys(BY_LANGUAGE);

const FALLBACK_LANGUAGE = 'en';

/** The texts of the widget, by language and key. */
export const STRINGS = {};

for (const language of LANGUAGES) {
    STRINGS[language] = BY_LANGUAGE[language].strings;
}

function supported(language) {
    return LANGUAGES.includes(language) ? language : FALLBACK_LANGUAGE;
}

/**
 * Picks the language of the widget. "auto" follows the language of the Plasma interface,
 * `uiLanguages` being the system's list of them in order of preference ("en-US", "ro_RO"…):
 * the first one the widget speaks, else English. The regional formats do not count.
 */
export function resolveLanguage(setting, uiLanguages) {
    if (LANGUAGES.includes(setting)) {
        return setting;
    }

    for (const tag of uiLanguages || []) {
        const language = String(tag).slice(0, 2).toLowerCase();

        if (LANGUAGES.includes(language)) {
            return language;
        }
    }

    return FALLBACK_LANGUAGE;
}

export function t(language, key, parameters) {
    const text = STRINGS[supported(language)][key];

    if (text === undefined) {
        return key;
    }

    return text.replace(/\{(\w+)\}/g, (placeholder, name) => (parameters && name in parameters ? parameters[name] : placeholder));
}

export function dayShort(language, dayIndex) {
    return BY_LANGUAGE[supported(language)].daysShort[dayIndex];
}

export function dayLong(language, dayIndex) {
    return BY_LANGUAGE[supported(language)].daysLong[dayIndex];
}

export function monthLong(language, month) {
    return BY_LANGUAGE[supported(language)].monthsLong[month - 1];
}

export function monthShort(language, month) {
    return BY_LANGUAGE[supported(language)].monthsShort[month - 1];
}

export function compass(degrees, language) {
    return BY_LANGUAGE[supported(language)].compass[Math.round(degrees / 45) % 8];
}
