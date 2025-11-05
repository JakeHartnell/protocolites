// Visual Diff Tool: Compare JS renderer output with Solidity output
const fs = require('fs');

// Test DNA
const tokenId = 1;
const dna = "0x0000000000000000000000000000000000000000000000000000000000000001";
const isKid = true;
const size = 16;

// Run the full JS renderer
const rendererV3 = fs.readFileSync('./renderer-v3.js', 'utf8');

// Execute renderer
eval(rendererV3);

// Convert grid to string for comparison
function gridToString(grid) {
  let result = '';
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      result += grid[y][x].char || ' ';
    }
    result += '\n';
  }
  return result;
}

// Convert grid to detailed format
function gridToDetailed(grid) {
  const details = [];
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const cell = grid[y][x];
      if (cell.char !== ' ' && cell.type !== 'empty') {
        details.push({
          x, y,
          char: cell.char,
          type: cell.type,
          charCode: cell.char.charCodeAt(0).toString(16)
        });
      }
    }
  }
  return details;
}

console.log("=== JS RENDERER OUTPUT ===\n");
console.log(gridToString(grid));
console.log("\n=== DETAILED GRID ===");
const details = gridToDetailed(grid);
details.forEach(d => {
  console.log(`(${d.x},${d.y}): '${d.char}' [U+${d.charCode}] type=${d.type}`);
});

// Save for comparison
fs.writeFileSync('./js-output.txt', gridToString(grid));
fs.writeFileSync('./js-output-detailed.json', JSON.stringify(details, null, 2));

console.log("\n\nJS output saved to js-output.txt and js-output-detailed.json");
console.log("\nNow run the Solidity test and compare outputs:");
console.log("  cd solidity && forge test --match-test testRenderCreature -vvv");
