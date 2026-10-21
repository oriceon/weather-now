/**
 * Text and addresses that come from the feeds, made safe to show and to open. A feed is written by
 * whoever runs it: its text may hold markup, and its links may lead to a file or to another program.
 */

const MARKUP = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

/** The text as it reads, in a label or a notification that reads markup: `<` and `&` stand for themselves. */
export function escapeMarkup(text) {
    return String(text || '').replace(/[&<>"']/g, (character) => MARKUP[character]);
}

/**
 * The address of a website, or '' for anything else: a file, a share, the scheme of a program. "www.x.ro",
 * as some services write their site, is given its https://; without it, Qt took it for a file next to the widget.
 */
export function webAddress(url) {
    const address = String(url || '').trim();

    if (/\s/.test(address)) {
        return '';
    }

    if (/^https?:\/\/[^/?#]+/i.test(address)) {
        return address;
    }

    return /^www\.[^/?#]+\.[a-z]{2,}(?:[/?#].*)?$/i.test(address) ? `https://${address}` : '';
}
