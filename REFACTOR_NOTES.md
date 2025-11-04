# Renderer Refactor Notes

## Date: 2025-11-03

## Problem
The static SVG renderer (`ProtocolitesRendererHybrid.sol`) and the JS animation renderer (`renderer-v3.js`) were producing visually different creatures despite using the same DNA. This was particularly noticeable with non-rectangular body shapes (mushroom, invader, ghost).

## Root Cause
The Solidity renderer was using fixed mathematical positions based on `bodyWidth` constants for placing arms, legs, and antennas. This assumed all body shapes were symmetrical rectangles.

The JS renderer actually scans the rendered grid to find where body cells exist, then places appendages relative to the actual body shape.

For asymmetric bodies like:
- **Mushroom**: Narrow stem at bottom
- **Invader**: Stepped edges
- **Ghost**: Wavy bottom

...the fixed positions caused arms/legs/antennas to float or be misplaced.

## Solution
Refactored the Solidity renderer to match the JS renderer's logic:

1. **Track body positions**: Store all (x,y) coordinates where body cells are rendered
2. **Scan for arms**: For each arm row, find the leftmost and rightmost body cells
3. **Scan for legs**: Find all body cells at the bottom row, select positions based on leg count
4. **Scan for antennas**: Find all body cells at the top row, select positions based on antenna count

## Changes Made

### `renderAnimatedCreature()` function:
- Added `bodyPositions` array to track all body cell coordinates
- Pack positions as `(y << 128) | x` for efficient storage
- Arms section now scans `bodyPositions` for edges at each arm row
- Legs section scans bottom row positions and selects based on percentage (25%, 50%, 75%, etc.)
- Antennas section scans top row positions and selects similarly

## Additional Fixes (2nd Pass)

### Arithmetic Overflow Issues (Panic Code 17)
After initial deployment, discovered multiple uint256 underflow issues:

1. **Hat rendering** (lines 701-749): `cx - 2 + dx` would underflow when `cx < 2`
   - Fixed: Added `cx >= 2` checks before all hat rendering
   - Compute `hatX = cx - 2 + dx` in temporary variable after bounds check

2. **Kid eyes (3-eye case)** (line 378): `cx - 2` would underflow
   - Fixed: Changed `else` to `else if (cx >= 2)`

3. **Adult mega eye** (lines 392-409): `cx - 2 + dx` iterations
   - Fixed: Added `cx >= 2` check and temporary variable

4. **Adult 2-eye case** (lines 410-449): `cx - blockSpacing - 2 + dx` = `cx - 4`
   - Fixed: Added `cx >= 4` check

5. **Adult 3-eye case** (lines 450-463): `int256(cx) + i - 1` where i=-3 means `cx - 4`
   - Fixed: Added `cx >= 4` check

6. **Antenna rendering** (line 686): `bodyStartY - i` could underflow
   - Fixed: Check `if (bodyStartY >= i)` before subtraction

7. **Hat Y position** (line 700): `bodyStartY - antennaLength - 1` could underflow
   - Fixed: Check `bodyStartY > antennaLength` before rendering hat

8. **Leg/Antenna array indexing**: Percentage-based calculations like `(bottomCount * 25) / 100` could exceed array bounds
   - Fixed: Added fallback logic for small counts with ternary operators

## Testing
Created `TestRendererRefactor.t.sol` to verify:
- Contract compiles and deploys
- SVG generation works for both kids and spreaders
- All 6 body types render without errors
- Edge case DNA values (0x0, max uint, various patterns) don't cause overflows
- Both kid and adult sizes work with all test cases

## Expected Result
Static SVG images should now match the JS-rendered creatures exactly (minus animations).
All NFTs should render without panic code 17 arithmetic overflow errors.
