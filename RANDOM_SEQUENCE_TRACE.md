# Complete Random Sequence Trace

## JavaScript Sequence (renderer-v3.js)

Starting with: `seed = hashCode(dna)`

### Call Order:

1. **Line 142 OR 182** (mutually exclusive):
   - `if (isKid)`: Line 142: `const eyeCount = 1 + Math.floor(random() * 3)`
   - `else`: Line 182: `const eyeCount = 1 + Math.floor(random() * 3)`

2. **Line 232**: `if (random() > 0.3)` - Mouth check (70% chance)

3. **Line 236** (only if mouth exists): `if (random() > 0.5)` - Extend mouth left

4. **Line 239** (only if mouth exists): `if (random() > 0.5)` - Extend mouth right

5. **Line 249** (only if hasCigarette): `cigChars[Math.floor(random() * cigChars.length)]` - Cigarette character

6. **Line 250** (only if hasCigarette): `random() > 0.5 ? 3 : -3` - Cigarette position

7. **Line 258**: `const armCount = 1 + Math.floor(random() * 4)`

8. **Line 259**:
   - If kid: `1 + Math.floor(random() * 2)`
   - If adult: `2 + Math.floor(random() * 4)`

9. **Line 290**: `const legCount = 1 + Math.floor(random() * 4)`

10. **Line 292**:
    - If kid: `1 + Math.floor(random() * 2)`
    - If adult: `2 + Math.floor(random() * 3)`

11. **Line 329**: `const antennaCount = 1 + Math.floor(random() * 4)`

12. **Line 330**:
    - If kid: `1` (constant, NO random call)
    - If adult: `1 + Math.floor(random() * 2)`

**CRITICAL: Line 330 for kids is `isKid ? 1` - NO RANDOM CALL!**

---

## Solidity Sequence (ProtocolitesRendererHybrid.sol)

Let me trace the exact lines:

### Call Order:

1. **Line 393 OR 461** (mutually exclusive):
   - `if (isKid)`: Line 393: `seed = _random(seed); uint256 eyeCount = 1 + (seed % 3)`
   - `else`: Line 461: `seed = _random(seed); uint256 adultEyeCount = 1 + (seed % 3)`

2. **Line 551**: `seed = _random(seed); if ((seed % 10) >= 3)` - Mouth check

3. **Line 558** (only if mouth exists): `seed = _random(seed); if ((seed % 2) == 0)` - Extend mouth left

4. **Line 563** (only if mouth exists): `seed = _random(seed); if ((seed % 2) == 0)` - Extend mouth right

5. **Line 576** (only if hasCigarette): `seed = _random(seed); uint256 cigCharIndex = seed % 3` - Cigarette character

6. **Line 581** (only if hasCigarette): `seed = _random(seed); bool cigRight = (seed % 2) == 0` - Cigarette position

7. **Line 597**: `seed = _random(seed); uint256 armCount = 1 + (seed % 4)`

8. **Line 599**:
   - If kid: `seed = _random(seed); 1 + (seed % 2)`
   - If adult: `seed = _random(seed); 2 + (seed % 4)`

9. **Line 642**: `seed = _random(seed); uint256 legCount = 1 + (seed % 4)`

10. **Line 644**:
    - If kid: `seed = _random(seed); 1 + (seed % 2)`
    - If adult: `seed = _random(seed); 2 + (seed % 3)`

11. **Line 705**: `seed = _random(seed); uint256 antennaCount = 1 + (seed % 4)`

12. **Line 707**:
    - If kid: `isKid ? 1` - NO RANDOM CALL
    - If adult: `seed = _random(seed); 1 + (seed % 2)`

---

## CRITICAL BUG: Seed Mismatch (FIXED)

**Problem:** The hashCode function must receive the **exact same string** in both JS and Solidity.

**JS receives:** `"0x0000000000000000000000000000000000000000000000001234567890abcdef"` (66 characters: 0x + 64 hex digits, padded with leading zeros)

**Solidity was using:** `LibString.toHexString(dna)` which produces variable-length strings without leading zeros like `"0x1234567890abcdef"` (18 characters)

**Result:** Different string lengths → different hash values → completely different random sequences!

**Fix:** Use `LibString.toHexString(dna, 32)` which produces a fixed 66-character padded hex string matching JS.

**Example:**
- Unpadded `"0x1234567890abcdef"` (18 chars) → hash = 2025415206
- Padded `"0x0000...001234567890abcdef"` (66 chars) → hash = 259309018
- These produce completely different random sequences!

---

## CRITICAL BUGS FOUND AND FIXED

### Bug 1: Ternary Operator Evaluation Order

**Problem:** In JavaScript, when you write:
```javascript
const value = condition ? funcA() : funcB();
```

The function is called INSIDE the ternary, so only ONE function gets called (short-circuit evaluation).

**Solidity Mistake:**
```solidity
seed = _random(seed);  // ❌ Called BEFORE ternary
uint256 value = condition ? (seed % 2) : (seed % 4);
```

This calls `_random()` once and uses the SAME seed value for both branches, but JS generates a NEW random number inside whichever branch is taken.

**Correct Solidity:**
```solidity
uint256 value;
if (condition) {
    seed = _random(seed);  // ✅ Called INSIDE branch
    value = seed % 2;
} else {
    seed = _random(seed);  // ✅ Called INSIDE branch
    value = seed % 4;
}
```

### Bug 2: Ternary with Constant Branch

**Problem:** In JavaScript:
```javascript
const value = isKid ? 1 : (1 + Math.floor(random() * 2));
```

If `isKid` is true, the ternary returns `1` immediately WITHOUT calling `random()`.

**Solidity Mistake:**
```solidity
seed = _random(seed);  // ❌ ALWAYS called, even for kids
uint256 value = isKid ? 1 : (1 + (seed % 2));
```

**Correct Solidity:**
```solidity
uint256 value;
if (isKid) {
    value = 1;  // ✅ No random call
} else {
    seed = _random(seed);  // ✅ Only called for adults
    value = 1 + (seed % 2);
}
```

---

## Fixed Locations

1. **Arms (line 600-608)**: Changed from ternary to if/else - both branches call random()
2. **Legs (line 652-660)**: Changed from ternary to if/else - both branches call random()
3. **Antennas (line 710-717)**: Changed to if/else - only adult branch calls random()

---

## Final Correct Sequence

### For KIDS (isKid = true):

1. Eye count: `random()` ✓
2. Mouth check: `random()` ✓
3. Mouth left: `random()` (if mouth) ✓
4. Mouth right: `random()` (if mouth) ✓
5. Cig char: `random()` (if has cigarette) ✓
6. Cig pos: `random()` (if has cigarette) ✓
7. Arm count: `random()` ✓
8. Arm length: `random()` ✓ (FIXED - was calling even for kids)
9. Leg count: `random()` ✓
10. Leg length: `random()` ✓ (FIXED - was calling even for kids)
11. Antenna count: `random()` ✓
12. Antenna length: **NO CALL** ✓ (FIXED - was incorrectly calling)

### For ADULTS (isKid = false):

1. Eye count: `random()` ✓
2. Mouth check: `random()` ✓
3. Mouth left: `random()` (if mouth) ✓
4. Mouth right: `random()` (if mouth) ✓
5. Cig char: `random()` (if has cigarette) ✓
6. Cig pos: `random()` (if has cigarette) ✓
7. Arm count: `random()` ✓
8. Arm length: `random()` ✓ (FIXED - now using fresh call)
9. Leg count: `random()` ✓
10. Leg length: `random()` ✓ (FIXED - now using fresh call)
11. Antenna count: `random()` ✓
12. Antenna length: `random()` ✓ (FIXED - now calling correctly)

**Result:** Now matches JS exactly! ✅

---

## Known Behavior: Arms Can Overlap Eyes

When an adult creature has `eyeCount=1` (mega eye with 3 eyes in center row) AND the first arm row coincides with the eye row (`bodyStartY + 2 == eyeY + 1`), the arms can overwrite the outer eyes.

**What happens:**
1. Eyes placed at (cx-1, eyeY+1), (cx, eyeY+1), (cx+1, eyeY+1)
2. Arms scan from center cx on same row
3. Center cell is eye (not body), so scan immediately stops
4. leftBodyEdge = rightBodyEdge = cx
5. Arms drawn from cx outward, overwriting eyes at cx-1 and cx+1
6. Only center eye at cx survives

This is **intentional behavior matching JS renderer** - both implementations have this quirk where arm rendering can overlap eye positions in this specific scenario.
