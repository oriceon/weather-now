// Looking a place up by what was typed. Open-Meteo finds a place by the start of its name, written
// nearly as it is: "Valul lui Traian" or "Valu lui Traian Constanta" find nothing, though "Valu lui
// Traian" does. So the search asks in turn, until something answers: the name as typed, then with
// its last words left out, which may be the county or the country, then each of its longer words
// alone, and their starts, among many places, keeping those whose name has all the words typed,
// give or take a letter. What comes after a comma is the county or the country, and only sorts what is found.

/** Letters with diacritics, and what they are without; for an engine without String#normalize. */
const PLAIN = {
    ă: 'a', â: 'a', á: 'a', à: 'a', ä: 'a', å: 'a', ą: 'a', ã: 'a',
    î: 'i', í: 'i', ì: 'i', ï: 'i', ı: 'i',
    ș: 's', ş: 's', ś: 's', š: 's', ß: 'ss',
    ț: 't', ţ: 't',
    é: 'e', è: 'e', ê: 'e', ë: 'e', ę: 'e', ě: 'e',
    ó: 'o', ò: 'o', ô: 'o', ö: 'o', ő: 'o', õ: 'o', ø: 'o',
    ú: 'u', ù: 'u', û: 'u', ü: 'u', ű: 'u', ů: 'u',
    ç: 'c', ć: 'c', č: 'c', ñ: 'n', ń: 'n', ň: 'n', ł: 'l', ż: 'z', ź: 'z', ž: 'z', ř: 'r', ý: 'y', ğ: 'g', đ: 'd', ď: 'd',
};
/** How many places a word alone is looked up among. */
const MANY = 100;
/** How many places are shown. */
const SHOWN = 8;

/** A text for comparing: in lower case, without diacritics, ș and ț of either form alike. */
export function folded(text) {
    return Array.from(String(text).toLowerCase()).map((letter) => PLAIN[letter] || letter).join('');
}

function wordsOf(text) {
    return folded(text).split(/[\s\-.'’]+/).filter((word) => word !== '');
}

/** The number of letters to add, remove or change to make one word the other. */
function distance(first, second) {
    let previous = Array.from({ length: second.length + 1 }, (unused, index) => index);

    for (let row = 1; row <= first.length; row++) {
        const current = [row];

        for (let column = 1; column <= second.length; column++) {
            current.push(Math.min(previous[column] + 1, current[column - 1] + 1, previous[column - 1] + (first[row - 1] === second[column - 1] ? 0 : 1)));
        }

        previous = current;
    }

    return previous[second.length];
}

/** Whether a word typed is a word of a name: the same, its start, or a letter off in a long word. */
export function similarWords(typed, real) {
    if (typed === real || (typed.length >= 3 && real.startsWith(typed))) {
        return true;
    }

    return typed.length >= 4 && real.length >= 3 && distance(typed, real) <= 1;
}

/**
 * What to ask Open-Meteo, in turn: `[{ name, count, dropped, every }]`, `name` the text to look up
 * among `count` places; the places it gives must have `dropped`, the words left out of the name,
 * in their name, county or country, or, with `every`, all the words typed. `qualifiers`, from after
 * the commas, only sort them.
 */
export function searchPlan(text) {
    const [typedName, ...rest] = String(text).split(',');
    const words = typedName.trim().split(/\s+/).filter((word) => word !== '');
    const queries = [];

    for (let kept = words.length; kept >= 1; kept--) {
        queries.push({ name: words.slice(0, kept).join(' '), count: kept === words.length ? SHOWN : MANY / 5, dropped: words.slice(kept).map(folded), every: false });
    }

    const longest = words.filter((word) => word.length >= 4).sort((first, second) => second.length - first.length);

    longest.forEach((word) => queries.push({ name: word, count: MANY, dropped: [], every: true }));
    // A word mistyped at its end, as "Valul" for "Valu", is found by its start.
    longest.filter((word) => word.length >= 5).forEach((word) => queries.push({ name: word.slice(0, -1), count: MANY, dropped: [], every: true }));

    return {
        queries: queries.filter((query, index) => queries.findIndex((other) => other.name === query.name && other.count === query.count) === index),
        words: words.map(folded),
        qualifiers: rest.map((part) => folded(part).trim()).filter((part) => part !== ''),
    };
}

/** Whether each of `words` is a word of the place, of its name, county or country. */
function hasWords(place, words) {
    const own = wordsOf(`${place.name} ${place.region || ''} ${place.country || ''} ${place.countryCode || ''}`);

    return words.every((typed) => wordsOf(typed).every((part) => own.some((word) => similarWords(part, word))));
}

/**
 * The places of one answer to `query` of `plan` worth showing: those that have what the query asks
 * for; those of the county or country after the commas first, the others after them.
 */
export function placesFound(places, query, plan) {
    const fitting = places.filter((place) => (query.every ? hasWords(place, plan.words) : hasWords(place, query.dropped)));
    const qualified = fitting.filter((place) => hasWords(place, plan.qualifiers));

    return qualified.concat(fitting.filter((place) => qualified.indexOf(place) === -1)).slice(0, SHOWN);
}
