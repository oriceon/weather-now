import test from 'node:test';
import assert from 'node:assert/strict';
import { escapeMarkup, webAddress } from '../package/contents/code/links.mjs';

test('text from a feed reads as it is written, markup and all', () => {
    assert.equal(escapeMarkup('< -10 °C & <img src=http://x/p.png>'), '&lt; -10 °C &amp; &lt;img src=http://x/p.png&gt;');
    assert.equal(escapeMarkup('<a href="file:///x">DWD</a>'), '&lt;a href=&quot;file:///x&quot;&gt;DWD&lt;/a&gt;');
    assert.equal(escapeMarkup(undefined), '');
});

test('only the address of a website opens', () => {
    assert.equal(webAddress('https://www.knmi.nl/waarschuwingen'), 'https://www.knmi.nl/waarschuwingen');
    assert.equal(webAddress('http://www.meteoromania.ro'), 'http://www.meteoromania.ro');
    assert.equal(webAddress(' www.boebrach.de '), 'https://www.boebrach.de');

    ['file:///etc/passwd', 'smb://host/share', 'steam://run/1', 'javascript:alert(1)', 'evil.desktop', 'https://', 'https://x.ro/a b', ''].forEach((address) => {
        assert.equal(webAddress(address), '', address);
    });
});
