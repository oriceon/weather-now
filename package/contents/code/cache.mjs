/**
 * The answers of the servers, kept a while by address: a place switched back to, a change of the
 * language or of the units, or another widget showing the same place, does not ask again. The
 * module is loaded once for the engine of the desktop, so that what one widget fetched, all have.
 */

/** No more than this many characters are kept in all: a forecast is some hundreds of thousands. */
const MOST_CHARACTERS = 6 * 1000 * 1000;

/** Address => `{ text, at }`, the oldest first. */
const answers = new Map();

/**
 * The text last fetched from `url`, if it is younger than `lifetime` milliseconds; else undefined.
 * One fetched "in the future", before the clock of the computer was set back, is not fresh.
 */
export function remembered(url, lifetime, now = Date.now()) {
    const answer = answers.get(url);
    const age = answer !== undefined ? now - answer.at : -1;

    return age >= 0 && age < lifetime ? answer.text : undefined;
}

/** When the text kept for `url` was fetched, in milliseconds like Date.now(); 0 for none. */
export function fetchedAt(url) {
    const answer = answers.get(url);

    return answer !== undefined ? answer.at : 0;
}

/** Keeps the text fetched from `url`; the oldest answers make room for it. */
export function remember(url, text, now = Date.now()) {
    answers.delete(url);
    answers.set(url, { text, at: now });

    let total = 0;

    answers.forEach((answer) => {
        total += answer.text.length;
    });

    for (const [address, answer] of answers) {
        if (total <= MOST_CHARACTERS || address === url) {
            break;
        }

        total -= answer.text.length;
        answers.delete(address);
    }
}

/** Forgets every answer: for the tests. */
export function forgetAll() {
    answers.clear();
}
