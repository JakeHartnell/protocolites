// Parse the HTML you provided to understand what it actually contains
const html = `<span class="creature-char" style="left: 120px; top: 80px; color: rgb(204, 0, 0); transform: none;">▀</span>`;

// Count each character type from your HTML
const chars = {
  '▀': 'top block',
  '▄': 'bottom block',
  '●': 'filled circle (antenna tip)',
  '◎': 'double circle (eye)',
  '░': 'light shade (body)',
  '─': 'horizontal line (arm)',
  '│': 'vertical line (leg)'
};

// I'll manually count from your HTML:
console.log("Characters in HTML output:");
console.log("▀ (hat top): 5 (at y=80)");
console.log("▄ (hat bottom): 5 (at y=100)");
console.log("● (antenna tip): 1 (at 144,120)");
console.log("░ (body): many");
console.log("─ (arms): many");
console.log("│ (legs): 4 at y=300,320");
console.log("");
console.log("◎ (eyes): NOT FOUND - this is the problem!");
console.log("");
console.log("This HTML appears to show a KID creature (1 antenna, simple layout)");
console.log("But isKid=false for tokenId 6!");
