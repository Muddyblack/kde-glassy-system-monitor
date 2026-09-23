.pragma library

// The optional password for the network window: a salted, iterated SHA-256
// of it is kept in network-window.json (private, 600), never the password.
// It locks the window, it does not encrypt the history files (the widget
// records in the background, without the password).

var K = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];

function utf8Bytes(text) {
    var out = [];
    for (var i = 0; i < text.length; i++) {
        var c = text.charCodeAt(i);
        if (c >= 0xd800 && c < 0xdc00 && i + 1 < text.length)
            c = 0x10000 + ((c - 0xd800) << 10) + (text.charCodeAt(++i) - 0xdc00);
        if (c < 0x80)
            out.push(c);
        else if (c < 0x800)
            out.push(0xc0 | c >> 6, 0x80 | c & 63);
        else if (c < 0x10000)
            out.push(0xe0 | c >> 12, 0x80 | c >> 6 & 63, 0x80 | c & 63);
        else
            out.push(0xf0 | c >> 18, 0x80 | c >> 12 & 63, 0x80 | c >> 6 & 63, 0x80 | c & 63);
    }
    return out;
}

// SHA-256 of a byte array → hex.
function sha256Bytes(bytes) {
    var h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    var msg = bytes.slice();
    var bits = bytes.length * 8;
    msg.push(0x80);
    while (msg.length % 64 !== 56)
        msg.push(0);
    for (var s = 7; s >= 0; s--)
        msg.push(s >= 4 ? 0 : (bits >>> (s * 8)) & 255);
    var w = new Array(64);
    for (var off = 0; off < msg.length; off += 64) {
        for (var t = 0; t < 16; t++)
            w[t] = msg[off + t * 4] << 24 | msg[off + t * 4 + 1] << 16 | msg[off + t * 4 + 2] << 8 | msg[off + t * 4 + 3];
        for (t = 16; t < 64; t++) {
            var x = w[t - 15], y = w[t - 2];
            var s0 = (x >>> 7 | x << 25) ^ (x >>> 18 | x << 14) ^ x >>> 3;
            var s1 = (y >>> 17 | y << 15) ^ (y >>> 19 | y << 13) ^ y >>> 10;
            w[t] = w[t - 16] + s0 + w[t - 7] + s1 | 0;
        }
        var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], k = h[7];
        for (t = 0; t < 64; t++) {
            var S1 = (e >>> 6 | e << 26) ^ (e >>> 11 | e << 21) ^ (e >>> 25 | e << 7);
            var t1 = k + S1 + (e & f ^ ~e & g) + K[t] + w[t] | 0;
            var S0 = (a >>> 2 | a << 30) ^ (a >>> 13 | a << 19) ^ (a >>> 22 | a << 10);
            var t2 = S0 + (a & b ^ a & c ^ b & c) | 0;
            k = g;
            g = f;
            f = e;
            e = d + t1 | 0;
            d = c;
            c = b;
            b = a;
            a = t1 + t2 | 0;
        }
        h[0] = h[0] + a | 0;
        h[1] = h[1] + b | 0;
        h[2] = h[2] + c | 0;
        h[3] = h[3] + d | 0;
        h[4] = h[4] + e | 0;
        h[5] = h[5] + f | 0;
        h[6] = h[6] + g | 0;
        h[7] = h[7] + k | 0;
    }
    return h.map(function (v) { return ("0000000" + (v >>> 0).toString(16)).slice(-8); }).join("");
}

function sha256(text) {
    return sha256Bytes(utf8Bytes(text));
}

var ITERATIONS = 8000;

// { salt, iter, hash } for a new password.
function create(password) {
    var salt = "";
    for (var i = 0; i < 4; i++)
        salt += ("0000000" + Math.floor(Math.random() * 0x100000000).toString(16)).slice(-8);
    return { salt: salt, iter: ITERATIONS, hash: derive(password, salt, ITERATIONS) };
}

function derive(password, salt, iter) {
    var h = sha256(salt + ":" + password);
    for (var i = 1; i < iter; i++)
        h = sha256(h + salt);
    return h;
}

function check(lock, password) {
    if (!lock || !lock.hash || !lock.salt)
        return true;
    return derive(password, lock.salt, lock.iter || ITERATIONS) === lock.hash;
}
