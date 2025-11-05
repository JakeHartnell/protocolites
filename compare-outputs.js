// Direct comparison of JS renderer output for tokenId 6
const fs = require('fs');

const tokenId = 6;
const dna = "0x2749b2e8089146d20914f5429502c8d701db600cd442f0cd8355b91a3af97fdf";
const isKid = false;
const parentDna = "0x00";
const size = 24;

// Hash function for seeding
function hashCode(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) - h) + s.charCodeAt(i);
    h &= h;
  }
  return Math.abs(h);
}

// Seeded random number generator
let seed = hashCode(dna);
console.log("Initial seed:", seed);

let callCount = 0;
function random() {
  seed = (seed * 9301 + 49297) % 233280;
  callCount++;
  const result = seed / 233280;
  console.log(`Random call ${callCount}: seed=${seed}, result=${result.toFixed(6)}`);
  return result;
}

// DNA Decoding
function decodeDNA(d) {
  const n = BigInt(d);
  const bt = ["square", "round", "diamond", "mushroom", "invader", "ghost"];
  const bc = ["\u2588", "\u2593", "\u2592", "\u2591"];
  const ec = ["\u25cf", "\u25c9", "\u25ce", "\u25cb"];
  const at = ["\u25cf", "\u25c9", "\u25cb", "\u25ce", "\u2726", "\u2727", "\u2605"];
  const ht = ["none", "top", "flat", "double", "fancy"];

  return {
    bodyType: bt[Number((n >> 0n) & 7n) % 6],
    bodyChar: bc[Number((n >> 3n) & 3n)],
    eyeChar: ec[Number((n >> 5n) & 3n)],
    eyeSize: Number((n >> 7n) & 1n) === 1 ? "mega" : "normal",
    antennaTip: at[Number((n >> 8n) & 7n) % 7],
    armStyle: Number((n >> 11n) & 1n) === 1 ? "line" : "block",
    legStyle: Number((n >> 12n) & 1n) === 1 ? "line" : "block",
    hatType: ht[Number((n >> 13n) & 7n) % 5],
    hasCigarette: Number((n >> 16n) & 1n) === 1
  };
}

const dnaObj = decodeDNA(dna);
console.log("\nDNA decoded:", dnaObj);

// Initialize grid
const grid = Array(size).fill().map(() =>
  Array(size).fill(null).map(() => ({ char: " ", type: "empty" }))
);

const cx = Math.floor(size / 2);
const cy = Math.floor(size / 2);
const bodyType = dnaObj.bodyType;
const bodyWidth = size === 24 ? 6 : 3;
const bodyHeight = size === 24 ? 8 : 4;
const bodyStartY = size === 24 ? 7 : 6;

console.log(`\nBody params: cx=${cx}, cy=${cy}, bodyWidth=${bodyWidth}, bodyHeight=${bodyHeight}, bodyStartY=${bodyStartY}`);

// Draw body
for (let y = 0; y < bodyHeight; y++) {
  for (let x = -bodyWidth; x <= bodyWidth; x++) {
    const posY = bodyStartY + y;
    const posX = cx + x;
    let inBody = false;
    const relX = x / bodyWidth;
    const relY = (y - bodyHeight / 2) / (bodyHeight / 2);

    if (bodyType === "square") {
      inBody = true;
    } else if (bodyType === "round") {
      const dist = Math.sqrt(relX * relX + relY * relY);
      inBody = dist <= 1.0;
    }

    if (inBody && posX >= 0 && posX < size && posY >= 0 && posY < size) {
      grid[posY][posX] = { char: dnaObj.bodyChar, type: 'body' };
    }
  }
}

const isBodyChar = c => c && c.type === "body";

// Draw eyes
console.log("\n=== EYE RENDERING ===");
const eyeY = bodyStartY + 1;
console.log(`eyeY = ${eyeY}`);

if (isKid) {
  console.log("KID BRANCH");
  const eyeCount = 1 + Math.floor(random() * 3);
  console.log(`eyeCount = ${eyeCount}`);
} else {
  console.log("ADULT BRANCH");
  const eyeCount = 1 + Math.floor(random() * 3);
  console.log(`eyeCount = ${eyeCount}`);

  if (eyeCount === 1) {
    console.log("Adult eyeCount === 1: Drawing mega eye");
    // Clear and draw mega eye
    for (let dy = 0; dy < 3; dy++) {
      for (let dx = -2; dx <= 2; dx++) {
        if (isBodyChar(grid[eyeY + dy][cx + dx])) {
          grid[eyeY + dy][cx + dx] = { char: ' ', type: 'empty' };
        }
      }
    }
    for (let dx = -2; dx <= 2; dx++) {
      grid[eyeY][cx + dx] = { char: dnaObj.bodyChar, type: 'body' };
      grid[eyeY + 2][cx + dx] = { char: dnaObj.bodyChar, type: 'body' };
    }
    grid[eyeY + 1][cx - 2] = { char: dnaObj.bodyChar, type: 'body' };
    grid[eyeY + 1][cx - 1] = { char: dnaObj.eyeChar, type: 'eye' };
    grid[eyeY + 1][cx] = { char: dnaObj.eyeChar, type: 'eye' };
    grid[eyeY + 1][cx + 1] = { char: dnaObj.eyeChar, type: 'eye' };
    grid[eyeY + 1][cx + 2] = { char: dnaObj.bodyChar, type: 'body' };
  } else if (eyeCount === 2) {
    console.log("Adult eyeCount === 2: Drawing 2 eyes");
  } else {
    console.log("Adult eyeCount === 3: Drawing 3 pairs of eyes");
    for (let i = -3; i <= 3; i += 3) {
      console.log(`  Drawing eye pair at i=${i} (positions: cx+${i}-1=${cx+i-1}, cx+${i}=${cx+i})`);
      for (let dy = 0; dy < 2; dy++) {
        if (isBodyChar(grid[eyeY + dy][cx + i])) grid[eyeY + dy][cx + i] = { char: ' ', type: 'empty' };
        if (isBodyChar(grid[eyeY + dy][cx + i - 1])) grid[eyeY + dy][cx + i - 1] = { char: ' ', type: 'empty' };
        grid[eyeY + dy][cx + i] = { char: dnaObj.eyeChar, type: 'eye' };
        grid[eyeY + dy][cx + i - 1] = { char: dnaObj.eyeChar, type: 'eye' };
      }
    }
  }
}

// Print eye positions
console.log("\nEye positions in grid:");
for (let y = 0; y < size; y++) {
  for (let x = 0; x < size; x++) {
    if (grid[y][x].type === 'eye') {
      console.log(`  (${x}, ${y}): '${grid[y][x].char}'`);
    }
  }
}

console.log(`\nTotal random() calls so far: ${callCount}`);
