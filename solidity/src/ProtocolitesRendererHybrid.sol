// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solady/utils/Base64.sol";
import "solady/utils/LibString.sol";
import "solady/auth/Ownable.sol";
import "solady/utils/SSTORE2.sol";
import "solady/utils/FixedPointMathLib.sol";
import "solady/utils/SafeCastLib.sol";

import "./interfaces/IProtocolitesRenderer.sol";

/// @title ProtocolitesRendererHybrid
/// @notice Hybrid renderer with static SVG and optional JavaScript animations
/// @dev Supports both static SVG images and animated HTML with JavaScript, uses Solady math libraries
contract ProtocolitesRendererHybrid is Ownable, IProtocolitesRenderer {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;

    address private renderScriptPointer;

    /// @dev Scale factor for fixed-point math (matches JS decimal precision)
    int256 private constant SCALE = 1000;

    constructor() {
        _initializeOwner(msg.sender);
    }

    function setRenderScript(string memory _script) external onlyOwner {
        renderScriptPointer = SSTORE2.write(bytes(_script));
    }

    function renderScript() public view returns (string memory) {
        if (renderScriptPointer == address(0)) return "";
        return string(SSTORE2.read(renderScriptPointer));
    }

    function tokenURI(uint256 tokenId, TokenData memory data) external view returns (string memory) {
        return string.concat("data:application/json;base64,", Base64.encode(bytes(metadata(tokenId, data))));
    }

    function metadata(uint256 tokenId, TokenData memory data) public view returns (string memory) {
        bool isKid = data.isKid;
        uint256 size = isKid ? 16 : 24;

        // Generate static SVG
        string memory svg = generateSVG(tokenId, data);
        string memory imageData = string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(svg)));

        // Generate animated HTML page if script is available
        string memory animationUrl = "";
        if (renderScriptPointer != address(0)) {
            string memory animation = string.concat(
                '<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">',
                "<title>Protocolite #",
                LibString.toString(tokenId),
                "</title>",
                '<style>@import url("https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@100;200;300;400&display=swap");',
                "*{margin:0;padding:0;box-sizing:border-box;}",
                "html,body{width:100%;height:100%;margin:0;padding:0;min-width:600px;min-height:600px;}",
                'body{font-family:"JetBrains Mono","Courier New",monospace;background:#fff;color:#000;line-height:1;font-size:12px;font-weight:200;display:flex;align-items:center;justify-content:center;overflow:hidden;}',
                ".container{text-align:center;padding:",
                isKid ? "20" : "30",
                "px;position:relative;}",
                ".creature-container{position:relative;display:inline-block;font-family:'Courier New',monospace;line-height:1;-webkit-font-smoothing:none;-moz-osx-font-smoothing:unset;font-smooth:never;text-rendering:optimizeSpeed;}",
                ".creature-char{position:absolute;font-family:'Courier New',monospace;white-space:pre;user-select:none;pointer-events:none;will-change:transform;}",
                "</style></head><body>",
                '<div class="container"><div class="creature-container" id="creature"></div></div>',
                "<script>",
                "const tokenId=",
                LibString.toString(tokenId),
                ";",
                'const dna="',
                LibString.toHexString(data.dna),
                '";',
                "const isKid=",
                isKid ? "true" : "false",
                ";",
                'const parentDna="',
                LibString.toHexString(data.parentDna),
                '";',
                "const size=",
                LibString.toString(size),
                ";",
                renderScript(),
                "</script>",
                "</body></html>"
            );
            animationUrl = string.concat('"animation_url":"data:text/html;base64,', Base64.encode(bytes(animation)), '",');
        }

        string memory attributes = string.concat(
            '[{"trait_type":"Type","value":"',
            isKid ? "Child" : "Spreader",
            '"},',
            '{"trait_type":"Size","value":"',
            LibString.toString(size),
            "x",
            LibString.toString(size),
            '"},',
            '{"trait_type":"DNA","value":"',
            LibString.toHexString(data.dna),
            '"},',
            '{"trait_type":"Birth Block","value":',
            LibString.toString(data.birthBlock),
            "}",
            isKid
                ? string.concat(',{"trait_type":"Parent DNA","value":"', LibString.toHexString(data.parentDna), '"}')
                : "",
            "]"
        );

        string memory json = string.concat(
            '{"name":"Protocolite #',
            LibString.toString(tokenId),
            isKid ? " (Child)" : " (Spreader)",
            '",',
            '"description":"Fully on-chain generative ASCII art with hybrid SVG/JS rendering.",',
            '"image":"',
            imageData,
            '",',
            animationUrl,
            '"attributes":',
            attributes,
            "}"
        );

        return json;
    }

    /// @notice Generates a static SVG with CSS animations for the Protocolite
    /// @param tokenId The token ID (used for animation seeding)
    /// @param data The token data
    /// @return SVG markup as a string
    function generateSVG(uint256 tokenId, TokenData memory data) public pure returns (string memory) {
        bool isKid = data.isKid;
        uint256 size = isKid ? 16 : 24;
        uint256 dna = data.dna;

        // Decode DNA to get traits
        string memory familyColor = getFamilyColor(dna);

        // Initialize seed from DNA hash (match JS renderer's hashCode function)
        // JS: hashCode(dna) then uses LCG: (seed * 9301 + 49297) % 233280
        // We need to match this exactly for same random sequence
        uint256 seed = _hashCode(dna);
        uint256 tempIndex = getTemperament(seed);

        // Calculate SVG dimensions (match JS renderer spacing)
        uint256 fontSize = size == 24 ? 20 : 16;
        uint256 charWidth = (fontSize * 6) / 10; // fontSize * 0.6
        uint256 charHeight = fontSize;
        uint256 creatureWidth = size * charWidth;
        uint256 creatureHeight = size * charHeight;

        // Use square viewBox (max dimension) to prevent aspect ratio distortion
        uint256 maxDim = creatureWidth > creatureHeight ? creatureWidth : creatureHeight;

        // Center creature in square viewBox
        uint256 xOffset = (maxDim - creatureWidth) / 2;
        uint256 yOffset = (maxDim - creatureHeight) / 2;

        // Generate creature parts
        string memory creature = renderAnimatedCreature(dna, isKid, seed, charWidth, charHeight, xOffset, yOffset);

        // Build CSS animations
        string memory animations = buildAnimations(tempIndex, familyColor, fontSize);

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ',
            LibString.toString(maxDim),
            " ",
            LibString.toString(maxDim),
            '" width="100%" height="100%" preserveAspectRatio="xMidYMid meet" style="background:#fff">',
            "<defs><style>",
            animations,
            "</style></defs>",
            creature,
            "</svg>"
        );
    }

    /// @notice Hash function matching JS renderer's hashCode
    /// @dev Implements: h = ((h << 5) - h) + s.charCodeAt(i); h &= h;
    function _hashCode(uint256 dna) private pure returns (uint256) {
        // Convert dna to 66-character hex string (0x + 64 hex digits) to match JS input
        // JS receives DNA as full padded hex string from tokenURI HTML
        string memory dnaStr = LibString.toHexString(dna, 32); // 32 bytes = 64 hex chars
        bytes memory dnaBytes = bytes(dnaStr);

        int256 h = 0;
        for (uint256 i = 0; i < dnaBytes.length; i++) {
            unchecked {
                h = ((h << 5) - h) + uint256(uint8(dnaBytes[i])).toInt256();
                h = h & h; // Bitwise AND with itself (no-op but matches JS)
            }
        }

        // Return absolute value
        return (h < 0 ? -h : h).toUint256();
    }

    /// @notice Build CSS styles (animations removed)
    function buildAnimations(uint256 tempIndex, string memory color, uint256 fontSize) private pure returns (string memory) {
        // Base styles only - no animations
        // CRITICAL: Use monospace with explicit letter-spacing to match HTML character width
        return string.concat(
            "text{font-family:'Courier New',monospace;font-size:",
            LibString.toString(fontSize),
            "px;font-weight:400;fill:",
            color,
            ";dominant-baseline:text-before-edge;text-anchor:start;letter-spacing:0px;word-spacing:0px}"
        );
    }

    /// @notice Get temperament index from seed (weighted probability)
    function getTemperament(uint256 seed) private pure returns (uint256) {
        // Weights: [35, 30, 20, 10, 4, 1] (total=100)
        uint256 roll = seed % 100;
        if (roll < 35) return 0; // calm
        if (roll < 65) return 1; // balanced
        if (roll < 85) return 2; // energetic
        if (roll < 95) return 3; // chaotic
        if (roll < 99) return 4; // glitchy
        return 5; // unstable
    }

    function getFamilyColor(uint256 dna) private pure returns (string memory) {
        uint256 familyBits = dna >> 17;
        uint256 colorIndex = (familyBits % 16777216) % 6;
        if (colorIndex == 0) return "#cc0000";
        if (colorIndex == 1) return "#008800";
        if (colorIndex == 2) return "#0044cc";
        if (colorIndex == 3) return "#cc9900";
        if (colorIndex == 4) return "#8800cc";
        return "#0088aa";
    }

    function getBodyChar(uint256 charIndex) private pure returns (string memory) {
        if (charIndex == 0) return unicode"█"; // U+2588 Full Block
        if (charIndex == 1) return unicode"▓"; // U+2593 Dark Shade
        if (charIndex == 2) return unicode"▒"; // U+2592 Medium Shade
        return unicode"░"; // U+2591 Light Shade
    }

    function getEyeChar(uint256 charIndex) private pure returns (string memory) {
        if (charIndex == 0) return unicode"●"; // U+25CF Black Circle
        if (charIndex == 1) return unicode"◉"; // U+25C9 Fisheye
        if (charIndex == 2) return unicode"◎"; // U+25CE Bullseye
        return unicode"○"; // U+25CB White Circle
    }

    function getAntennaTip(uint256 tipIndex) private pure returns (string memory) {
        tipIndex = tipIndex % 7;
        if (tipIndex == 0) return unicode"●"; // U+25CF Black Circle
        if (tipIndex == 1) return unicode"◉"; // U+25C9 Fisheye
        if (tipIndex == 2) return unicode"○"; // U+25CB White Circle
        if (tipIndex == 3) return unicode"◎"; // U+25CE Bullseye
        if (tipIndex == 4) return unicode"✦"; // U+2726 Black Four Pointed Star
        if (tipIndex == 5) return unicode"✧"; // U+2727 White Four Pointed Star
        return unicode"★"; // U+2605 Black Star
    }

    /// @notice Grid cell structure for grid-based rendering
    /// @dev Matches renderer-v3.js grid approach: { char: string, type: string }
    struct GridCell {
        string char;
        string cellType; // "empty", "body", "eye", "mouth", "cigarette", "arm", "leg", "antenna", "antenna-tip", "hat"
    }

    /// @notice Initialize empty grid
    /// @param size Grid size (16 for kids, 24 for adults)
    /// @return grid 2D array of GridCell initialized to empty spaces
    function _initializeGrid(uint256 size) private pure returns (GridCell[][] memory grid) {
        grid = new GridCell[][](size);
        for (uint256 i = 0; i < size; i++) {
            grid[i] = new GridCell[](size);
            for (uint256 j = 0; j < size; j++) {
                grid[i][j] = GridCell(" ", "empty");
            }
        }
    }

    /// @notice Check if grid cell contains body character
    /// @param cell Grid cell to check
    /// @return true if cell type is "body"
    function _isBodyCell(GridCell memory cell) private pure returns (bool) {
        return keccak256(bytes(cell.cellType)) == keccak256(bytes("body"));
    }

    /// @notice Check if grid cell is empty
    /// @param cell Grid cell to check
    /// @return true if cell type is "empty"
    function _isEmptyCell(GridCell memory cell) private pure returns (bool) {
        return keccak256(bytes(cell.cellType)) == keccak256(bytes("empty"));
    }

    /// @notice Set grid cell with bounds checking
    /// @param grid The grid to modify
    /// @param x X coordinate
    /// @param y Y coordinate
    /// @param char Character to set
    /// @param cellType Type of cell
    /// @param size Grid size for bounds checking
    function _setGridCell(GridCell[][] memory grid, uint256 x, uint256 y, string memory char, string memory cellType, uint256 size)
        private
        pure
    {
        if (x < size && y < size) {
            grid[y][x] = GridCell(char, cellType);
        }
    }

    /// @notice Convert grid to SVG text elements
    /// @param grid The grid to convert
    /// @param size Grid size
    /// @param charWidth Character width in pixels
    /// @param charHeight Character height in pixels
    /// @param xOffset X offset for positioning
    /// @param yOffset Y offset for positioning
    /// @return SVG text elements as concatenated string
    function _gridToSVG(GridCell[][] memory grid, uint256 size, uint256 charWidth, uint256 charHeight, uint256 xOffset, uint256 yOffset)
        private
        pure
        returns (string memory)
    {
        string memory result = "";
        for (uint256 y = 0; y < size; y++) {
            for (uint256 x = 0; x < size; x++) {
                if (!_isEmptyCell(grid[y][x])) {
                    result = string.concat(
                        result,
                        _renderTextWithClass(x, y, grid[y][x].char, grid[y][x].cellType, charWidth, charHeight, xOffset, yOffset)
                    );
                }
            }
        }
        return result;
    }

    function renderAnimatedCreature(uint256 dna, bool isKid, uint256 seed, uint256 charWidth, uint256 charHeight, uint256 xOffset, uint256 yOffset)
        private
        pure
        returns (string memory)
    {
        uint256 size = isKid ? 16 : 24;
        uint256 cx = size / 2;

        uint256 bodyType = (dna >> 0) & 0x7;
        if (bodyType >= 6) bodyType = bodyType % 6;

        string memory bodyChar = getBodyChar((dna >> 3) & 0x3);
        string memory eyeChar = getEyeChar((dna >> 5) & 0x3);
        bool megaEyes = ((dna >> 7) & 0x1) == 1;
        string memory antennaTip = getAntennaTip((dna >> 8) & 0x7);
        bool lineArms = ((dna >> 11) & 0x1) == 1; // 1 = line style (inverted from blockArms)
        bool lineLegs = ((dna >> 12) & 0x1) == 1; // 1 = line style (inverted from blockLegs)
        uint256 hatType = ((dna >> 13) & 0x7) % 5;
        bool hasCigarette = ((dna >> 16) & 0x1) == 1;

        uint256 bodyWidth = size == 24 ? 6 : 3;
        uint256 bodyHeight = size == 24 ? 8 : 4;
        uint256 bodyStartY = size == 24 ? 7 : 6;

        // Initialize grid (matching renderer-v3.js grid-based approach)
        GridCell[][] memory grid = _initializeGrid(size);

        // Render body to grid (matching renderer-v3.js exactly)
        for (uint256 y = 0; y < bodyHeight; y++) {
            for (int256 x = -bodyWidth.toInt256(); x <= bodyWidth.toInt256(); x++) {
                uint256 posY = bodyStartY + y;
                int256 posX = cx.toInt256() + x;
                if (posX < 0 || posX >= size.toInt256()) continue;

                // Calculate normalized coordinates: relX and relY in range [-1.0, 1.0] scaled by 1000
                // JS: relX = x / bodyWidth, relY = (y - bodyHeight/2) / (bodyHeight/2)
                int256 relX = _mulDiv(x, SCALE, bodyWidth.toInt256());
                int256 halfHeight = bodyHeight.toInt256() / 2;
                int256 relY = _mulDiv(y.toInt256() - halfHeight, SCALE, halfHeight);

                bool inBody = _isInBody(bodyType, relX, relY, isKid, x, bodyWidth);

                if (inBody) {
                    grid[posY][posX.toUint256()] = GridCell(bodyChar, "body");
                }
            }
        }

        // Eyes with proper grid clearing (matching renderer-v3.js lines 140-230)
        uint256 eyeY = bodyStartY + 1;

        if (isKid) {
            // Kid eyes (JS line 142 calls random() inside kid branch)
            seed = _random(seed);
            uint256 eyeCount = 1 + (seed % 3);
            if (eyeCount == 1) {
                // Clear 3x2 area for single eye socket
                for (uint256 dy = 0; dy < 2; dy++) {
                    for (int256 dx = -1; dx <= 1; dx++) {
                        int256 eyeX = int256(cx) + dx;
                        if (eyeX >= 0 && eyeX < int256(size) && eyeY + dy < size) {
                            if (_isBodyCell(grid[eyeY + dy][uint256(eyeX)])) {
                                grid[eyeY + dy][uint256(eyeX)] = GridCell(" ", "empty");
                            }
                        }
                    }
                }
                // Rebuild eye socket structure
                if (cx >= 1 && cx + 1 < size) {
                    grid[eyeY][cx - 1] = GridCell(bodyChar, "body");
                    grid[eyeY][cx] = GridCell(eyeChar, "eye");
                    grid[eyeY][cx + 1] = GridCell(bodyChar, "body");
                    grid[eyeY + 1][cx] = GridCell(bodyChar, "body");
                }
            } else if (eyeCount == 2) {
                uint256 eyeSpacing = 1;
                // Clear 2x2 areas for both eyes
                for (uint256 dy = 0; dy < 2; dy++) {
                    for (uint256 dx = 0; dx < 2; dx++) {
                        // Left eye area
                        if (cx >= eyeSpacing + 1 && cx - eyeSpacing - 1 + dx < size && eyeY + dy < size) {
                            if (_isBodyCell(grid[eyeY + dy][cx - eyeSpacing - 1 + dx])) {
                                grid[eyeY + dy][cx - eyeSpacing - 1 + dx] = GridCell(" ", "empty");
                            }
                        }
                        // Right eye area
                        if (cx + eyeSpacing + dx < size && eyeY + dy < size) {
                            if (_isBodyCell(grid[eyeY + dy][cx + eyeSpacing + dx])) {
                                grid[eyeY + dy][cx + eyeSpacing + dx] = GridCell(" ", "empty");
                            }
                        }
                    }
                }
                // Rebuild left eye socket
                if (cx >= eyeSpacing + 1) {
                    grid[eyeY][cx - eyeSpacing - 1] = GridCell(bodyChar, "body");
                    grid[eyeY][cx - eyeSpacing] = GridCell(eyeChar, "eye");
                    grid[eyeY + 1][cx - eyeSpacing - 1] = GridCell(bodyChar, "body");
                    grid[eyeY + 1][cx - eyeSpacing] = GridCell(bodyChar, "body");
                }
                // Rebuild right eye socket
                if (cx + eyeSpacing + 1 < size) {
                    grid[eyeY][cx + eyeSpacing] = GridCell(eyeChar, "eye");
                    grid[eyeY][cx + eyeSpacing + 1] = GridCell(bodyChar, "body");
                    grid[eyeY + 1][cx + eyeSpacing] = GridCell(bodyChar, "body");
                    grid[eyeY + 1][cx + eyeSpacing + 1] = GridCell(bodyChar, "body");
                }
            } else {
                // 3 eyes - clear and place (renderer-v3.js lines 176-180)
                for (int256 dx = -2; dx <= 2; dx += 2) {
                    int256 eyeX = int256(cx) + dx;
                    if (eyeX >= 0 && eyeX < int256(size) && eyeY < size) {
                        uint256 eyeXu = uint256(eyeX);
                        if (_isBodyCell(grid[eyeY][eyeXu])) {
                            grid[eyeY][eyeXu] = GridCell(" ", "empty");
                        }
                        grid[eyeY][eyeXu] = GridCell(eyeChar, "eye");
                    }
                }
            }
        } else {
            // Adult eyes (JS line 182 calls random() again in else branch)
            seed = _random(seed);
            uint256 adultEyeCount = 1 + (seed % 3);

            if (adultEyeCount == 1) {
                // Mega eye: clear 5x3 area, rebuild structure (renderer-v3.js lines 184-199)
                for (uint256 dy = 0; dy < 3; dy++) {
                    for (int256 dx = -2; dx <= 2; dx++) {
                        int256 eyeX = int256(cx) + dx;
                        if (eyeX >= 0 && eyeX < int256(size) && eyeY + dy < size) {
                            uint256 eyeXu = uint256(eyeX);
                            if (_isBodyCell(grid[eyeY + dy][eyeXu])) {
                                grid[eyeY + dy][eyeXu] = GridCell(" ", "empty");
                            }
                        }
                    }
                }
                // Rebuild mega eye structure
                if (cx >= 2 && cx + 2 < size && eyeY + 2 < size) {
                    for (int256 dx = -2; dx <= 2; dx++) {
                        uint256 eyeXu = (int256(cx) + dx).toUint256();
                        grid[eyeY][eyeXu] = GridCell(bodyChar, "body");
                        grid[eyeY + 2][eyeXu] = GridCell(bodyChar, "body");
                    }
                    grid[eyeY + 1][cx - 2] = GridCell(bodyChar, "body");
                    grid[eyeY + 1][cx - 1] = GridCell(eyeChar, "eye");
                    grid[eyeY + 1][cx] = GridCell(eyeChar, "eye");
                    grid[eyeY + 1][cx + 1] = GridCell(eyeChar, "eye");
                    grid[eyeY + 1][cx + 2] = GridCell(bodyChar, "body");
                }
            } else if (adultEyeCount == 2) {
                // Two 3x3 eye sockets (renderer-v3.js lines 201-218)
                uint256 blockSpacing = 2;
                // Clear and rebuild both 3x3 blocks
                for (uint256 dy = 0; dy < 3; dy++) {
                    for (uint256 dx = 0; dx < 3; dx++) {
                        // Left eye
                        if (cx >= blockSpacing + 2 && cx - blockSpacing - 2 + dx < size && eyeY + dy < size) {
                            if (_isBodyCell(grid[eyeY + dy][cx - blockSpacing - 2 + dx])) {
                                grid[eyeY + dy][cx - blockSpacing - 2 + dx] = GridCell(" ", "empty");
                            }
                            bool isCenter = dy == 1 && dx == 1;
                            grid[eyeY + dy][cx - blockSpacing - 2 + dx] = GridCell(
                                isCenter ? eyeChar : bodyChar,
                                isCenter ? "eye" : "body"
                            );
                        }
                        // Right eye
                        if (cx + blockSpacing + dx < size && eyeY + dy < size) {
                            if (_isBodyCell(grid[eyeY + dy][cx + blockSpacing + dx])) {
                                grid[eyeY + dy][cx + blockSpacing + dx] = GridCell(" ", "empty");
                            }
                            bool isCenter = dy == 1 && dx == 1;
                            grid[eyeY + dy][cx + blockSpacing + dx] = GridCell(
                                isCenter ? eyeChar : bodyChar,
                                isCenter ? "eye" : "body"
                            );
                        }
                    }
                }
            } else {
                // 3 eyes with 2x2 blocks (renderer-v3.js lines 220-230)
                // JS places eyes at cx+i-1 and cx+i for i = -3, 0, 3
                for (int256 i = -3; i <= 3; i += 3) {
                    for (uint256 dy = 0; dy < 2; dy++) {
                        // Place at cx + i - 1
                        int256 eyeX1 = int256(cx) + i - 1;
                        if (eyeX1 >= 0 && eyeX1 < int256(size) && eyeY + dy < size) {
                            uint256 eyeXu = uint256(eyeX1);
                            if (_isBodyCell(grid[eyeY + dy][eyeXu])) {
                                grid[eyeY + dy][eyeXu] = GridCell(" ", "empty");
                            }
                            grid[eyeY + dy][eyeXu] = GridCell(eyeChar, "eye");
                        }

                        // Place at cx + i
                        int256 eyeX2 = int256(cx) + i;
                        if (eyeX2 >= 0 && eyeX2 < int256(size) && eyeY + dy < size) {
                            uint256 eyeXu = uint256(eyeX2);
                            if (_isBodyCell(grid[eyeY + dy][eyeXu])) {
                                grid[eyeY + dy][eyeXu] = GridCell(" ", "empty");
                            }
                            grid[eyeY + dy][eyeXu] = GridCell(eyeChar, "eye");
                        }
                    }
                }
            }
        }

        // Mouth (matching renderer-v3.js lines 232-243)
        seed = _random(seed);
        if ((seed % 10) >= 3) {
            uint256 mouthY = eyeY + (isKid ? 2 : 3);
            // Only place mouth where body exists (critical fix)
            if (mouthY < size && _isBodyCell(grid[mouthY][cx])) {
                grid[mouthY][cx] = GridCell(unicode"─", "mouth");

                seed = _random(seed);
                if ((seed % 2) == 0 && cx > 0 && _isBodyCell(grid[mouthY][cx - 1])) {
                    grid[mouthY][cx - 1] = GridCell(unicode"─", "mouth");
                }

                seed = _random(seed);
                if ((seed % 2) == 0 && cx + 1 < size && _isBodyCell(grid[mouthY][cx + 1])) {
                    grid[mouthY][cx + 1] = GridCell(unicode"─", "mouth");
                }
            }
        }

        // Cigarette (matching renderer-v3.js lines 245-255)
        // IMPORTANT: JS calls random() for char FIRST (line 249), then position (line 250)
        if (hasCigarette) {
            uint256 cigY = eyeY + (isKid ? 2 : 3);

            // Get cigarette character first (JS line 249)
            seed = _random(seed);
            uint256 cigCharIndex = seed % 3;
            string memory cigChar = cigCharIndex == 0 ? unicode"≈" : (cigCharIndex == 1 ? unicode"∼" : "~");

            // Then get position (JS line 250)
            seed = _random(seed);
            bool cigRight = (seed % 2) == 0;
            int256 cigOffset = cigRight ? int256(3) : int256(-3);
            int256 cigXint = int256(cx) + cigOffset;

            if (cigXint >= 0 && cigXint < int256(size) && cigY < size) {
                uint256 cigX = uint256(cigXint);
                grid[cigY][cigX] = GridCell(cigChar, "cigarette");

                if (cigX + 1 < size) {
                    grid[cigY][cigX + 1] = GridCell(unicode"∙", "cigarette");
                }
            }
        }

        // Arms - scan from center outward (matching renderer-v3.js lines 257-281)
        seed = _random(seed);
        uint256 armCount = 1 + (seed % 4);
        // JS line 259: random() called INSIDE ternary (different call for kid vs adult)
        uint256 armLength;
        if (isKid) {
            seed = _random(seed);
            armLength = 1 + (seed % 2);
        } else {
            seed = _random(seed);
            armLength = 2 + (seed % 4);
        }
        string memory armChar = lineArms ? unicode"─" : unicode"█";

        for (uint256 a = 0; a < armCount; a++) {
            uint256 currentArmY = bodyStartY + 2 + a * (isKid ? 1 : 2);
            if (currentArmY >= bodyStartY + bodyHeight || currentArmY >= size) break;

            // Scan from center outward to find body edges (like JS)
            uint256 leftBodyEdge = cx;
            uint256 rightBodyEdge = cx;

            // Scan left from center until hitting non-body
            for (uint256 x = cx; ; x--) {
                if (_isBodyCell(grid[currentArmY][x])) {
                    leftBodyEdge = x;
                } else {
                    break;
                }
                if (x == 0) break; // Prevent underflow
            }

            // Scan right from center until hitting non-body
            for (uint256 x = cx; x < size; x++) {
                if (_isBodyCell(grid[currentArmY][x])) {
                    rightBodyEdge = x;
                } else {
                    break;
                }
            }

            // Draw arms extending from body edges
            // NOTE: This matches JS behavior which can overwrite eyes when center is not body
            for (uint256 i = 1; i <= armLength; i++) {
                if (leftBodyEdge >= i) {
                    grid[currentArmY][leftBodyEdge - i] = GridCell(armChar, "arm");
                }
                if (rightBodyEdge + i < size) {
                    grid[currentArmY][rightBodyEdge + i] = GridCell(armChar, "arm");
                }
            }
        }

        // Legs - scan grid for body bottom positions (matching renderer-v3.js lines 283-324)
        seed = _random(seed);
        uint256 legCount = 1 + (seed % 4);
        // JS line 292: random() called INSIDE ternary (different call for kid vs adult)
        uint256 legLength;
        if (isKid) {
            seed = _random(seed);
            legLength = 1 + (seed % 2);
        } else {
            seed = _random(seed);
            legLength = 2 + (seed % 3);
        }
        string memory legChar = lineLegs ? unicode"│" : unicode"█";
        uint256 legY = bodyStartY + bodyHeight;

        // Collect all X positions where body exists at the bottom row
        uint256[] memory bodyBottomPositions = new uint256[](size);
        uint256 bottomCount = 0;
        if (legY > 0 && legY - 1 < size) {
            for (uint256 x = 0; x < size; x++) {
                if (_isBodyCell(grid[legY - 1][x])) {
                    bodyBottomPositions[bottomCount] = x;
                    bottomCount++;
                }
            }
        }

        // Select leg positions based on count
        if (bottomCount > 0) {
            uint256[] memory legPositions = new uint256[](4);
            uint256 legPosCount = 0;

            if (legCount == 1) {
                legPositions[0] = bodyBottomPositions[bottomCount / 2];
                legPosCount = 1;
            } else if (legCount == 2) {
                // Match JS: Math.floor(length * 0.25) and Math.floor(length * 0.75)
                uint256 idx1 = (bottomCount * 1) / 4;
                uint256 idx2 = (bottomCount * 3) / 4;
                legPositions[0] = bodyBottomPositions[idx1];
                legPositions[1] = bodyBottomPositions[idx2];
                legPosCount = 2;
            } else if (legCount == 3) {
                legPositions[0] = bodyBottomPositions[0];
                legPositions[1] = bodyBottomPositions[bottomCount / 2];
                legPositions[2] = bodyBottomPositions[bottomCount - 1];
                legPosCount = 3;
            } else {
                uint256 idx1 = 0;
                uint256 idx2 = (bottomCount > 3) ? (bottomCount / 3) : (bottomCount > 1 ? 1 : 0);
                uint256 idx3 = (bottomCount > 3) ? (bottomCount * 2 / 3) : (bottomCount > 2 ? 2 : (bottomCount > 1 ? 1 : 0));
                uint256 idx4 = bottomCount > 1 ? bottomCount - 1 : 0;
                legPositions[0] = bodyBottomPositions[idx1];
                legPositions[1] = bodyBottomPositions[idx2];
                legPositions[2] = bodyBottomPositions[idx3];
                legPositions[3] = bodyBottomPositions[idx4];
                legPosCount = 4;
            }

            // Draw legs
            for (uint256 l = 0; l < legPosCount; l++) {
                uint256 legX = legPositions[l];
                if (legX < size) {
                    for (uint256 i = 0; i < legLength; i++) {
                        if (legY + i < size) {
                            grid[legY + i][legX] = GridCell(legChar, "leg");
                        }
                    }
                }
            }
        }

        // Antennas - scan grid for body top positions (matching renderer-v3.js lines 326-364)
        seed = _random(seed);
        uint256 antennaCount = 1 + (seed % 4);
        // CRITICAL: JS line 330 only calls random() for adults (ternary short-circuits for kids)
        uint256 antennaLength;
        if (isKid) {
            antennaLength = 1;  // No random call for kids
        } else {
            seed = _random(seed);
            antennaLength = 1 + (seed % 2);
        }

        // Collect all X positions where body exists at the top row
        uint256[] memory bodyTopPositions = new uint256[](size);
        uint256 topCount = 0;
        for (uint256 x = 0; x < size; x++) {
            if (_isBodyCell(grid[bodyStartY][x])) {
                bodyTopPositions[topCount] = x;
                topCount++;
            }
        }

        // Select antenna positions based on count
        if (topCount > 0) {
            uint256[] memory antennaPositions = new uint256[](4);
            uint256 antennaPosCount = 0;

            if (antennaCount == 1) {
                antennaPositions[0] = bodyTopPositions[topCount / 2];
                antennaPosCount = 1;
            } else if (antennaCount == 2) {
                // Match JS: Math.floor(length * 0.25) and Math.floor(length * 0.75)
                uint256 idx1 = (topCount * 1) / 4;
                uint256 idx2 = (topCount * 3) / 4;
                antennaPositions[0] = bodyTopPositions[idx1];
                antennaPositions[1] = bodyTopPositions[idx2];
                antennaPosCount = 2;
            } else if (antennaCount == 3) {
                antennaPositions[0] = bodyTopPositions[0];
                antennaPositions[1] = bodyTopPositions[topCount / 2];
                antennaPositions[2] = bodyTopPositions[topCount - 1];
                antennaPosCount = 3;
            } else {
                uint256 idx1 = 0;
                uint256 idx2 = (topCount > 3) ? (topCount / 3) : (topCount > 1 ? 1 : 0);
                uint256 idx3 = (topCount > 3) ? (topCount * 2 / 3) : (topCount > 2 ? 2 : (topCount > 1 ? 1 : 0));
                uint256 idx4 = topCount > 1 ? topCount - 1 : 0;
                antennaPositions[0] = bodyTopPositions[idx1];
                antennaPositions[1] = bodyTopPositions[idx2];
                antennaPositions[2] = bodyTopPositions[idx3];
                antennaPositions[3] = bodyTopPositions[idx4];
                antennaPosCount = 4;
            }

            // Draw antennas
            for (uint256 a = 0; a < antennaPosCount; a++) {
                uint256 antennaX = antennaPositions[a];
                for (uint256 i = 1; i <= antennaLength; i++) {
                    if (bodyStartY >= i) {
                        uint256 antennaY = bodyStartY - i;
                        string memory aChar = (i == antennaLength) ? antennaTip : unicode"│";
                        string memory aClass = (i == antennaLength) ? "antenna-tip" : "antenna";
                        grid[antennaY][antennaX] = GridCell(aChar, aClass);
                    }
                }
            }
        }

        // Hat (matching renderer-v3.js lines 366-397)
        if (hatType > 0 && bodyStartY > antennaLength + 1) {
            uint256 hatY = bodyStartY - antennaLength - 1;
            if (hatType == 1 && cx >= 2) {
                // Top hat with brim and stem
                for (uint256 dx = 0; dx <= 4; dx++) {
                    uint256 hatX = cx - 2 + dx;
                    if (hatX < size && hatY < size) {
                        grid[hatY][hatX] = GridCell(unicode"▀", "hat");
                    }
                }
                if (hatY + 1 < size) {
                    grid[hatY + 1][cx] = GridCell(unicode"█", "hat");
                }
            } else if (hatType == 2 && cx >= 2) {
                // Flat hat
                for (uint256 dx = 0; dx <= 4; dx++) {
                    uint256 hatX = cx - 2 + dx;
                    if (hatX < size && hatY < size) {
                        grid[hatY][hatX] = GridCell(unicode"═", "hat");
                    }
                }
            } else if (hatType == 3 && cx >= 2 && hatY > 0) {
                // Double hat
                for (uint256 dx = 0; dx <= 4; dx++) {
                    uint256 hatX = cx - 2 + dx;
                    if (hatX < size) {
                        if (hatY - 1 < size) grid[hatY - 1][hatX] = GridCell(unicode"▀", "hat");
                        if (hatY < size) grid[hatY][hatX] = GridCell(unicode"▄", "hat");
                    }
                }
            } else if (hatType == 4 && cx >= 2 && cx + 2 < size && hatY < size) {
                // Fancy hat
                grid[hatY][cx - 2] = GridCell(unicode"╔", "hat");
                grid[hatY][cx - 1] = GridCell(unicode"═", "hat");
                grid[hatY][cx] = GridCell(unicode"═", "hat");
                grid[hatY][cx + 1] = GridCell(unicode"═", "hat");
                grid[hatY][cx + 2] = GridCell(unicode"╗", "hat");
            }
        }

        // Convert grid to SVG
        return _gridToSVG(grid, size, charWidth, charHeight, xOffset, yOffset);
    }

    function _random(uint256 seed) private pure returns (uint256) {
        // Match JS LCG: seed = (seed * 9301 + 49297) % 233280
        unchecked {
            return (seed * 9301 + 49297) % 233280;
        }
    }

    /// @notice Safe signed integer multiply-divide matching JS division behavior
    /// @dev Equivalent to (a * b) / c for signed integers
    function _mulDiv(int256 a, int256 b, int256 c) private pure returns (int256) {
        require(c != 0, "Division by zero");
        return (a * b) / c;
    }

    /// @notice Absolute value of signed integer
    function _abs(int256 x) private pure returns (int256) {
        return x < 0 ? -x : x;
    }

    /// @notice Check if point is inside body shape (matching renderer-v3.js logic exactly)
    /// @param bodyType Shape type (0=square, 1=round, 2=diamond, 3=mushroom, 4=invader, 5=ghost)
    /// @param relX Normalized X coordinate (scaled by 1000)
    /// @param relY Normalized Y coordinate (scaled by 1000)
    /// @param isKid Whether this is a kid (affects mushroom shape)
    /// @param x Actual x offset from center
    /// @param bodyWidth Width of body for column calculations
    function _isInBody(uint256 bodyType, int256 relX, int256 relY, bool isKid, int256 x, uint256 bodyWidth)
        private
        pure
        returns (bool)
    {
        if (bodyType == 0) {
            // Square: always true within bounds
            return true;
        } else if (bodyType == 1) {
            // Round: distance from center <= 1.0
            // JS: Math.sqrt(relX * relX + relY * relY) <= 1.0
            // Optimized: relX^2 + relY^2 <= 1000 (avoiding sqrt)
            int256 distSquared = (relX * relX + relY * relY) / SCALE;
            return distSquared <= SCALE;
        } else if (bodyType == 2) {
            // Diamond: manhattan distance <= 1.0
            // JS: Math.abs(relX) + Math.abs(relY) <= 1.0
            return (_abs(relX) + _abs(relY)) <= SCALE;
        } else if (bodyType == 3) {
            // Mushroom
            if (isKid) {
                // JS: if (relY < -0.2) inBody = true; else inBody = Math.abs(relX) <= 0.7;
                if (relY < -200) return true;
                return _abs(relX) <= 700;
            } else {
                // JS: if (relY < 0) inBody = true; else inBody = Math.abs(relX) <= 0.6;
                if (relY < 0) return true;
                return _abs(relX) <= 600;
            }
        } else if (bodyType == 4) {
            // Invader
            // JS: if (relY < -0.3) inBody = Math.abs(relX) <= 0.7;
            //     else if (relY < 0.3) inBody = true;
            //     else inBody = Math.abs(relX) <= 0.85;
            int256 absX = _abs(relX);
            if (relY < -300) return absX <= 700;
            if (relY < 300) return true;
            return absX <= 850;
        } else if (bodyType == 5) {
            // Ghost
            // JS: if (relY < 0.5) inBody = distGhost <= 1.0;
            //     else inBody = Math.abs(relX) <= 0.9 && (Math.floor(x + bodyWidth) % 2 === 0 || relY < 0.8);
            int256 distSquared = (relX * relX + relY * relY) / SCALE;
            if (relY < 500) {
                return distSquared <= SCALE;
            } else {
                int256 absX = _abs(relX);
                uint256 columnIndex = (int256(bodyWidth) + x).toUint256();
                bool oddColumn = (columnIndex % 2) == 0;
                return absX <= 900 && (oddColumn || relY < 800);
            }
        }
        return false;
    }

    function _renderTextWithClass(
        uint256 x,
        uint256 y,
        string memory char,
        string memory className,
        uint256 charWidth,
        uint256 charHeight,
        uint256 xOffset,
        uint256 yOffset
    ) private pure returns (string memory) {
        // Use textLength to force exact character width (matches HTML positioning)
        return string.concat(
            '<text x="',
            LibString.toString(x * charWidth + xOffset),
            '" y="',
            LibString.toString(y * charHeight + yOffset),
            '" class="',
            className,
            '" textLength="',
            LibString.toString(charWidth),
            '" lengthAdjust="spacingAndGlyphs">',
            char,
            "</text>"
        );
    }
}
