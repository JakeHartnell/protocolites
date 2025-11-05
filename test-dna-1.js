// Test DNA from the failing test
const dna = "0x" + BigInt(1311768467294899695).toString(16).padStart(64, '0');
console.log("DNA:", dna);

// Hash function
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

// Decode DNA
const n = BigInt(dna);
const eyeChars = ["\u25cf", "\u25c9", "\u25ce", "\u25cb"];
const eyeCharIndex = Number((n >> 5n) & 3n);
console.log("Eye char index:", eyeCharIndex);
console.log("Eye char:", eyeChars[eyeCharIndex]);

// Test adult eye count
console.log("\nAdult eye rendering:");
const eyeCount = 1 + Math.floor(random() * 3);
console.log("eyeCount:", eyeCount);
console.log("Random result:", (seed / 233280).toFixed(6));
