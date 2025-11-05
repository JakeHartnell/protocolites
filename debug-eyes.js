// Debug eye rendering for test DNA 0x1234567890abcdef
const dna = "0x1234567890abcdef";
const isKid = false;
const size = 24;
const cx = 12;
const bodyStartY = 7;
const eyeY = bodyStartY + 1; // = 8

// Hash and seed
function hashCode(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) - h) + s.charCodeAt(i);
    h &= h;
  }
  return Math.abs(h);
}

let seed = hashCode(dna);
console.log("Initial seed:", seed);

function random() {
  seed = (seed * 9301 + 49297) % 233280;
  return seed / 233280;
}

// Decode eye char
const n = BigInt(dna);
const eyeChars = ["\u25cf", "\u25c9", "\u25ce", "\u25cb"];
const eyeCharIndex = Number((n >> 5n) & 3n);
const eyeChar = eyeChars[eyeCharIndex];
console.log("Eye char:", eyeChar);

// Adult eye rendering
console.log("\nAdult eye rendering:");
const eyeCount = 1 + Math.floor(random() * 3);
console.log("eyeCount:", eyeCount);
console.log("cx:", cx, "eyeY:", eyeY);

if (eyeCount === 1) {
  console.log("\nMega eye (eyeCount === 1):");
  console.log("Should place eyes at:");
  console.log(`  (${cx-1}, ${eyeY+1}) = (11, 9)`);
  console.log(`  (${cx}, ${eyeY+1}) = (12, 9)`);
  console.log(`  (${cx+1}, ${eyeY+1}) = (13, 9)`);
  console.log("");
  console.log("In pixel coordinates (charWidth=12, xOffset=96):");
  console.log(`  x=${(cx-1)*12+96} = 228`);
  console.log(`  x=${cx*12+96} = 240`);
  console.log(`  x=${(cx+1)*12+96} = 252`);
  console.log(`  y=${(eyeY+1)*20} = 180`);
}

console.log("\nCheck condition: cx >= 2 && cx + 2 < size && eyeY + 2 < size");
console.log(`  ${cx} >= 2: ${cx >= 2}`);
console.log(`  ${cx} + 2 < ${size}: ${cx + 2 < size}`);
console.log(`  ${eyeY} + 2 < ${size}: ${eyeY + 2 < size}`);
console.log(`  All pass: ${cx >= 2 && cx + 2 < size && eyeY + 2 < size}`);
