// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solady/utils/Base64.sol";
import "solady/utils/LibString.sol";
import "solady/auth/Ownable.sol";
import "solady/utils/SSTORE2.sol";

import "./interfaces/IProtocolitesRenderer.sol";

/// @title ProtocolitesRendererHybrid
/// @notice Hybrid renderer with static SVG and optional JavaScript animations
/// @dev Supports both static SVG images and animated HTML with JavaScript
contract ProtocolitesRendererHybrid is Ownable, IProtocolitesRenderer {
    address private renderScriptPointer;

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
        uint256 width = size * charWidth;
        uint256 height = size * charHeight;

        // No offset needed - render in grid coordinates, viewBox will be sized to fit
        uint256 xOffset = 0;

        // Generate creature parts
        string memory creature = renderAnimatedCreature(dna, isKid, seed, charWidth, charHeight, xOffset);

        // Build CSS animations
        string memory animations = buildAnimations(tempIndex, familyColor, fontSize);

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ',
            LibString.toString(width),
            " ",
            LibString.toString(height),
            '" width="',
            LibString.toString(width),
            '" height="',
            LibString.toString(height),
            '" style="background:#fff">',
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
        // Convert dna to hex string representation to match JS input
        string memory dnaStr = LibString.toHexString(dna);
        bytes memory dnaBytes = bytes(dnaStr);

        int256 h = 0;
        for (uint256 i = 0; i < dnaBytes.length; i++) {
            unchecked {
                h = ((h << 5) - h) + int256(uint256(uint8(dnaBytes[i])));
                h = h & h; // Bitwise AND with itself (no-op but matches JS)
            }
        }

        // Return absolute value
        return uint256(h < 0 ? -h : h);
    }

    /// @notice Build CSS styles (animations removed)
    function buildAnimations(uint256 tempIndex, string memory color, uint256 fontSize) private pure returns (string memory) {
        // Base styles only - no animations
        return string.concat(
            "text{font-family:'Courier New',monospace;font-size:",
            LibString.toString(fontSize),
            "px;font-weight:400;fill:",
            color,
            ";dominant-baseline:text-before-edge}"
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

    function renderAnimatedCreature(uint256 dna, bool isKid, uint256 seed, uint256 charWidth, uint256 charHeight, uint256 xOffset)
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

        string memory result = "";

        // Track body positions for arms/legs/antennas
        // We'll use a dynamic array approach: store packed position data
        // Format: array of uint256 where each element stores (y << 128) | x
        uint256[] memory bodyPositions = new uint256[](size * size);
        uint256 bodyPosCount = 0;

        // Render body and track positions
        for (uint256 y = 0; y < bodyHeight; y++) {
            for (int256 x = -int256(bodyWidth); x <= int256(bodyWidth); x++) {
                uint256 posY = bodyStartY + y;
                int256 posX = int256(cx) + x;
                if (posX < 0 || posX >= int256(size)) continue;

                bool inBody = false;
                int256 relX = (x * 1000) / int256(bodyWidth);
                int256 relY = ((int256(y) - int256(bodyHeight) / 2) * 1000) / (int256(bodyHeight) / 2);

                if (bodyType == 0) {
                    inBody = true;
                } else if (bodyType == 1) {
                    int256 dist = (relX * relX + relY * relY) / 1000;
                    inBody = dist <= 1000;
                } else if (bodyType == 2) {
                    int256 absX = relX < 0 ? -relX : relX;
                    int256 absY = relY < 0 ? -relY : relY;
                    inBody = (absX + absY) <= 1000;
                } else if (bodyType == 3) {
                    if (isKid) {
                        if (relY < -200) {
                            inBody = true;
                        } else {
                            int256 absX = relX < 0 ? -relX : relX;
                            inBody = absX <= 700;
                        }
                    } else {
                        if (relY < 0) {
                            inBody = true;
                        } else {
                            int256 absX = relX < 0 ? -relX : relX;
                            inBody = absX <= 600;
                        }
                    }
                } else if (bodyType == 4) {
                    int256 absX = relX < 0 ? -relX : relX;
                    if (relY < -300) inBody = absX <= 700;
                    else if (relY < 300) inBody = true;
                    else inBody = absX <= 850;
                } else if (bodyType == 5) {
                    int256 dist = (relX * relX + relY * relY) / 1000;
                    if (relY < 500) {
                        inBody = dist <= 1000;
                    } else {
                        int256 absX = relX < 0 ? -relX : relX;
                        // Calculate column index safely: x ranges from -bodyWidth to +bodyWidth
                        // To get 0-indexed column: add bodyWidth to shift range to 0..2*bodyWidth
                        uint256 columnIndex = uint256(int256(bodyWidth) + x);
                        bool oddColumn = (columnIndex % 2) == 0;
                        inBody = absX <= 900 && (oddColumn || relY < 800);
                    }
                }

                if (inBody) {
                    result = string.concat(
                        result, _renderTextWithClass(uint256(posX), posY, bodyChar, "body", charWidth, charHeight, xOffset)
                    );
                    // Track body position: pack y and x into single uint256
                    bodyPositions[bodyPosCount] = (posY << 128) | uint256(posX);
                    bodyPosCount++;
                }
            }
        }

        // Eyes (with surrounding body structure like JS renderer)
        uint256 eyeY = bodyStartY + 1;
        seed = _random(seed);
        uint256 eyeCount = 1 + (seed % 3);

        if (isKid) {
            if (eyeCount == 1 && cx >= 1) {
                // Create eye socket: clear 3x2 area and rebuild with eye and surrounding body
                result = string.concat(
                    result,
                    _renderTextWithClass(cx - 1, eyeY, bodyChar, "body", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + 1, eyeY, bodyChar, "body", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx, eyeY + 1, bodyChar, "body", charWidth, charHeight, xOffset)
                );
            } else if (eyeCount == 2 && cx >= 2) {
                uint256 eyeSpacing = 1;
                // Create two eye sockets (needs cx >= 2 for cx - eyeSpacing - 1 = cx - 2)
                result = string.concat(
                    result,
                    // Left eye socket
                    _renderTextWithClass(cx - eyeSpacing - 1, eyeY, bodyChar, "body", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx - eyeSpacing, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx - eyeSpacing - 1, eyeY + 1, bodyChar, "body", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx - eyeSpacing, eyeY + 1, bodyChar, "body", charWidth, charHeight, xOffset),
                    // Right eye socket
                    _renderTextWithClass(cx + eyeSpacing, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + eyeSpacing + 1, eyeY, bodyChar, "body", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + eyeSpacing, eyeY + 1, bodyChar, "body", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + eyeSpacing + 1, eyeY + 1, bodyChar, "body", charWidth, charHeight, xOffset)
                );
            } else if (cx >= 2) {
                // 3 eyes - no socket structure in JS
                result = string.concat(
                    result,
                    _renderTextWithClass(cx - 2, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + 2, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset)
                );
            }
        } else {
            // Adult eyes
            seed = _random(seed);
            uint256 adultEyeCount = 1 + (seed % 3);

            if (adultEyeCount == 1 && cx >= 2) {
                // Mega eye: 5x3 block
                for (uint256 dx = 0; dx < 5; dx++) {
                    uint256 eyeX = cx - 2 + dx;
                    result = string.concat(
                        result,
                        _renderTextWithClass(eyeX, eyeY, bodyChar, "body", charWidth, charHeight, xOffset),
                        _renderTextWithClass(eyeX, eyeY + 2, bodyChar, "body", charWidth, charHeight, xOffset)
                    );
                }
                result = string.concat(
                    result,
                    _renderTextWithClass(cx - 2, eyeY + 1, bodyChar, "body", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx - 1, eyeY + 1, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx, eyeY + 1, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + 1, eyeY + 1, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + 2, eyeY + 1, bodyChar, "body", charWidth, charHeight, xOffset)
                );
            } else if (adultEyeCount == 2 && cx >= 4) {
                // Two eye sockets: 3x3 blocks (need cx >= 4 to fit left socket: cx - blockSpacing - 2 = cx - 4)
                uint256 blockSpacing = 2;
                // Left eye socket
                for (uint256 dy = 0; dy < 3; dy++) {
                    for (uint256 dx = 0; dx < 3; dx++) {
                        bool isCenter = dy == 1 && dx == 1;
                        uint256 leftEyeX = cx - blockSpacing - 2 + dx;
                        result = string.concat(
                            result,
                            _renderTextWithClass(
                                leftEyeX,
                                eyeY + dy,
                                isCenter ? eyeChar : bodyChar,
                                isCenter ? "eye" : "body",
                                charWidth,
                                charHeight,
                                xOffset
                            )
                        );
                    }
                }
                // Right eye socket
                for (uint256 dy = 0; dy < 3; dy++) {
                    for (uint256 dx = 0; dx < 3; dx++) {
                        bool isCenter = dy == 1 && dx == 1;
                        result = string.concat(
                            result,
                            _renderTextWithClass(
                                cx + blockSpacing + dx,
                                eyeY + dy,
                                isCenter ? eyeChar : bodyChar,
                                isCenter ? "eye" : "body",
                                charWidth,
                                charHeight,
                                xOffset
                            )
                        );
                    }
                }
            } else if (cx >= 4) {
                // 3 eyes: 2x2 blocks (need cx >= 4 for leftmost eye at cx - 3 - 1 = cx - 4)
                for (int256 i = -3; i <= 3; i += 3) {
                    for (uint256 dy = 0; dy < 2; dy++) {
                        uint256 eyeX1 = uint256(int256(cx) + i);
                        uint256 eyeX2 = uint256(int256(cx) + i - 1);
                        result = string.concat(
                            result,
                            _renderTextWithClass(eyeX1, eyeY + dy, eyeChar, "eye", charWidth, charHeight, xOffset),
                            _renderTextWithClass(eyeX2, eyeY + dy, eyeChar, "eye", charWidth, charHeight, xOffset)
                        );
                    }
                }
            }
        }

        // Mouth
        seed = _random(seed);
        // JS: random() > 0.3 means 70% chance (values 0.3 to 1.0)
        // Convert to: (seed % 10) >= 3 for 70% chance (values 3-9 = 7 out of 10)
        if ((seed % 10) >= 3) {
            uint256 mouthY = eyeY + (isKid ? 2 : 3);
            // Always render center mouth
            result =
                string.concat(result, _renderTextWithClass(cx, mouthY, unicode"─", "mouth", charWidth, charHeight, xOffset));

            // Randomly add left extension (50% chance)
            // JS: random() > 0.5 means 50% chance
            seed = _random(seed);
            if ((seed % 2) == 0 && cx > 0) {
                result = string.concat(
                    result, _renderTextWithClass(cx - 1, mouthY, unicode"─", "mouth", charWidth, charHeight, xOffset)
                );
            }

            // Randomly add right extension (50% chance)
            // JS: random() > 0.5 means 50% chance
            seed = _random(seed);
            if ((seed % 2) == 0 && cx + 1 < size) {
                result = string.concat(
                    result, _renderTextWithClass(cx + 1, mouthY, unicode"─", "mouth", charWidth, charHeight, xOffset)
                );
            }
        }

        // Cigarette
        if (hasCigarette) {
            uint256 cigY = eyeY + (isKid ? 2 : 3);
            seed = _random(seed);
            // JS: random() > 0.5 ? 3 : -3 (right side if > 0.5)
            bool cigRight = (seed % 2) == 0;
            uint256 cigX = cigRight ? (cx + 3) : (cx >= 3 ? cx - 3 : 0);
            if (cigX < size) {
                // Pick cigarette character randomly like JS version
                seed = _random(seed);
                uint256 cigCharIndex = seed % 3;
                string memory cigChar = cigCharIndex == 0 ? unicode"≈" : (cigCharIndex == 1 ? unicode"∼" : "~");
                result = string.concat(
                    result, _renderTextWithClass(cigX, cigY, cigChar, "cigarette", charWidth, charHeight, xOffset)
                );
                // Add ember dot next to cigarette
                if (cigX + 1 < size) {
                    result = string.concat(
                        result, _renderTextWithClass(cigX + 1, cigY, unicode"∙", "cigarette", charWidth, charHeight, xOffset)
                    );
                }
            }
        }

        // Arms - scan actual body edges per row
        seed = _random(seed);
        uint256 armCount = 1 + (seed % 4);
        seed = _random(seed);
        uint256 armLength = isKid ? (1 + (seed % 2)) : (2 + (seed % 4));
        string memory armChar = lineArms ? unicode"─" : unicode"█"; // line style uses ─, block style uses solid █

        for (uint256 a = 0; a < armCount; a++) {
            uint256 currentArmY = bodyStartY + 2 + a * (isKid ? 1 : 2);
            if (currentArmY >= bodyStartY + bodyHeight) break;

            // Find left and right body edges at this Y coordinate
            uint256 leftBodyEdge = cx;
            uint256 rightBodyEdge = cx;
            bool foundLeft = false;
            bool foundRight = false;

            for (uint256 i = 0; i < bodyPosCount; i++) {
                uint256 posY = bodyPositions[i] >> 128;
                uint256 posX = bodyPositions[i] & ((1 << 128) - 1);

                if (posY == currentArmY) {
                    if (!foundLeft || posX < leftBodyEdge) {
                        leftBodyEdge = posX;
                        foundLeft = true;
                    }
                    if (!foundRight || posX > rightBodyEdge) {
                        rightBodyEdge = posX;
                        foundRight = true;
                    }
                }
            }

            // Draw arms extending from body edges
            if (foundLeft && foundRight) {
                for (uint256 i = 1; i <= armLength; i++) {
                    if (leftBodyEdge >= i) {
                        result = string.concat(
                            result, _renderTextWithClass(leftBodyEdge - i, currentArmY, armChar, "arm", charWidth, charHeight, xOffset)
                        );
                    }
                    if (rightBodyEdge + i < size) {
                        result = string.concat(
                            result, _renderTextWithClass(rightBodyEdge + i, currentArmY, armChar, "arm", charWidth, charHeight, xOffset)
                        );
                    }
                }
            }
        }

        // Legs - scan actual body bottom positions
        seed = _random(seed);
        uint256 legCount = 1 + (seed % 4);
        seed = _random(seed);
        uint256 legLength = isKid ? (1 + (seed % 2)) : (2 + (seed % 3));
        string memory legChar = lineLegs ? unicode"│" : unicode"█"; // line style uses │, block style uses solid █
        uint256 legY = bodyStartY + bodyHeight;

        // Collect all X positions where body exists at the bottom row
        uint256[] memory bodyBottomPositions = new uint256[](size);
        uint256 bottomCount = 0;
        if (legY > 0) { // Ensure legY - 1 doesn't underflow
            for (uint256 i = 0; i < bodyPosCount; i++) {
                uint256 posY = bodyPositions[i] >> 128;
                uint256 posX = bodyPositions[i] & ((1 << 128) - 1);
                if (posY == legY - 1) {
                    bodyBottomPositions[bottomCount] = posX;
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
                // Use safer index calculation with bounds checking
                uint256 idx1 = (bottomCount > 4) ? (bottomCount / 4) : 0;
                uint256 idx2 = (bottomCount > 4) ? (bottomCount * 3 / 4) : (bottomCount > 1 ? bottomCount - 1 : 0);
                legPositions[0] = bodyBottomPositions[idx1];
                legPositions[1] = bodyBottomPositions[idx2];
                legPosCount = 2;
            } else if (legCount == 3) {
                legPositions[0] = bodyBottomPositions[0];
                legPositions[1] = bodyBottomPositions[bottomCount / 2];
                legPositions[2] = bodyBottomPositions[bottomCount - 1];
                legPosCount = 3;
            } else {
                // Use safer index calculation
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
                            result = string.concat(
                                result, _renderTextWithClass(legX, legY + i, legChar, "leg", charWidth, charHeight, xOffset)
                            );
                        }
                    }
                }
            }
        }

        // Antennas - scan actual body top positions
        seed = _random(seed);
        uint256 antennaCount = 1 + (seed % 4);
        seed = _random(seed);
        uint256 antennaLength = isKid ? 1 : (1 + (seed % 2));

        // Collect all X positions where body exists at the top row
        uint256[] memory bodyTopPositions = new uint256[](size);
        uint256 topCount = 0;
        for (uint256 i = 0; i < bodyPosCount; i++) {
            uint256 posY = bodyPositions[i] >> 128;
            uint256 posX = bodyPositions[i] & ((1 << 128) - 1);
            if (posY == bodyStartY) {
                bodyTopPositions[topCount] = posX;
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
                // Use safer index calculation with bounds checking
                uint256 idx1 = (topCount > 4) ? (topCount / 4) : 0;
                uint256 idx2 = (topCount > 4) ? (topCount * 3 / 4) : (topCount > 1 ? topCount - 1 : 0);
                antennaPositions[0] = bodyTopPositions[idx1];
                antennaPositions[1] = bodyTopPositions[idx2];
                antennaPosCount = 2;
            } else if (antennaCount == 3) {
                antennaPositions[0] = bodyTopPositions[0];
                antennaPositions[1] = bodyTopPositions[topCount / 2];
                antennaPositions[2] = bodyTopPositions[topCount - 1];
                antennaPosCount = 3;
            } else {
                // Use safer index calculation
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
                    // Check for underflow: bodyStartY must be >= i
                    if (bodyStartY >= i) {
                        uint256 antennaY = bodyStartY - i;
                        string memory aChar = (i == antennaLength) ? antennaTip : unicode"│";
                        string memory aClass = (i == antennaLength) ? "antenna-tip" : "antenna";
                        result = string.concat(
                            result, _renderTextWithClass(antennaX, antennaY, aChar, aClass, charWidth, charHeight, xOffset)
                        );
                    }
                }
            }
        }

        // Hat
        if (hatType > 0 && bodyStartY > antennaLength + 1) { // Check for underflow: need bodyStartY >= antennaLength + 2
            uint256 hatY = bodyStartY - antennaLength - 1;
            if (hatType == 1 && cx >= 2) {
                // Top hat with brim and stem
                for (uint256 dx = 0; dx <= 4; dx++) {
                    uint256 hatX = cx - 2 + dx;
                    if (hatX < size) {
                        result = string.concat(
                            result, _renderTextWithClass(hatX, hatY, unicode"▀", "hat", charWidth, charHeight, xOffset)
                        );
                    }
                }
                // Add stem below brim (match JS renderer)
                if (hatY + 1 < size) {
                    result = string.concat(
                        result, _renderTextWithClass(cx, hatY + 1, unicode"█", "hat", charWidth, charHeight, xOffset)
                    );
                }
            } else if (hatType == 2 && cx >= 2) {
                // Flat hat
                for (uint256 dx = 0; dx <= 4; dx++) {
                    uint256 hatX = cx - 2 + dx;
                    if (hatX < size) {
                        result = string.concat(
                            result, _renderTextWithClass(hatX, hatY, unicode"═", "hat", charWidth, charHeight, xOffset)
                        );
                    }
                }
            } else if (hatType == 3 && cx >= 2 && hatY > 0) {
                // Double hat (need hatY >= 1 to render hatY-1)
                for (uint256 dx = 0; dx <= 4; dx++) {
                    uint256 hatX = cx - 2 + dx;
                    if (hatX < size) {
                        result = string.concat(
                            result,
                            _renderTextWithClass(hatX, hatY - 1, unicode"▀", "hat", charWidth, charHeight, xOffset),
                            _renderTextWithClass(hatX, hatY, unicode"▄", "hat", charWidth, charHeight, xOffset)
                        );
                    }
                }
            } else if (hatType == 4 && cx >= 2 && cx + 2 < size) {
                // Fancy hat
                result = string.concat(
                    result,
                    _renderTextWithClass(cx - 2, hatY, unicode"╔", "hat", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx - 1, hatY, unicode"═", "hat", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx, hatY, unicode"═", "hat", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + 1, hatY, unicode"═", "hat", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + 2, hatY, unicode"╗", "hat", charWidth, charHeight, xOffset)
                );
            }
        }

        return result;
    }

    function _random(uint256 seed) private pure returns (uint256) {
        // Match JS LCG: seed = (seed * 9301 + 49297) % 233280
        unchecked {
            return (seed * 9301 + 49297) % 233280;
        }
    }

    function _renderTextWithClass(
        uint256 x,
        uint256 y,
        string memory char,
        string memory className,
        uint256 charWidth,
        uint256 charHeight,
        uint256 xOffset
    ) private pure returns (string memory) {
        return string.concat(
            '<text x="',
            LibString.toString(x * charWidth + xOffset),
            '" y="',
            LibString.toString(y * charHeight),
            '" class="',
            className,
            '">',
            char,
            "</text>"
        );
    }
}
