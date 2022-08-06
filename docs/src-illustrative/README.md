
```sh
node mini_mocaico.js
```

## Explain

Imagine a binary representation of an hierarchical code, *hcode*.  We can aggregate over "parent codes" (prefixes), that results in a 2 or 3-digits binary number.  Imagine that each 5-digits hcode represents a file, and each file can result in a different size (in bytes).  

```js
S2 and configs: { nItems: 25,
  maxBytes: 60,
  minBytes: 5,
  hcode_isbase4: false,
  hcode_digits: 5,
  treshold: 250 }
Set {
  { hcode: '00001', bytes: 33 },
  { hcode: '01111', bytes: 41 },
  { hcode: '10011', bytes: 28 },
  { hcode: '00101', bytes: 11 },
  { hcode: '00100', bytes: 18 },
  { hcode: '01110', bytes: 30 },
  { hcode: '11111', bytes: 18 },
  { hcode: '10111', bytes: 21 },
  { hcode: '01001', bytes: 17 },
  { hcode: '11100', bytes: 39 },
  { hcode: '11000', bytes: 21 },
  { hcode: '00010', bytes: 41 },
  { hcode: '10010', bytes: 47 },
  { hcode: '11011', bytes: 20 },
  { hcode: '11010', bytes: 49 },
  { hcode: '11001', bytes: 33 },
  { hcode: '01100', bytes: 55 },
  { hcode: '10001', bytes: 29 },
  { hcode: '00110', bytes: 28 },
  { hcode: '10000', bytes: 43 },
  { hcode: '01010', bytes: 26 },
  { hcode: '10110', bytes: 22 },
  { hcode: '11101', bytes: 12 },
  { hcode: '00111', bytes: 53 },
  { hcode: '01011', bytes: 32 } }

S2 mosaic:
{ '10':
   { bytesSum: 190,
     items:
      { '10000': 43,
        '10001': 29,
        '10010': 47,
        '10011': 28,
        '10110': 22,
        '10111': 21 } },
  '11':
   { bytesSum: 192,
     items:
      { '11000': 21,
        '11001': 33,
        '11010': 49,
        '11011': 20,
        '11100': 39,
        '11101': 12,
        '11111': 18 } },
  '00':
   { bytesSum: 184,
     items:
      { '00111': 53,
        '00110': 28,
        '00010': 41,
        '00100': 18,
        '00101': 11,
        '00001': 33 } },
  '01':
   { bytesSum: 201,
     items:
      { '01011': 32,
        '01010': 26,
        '01100': 55,
        '01001': 17,
        '01110': 30,
        '01111': 41 } } }

Reduced mosaic:
{ '0':
   { bytesSum: 385,
     items:
      { '00111': 53,
        '00110': 28,
        '00010': 41,
        '00100': 18,
        '00101': 11,
        '00001': 33,
        '01011': 32,
        '01010': 26,
        '01100': 55,
        '01001': 17,
        '01110': 30,
        '01111': 41 } },
  '1':
   { bytesSum: 382,
     items:
      { '10000': 43,
        '10001': 29,
        '10010': 47,
        '10011': 28,
        '10110': 22,
        '10111': 21,
        '11000': 21,
        '11001': 33,
        '11010': 49,
        '11011': 20,
        '11100': 39,
        '11101': 12,
        '11111': 18 } } }
```

Run again to obtain a reduced mosaic with a peace of 2 digits:

```js
S2 mosaic:
{ '10':
   { bytesSum: 245,
     items:
      { '10000': 57,
        '10011': 9,
        '10100': 29,
        '10101': 54,
        '10110': 49,
        '10111': 47 } },
  '11':
   { bytesSum: 126,
     items:
      { '11001': 6,
        '11010': 34,
        '11011': 34,
        '11100': 21,
        '11101': 6,
        '11110': 25 } },
  '01':
   { bytesSum: 251,
     items:
      { '01111': 22,
        '01000': 27,
        '01110': 46,
        '01101': 59,
        '01011': 42,
        '01010': 55 } },
  '00':
   { bytesSum: 207,
     items:
      { '00100': 26,
        '00010': 42,
        '00011': 23,
        '00111': 11,
        '00000': 43,
        '00101': 44,
        '00001': 18 } } }

Reduced mosaic:
{ '0':
   { bytesSum: 207,
     items:
      { '00100': 26,
        '00010': 42,
        '00011': 23,
        '00111': 11,
        '00000': 43,
        '00101': 44,
        '00001': 18 } },
  '1':
   { bytesSum: 371,
     items:
      { '10000': 57,
        '10011': 9,
        '10100': 29,
        '10101': 54,
        '10110': 49,
        '10111': 47,
        '11001': 6,
        '11010': 34,
        '11011': 34,
        '11100': 21,
        '11101': 6,
        '11110': 25 } },
  '01':
   { bytesSum: 251,
     items:
      { '01111': 22,
        '01000': 27,
        '01110': 46,
        '01101': 59,
        '01011': 42,
        '01010': 55 } } }
```
