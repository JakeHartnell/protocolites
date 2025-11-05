// Test what happens when arms are drawn on a row with eyes

const grid = Array(24).fill().map(() =>
  Array(24).fill().map(() => ({ char: ' ', type: 'empty' }))
);

const cx = 12;
const armY = 9;

// Simulate having eyes at the center
grid[armY][11] = { char: '◎', type: 'eye' };
grid[armY][12] = { char: '◎', type: 'eye' };
grid[armY][13] = { char: '◎', type: 'eye' };

// Put body cells on either side
for (let x = 6; x <= 10; x++) {
  grid[armY][x] = { char: '░', type: 'body' };
}
for (let x = 14; x <= 18; x++) {
  grid[armY][x] = { char: '░', type: 'body' };
}

console.log("Before arm rendering:");
console.log("Row", armY, ":");
for (let x = 6; x <= 18; x++) {
  console.log(`  [${x}]: ${grid[armY][x].char} (${grid[armY][x].type})`);
}

// Simulate JS arm rendering logic
const isBodyChar = c => c && c.type === "body";

let leftBodyEdge = cx, rightBodyEdge = cx;
console.log("\nScanning left from cx=" + cx);
for (let x = cx; x >= 0; x--) {
  console.log(`  Check [${x}]: type=${grid[armY][x].type}, isBody=${isBodyChar(grid[armY][x])}`);
  if (isBodyChar(grid[armY][x])) {
    leftBodyEdge = x;
  } else {
    console.log(`  -> Not body, break`);
    break;
  }
}
console.log("leftBodyEdge:", leftBodyEdge);

console.log("\nScanning right from cx=" + cx);
for (let x = cx; x < 24; x++) {
  console.log(`  Check [${x}]: type=${grid[armY][x].type}, isBody=${isBodyChar(grid[armY][x])}`);
  if (isBodyChar(grid[armY][x])) {
    rightBodyEdge = x;
  } else {
    console.log(`  -> Not body, break`);
    break;
  }
}
console.log("rightBodyEdge:", rightBodyEdge);

// Draw arms
const armChar = '─';
const armLength = 4;
console.log("\nDrawing arms with armLength=" + armLength);
for (let i = 1; i <= armLength; i++) {
  if (leftBodyEdge - i >= 0) {
    console.log(`  Left arm at [${leftBodyEdge - i}]`);
    grid[armY][leftBodyEdge - i] = { char: armChar, type: 'arm' };
  }
  if (rightBodyEdge + i < 24) {
    console.log(`  Right arm at [${rightBodyEdge + i}]`);
    grid[armY][rightBodyEdge + i] = { char: armChar, type: 'arm' };
  }
}

console.log("\nAfter arm rendering:");
console.log("Row", armY, ":");
for (let x = 6; x <= 18; x++) {
  console.log(`  [${x}]: ${grid[armY][x].char} (${grid[armY][x].type})`);
}
