// Test random sequence for tokenId 6
const dna = "0x2749b2e8089146d20914f5429502c8d701db600cd442f0cd8355b91a3af97fdf";
const tokenId = 6;
const isKid = (tokenId % 10) < 3;

console.log("tokenId:", tokenId);
console.log("isKid:", isKid);
console.log("dna:", dna);
console.log("");

// Hash function
function hashCode(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) - h) + s.charCodeAt(i);
    h &= h;
  }
  return Math.abs(h);
}

// Seeded random
let seed = hashCode(dna);
console.log("Initial seed:", seed);

let callNum = 0;
function random() {
  seed = (seed * 9301 + 49297) % 233280;
  const result = seed / 233280;
  callNum++;
  console.log(`Call ${callNum}: seed=${seed}, result=${result.toFixed(6)}`);
  return result;
}

// Trace the sequence
console.log("\n=== RANDOM SEQUENCE ===\n");

// Eye count (adult branch)
console.log("1. Eye count:");
const eyeCount = 1 + Math.floor(random() * 3);
console.log(`   eyeCount = ${eyeCount}\n`);

// Mouth check
console.log("2. Mouth check:");
const hasMouth = random() > 0.3;
console.log(`   hasMouth = ${hasMouth}\n`);

if (hasMouth) {
  console.log("3. Mouth extend left:");
  const extendLeft = random() > 0.5;
  console.log(`   extendLeft = ${extendLeft}\n`);

  console.log("4. Mouth extend right:");
  const extendRight = random() > 0.5;
  console.log(`   extendRight = ${extendRight}\n`);
}

// Decode DNA for hasCigarette
const n = BigInt(dna);
const hasCigarette = Number((n >> 16n) & 1n) === 1;
console.log("hasCigarette (from DNA):", hasCigarette);

if (hasCigarette) {
  console.log("5. Cigarette character:");
  const cigCharIndex = Math.floor(random() * 3);
  console.log(`   cigCharIndex = ${cigCharIndex}\n`);

  console.log("6. Cigarette position:");
  const cigRight = random() > 0.5;
  console.log(`   cigRight = ${cigRight}\n`);
}

console.log("7. Arm count:");
const armCount = 1 + Math.floor(random() * 4);
console.log(`   armCount = ${armCount}\n`);

console.log("8. Arm length (adult):");
const armLength = 2 + Math.floor(random() * 4);
console.log(`   armLength = ${armLength}\n`);

console.log("9. Leg count:");
const legCount = 1 + Math.floor(random() * 4);
console.log(`   legCount = ${legCount}\n`);

console.log("10. Leg length (adult):");
const legLength = 2 + Math.floor(random() * 3);
console.log(`   legLength = ${legLength}\n`);

console.log("11. Antenna count:");
const antennaCount = 1 + Math.floor(random() * 4);
console.log(`   antennaCount = ${antennaCount}\n`);

console.log("12. Antenna length (adult):");
const antennaLength = 1 + Math.floor(random() * 2);
console.log(`   antennaLength = ${antennaLength}\n`);

console.log("\n=== SUMMARY ===");
console.log(`Total random() calls: ${callNum}`);
