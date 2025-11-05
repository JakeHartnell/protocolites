// Verify that Solidity _hashCode will match JS hashCode

function hashCode(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) - h) + s.charCodeAt(i);
    h &= h; // In JS, this is a no-op (x & x === x), but matches what's in the code
  }
  return Math.abs(h);
}

// Test with the actual test DNA
const testDNA = BigInt(0x1234567890abcdef);
const dnaHexFull = '0x' + testDNA.toString(16).padStart(64, '0');

console.log('Test DNA value:', testDNA.toString(16));
console.log('Full hex string (66 chars):', dnaHexFull);
console.log('String length:', dnaHexFull.length);
console.log('');

const seed = hashCode(dnaHexFull);
console.log('Seed from hashCode:', seed);
console.log('');

// First random call - eye count
let currentSeed = seed;
function random() {
  currentSeed = (currentSeed * 9301 + 49297) % 233280;
  return currentSeed / 233280;
}

console.log('First random() for eyeCount:');
const r1 = random();
console.log('  random() =', r1.toFixed(6));
const eyeCount = 1 + Math.floor(r1 * 3);
console.log('  eyeCount =', eyeCount);
console.log('');

if (eyeCount === 3) {
  console.log('Expected: 3 pairs of 2x2 eyes at positions:');
  const cx = 12;
  const eyeY = 8;
  for (let i = -3; i <= 3; i += 3) {
    console.log(`  Pair at i=${i}: x=${cx+i-1},${cx+i} y=${eyeY},${eyeY+1}`);
  }
}
