// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solady/utils/Base64.sol";
import "solady/utils/LibString.sol";
import "solady/auth/Ownable.sol";

import "./interfaces/IProtocolitesRenderer.sol";

/// @title ProtocolitesRendererSVG
/// @notice Fully static SVG renderer with CSS animations - no JavaScript required
/// @dev All animations are done via CSS keyframes, matching the original JS animation aesthetics
contract ProtocolitesRendererSVG is Ownable, IProtocolitesRenderer {
    string private constant DEPRECATED_SCRIPT = ""; // V4 uses pure CSS animations, no JS

    constructor() {
        _initializeOwner(msg.sender);
    }

    /// @notice Deprecated - V4 uses pure CSS animations
    function renderScript() external pure returns (string memory) {
        return DEPRECATED_SCRIPT;
    }

    /// @notice Deprecated - V4 uses pure CSS animations
    function setRenderScript(string memory) external pure {
        revert("V4 uses pure CSS animations - no script needed");
    }

    function tokenURI(uint256 tokenId, TokenData memory data) external pure returns (string memory) {
        return string.concat("data:application/json;base64,", Base64.encode(bytes(metadata(tokenId, data))));
    }

    function metadata(uint256 tokenId, TokenData memory data) public pure returns (string memory) {
        bool isKid = data.isKid;
        uint256 size = isKid ? 16 : 24;

        // Generate static SVG with CSS animations
        string memory svg = generateSVG(tokenId, data);
        string memory imageData = string.concat("data:image/svg+xml;base64,", Base64.encode(bytes(svg)));

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
            '"description":"Fully on-chain generative ASCII art with pure CSS animations.",',
            '"image":"',
            imageData,
            '",',
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

        // Determine temperament from DNA
        uint256 seed = uint256(keccak256(abi.encodePacked(dna, tokenId)));
        uint256 tempIndex = getTemperament(seed);

        // Calculate SVG dimensions (match JS renderer spacing)
        uint256 fontSize = size == 24 ? 20 : 16;
        uint256 charWidth = (fontSize * 6) / 10; // fontSize * 0.6
        uint256 charHeight = fontSize;
        uint256 width = size * charWidth;
        uint256 height = size * charHeight;

        // Make viewBox square using the larger dimension
        uint256 viewSize = width > height ? width : height;

        // Calculate horizontal offset to center the creature
        uint256 xOffset = (viewSize - width) / 2;

        // Generate creature parts
        string memory creature = renderAnimatedCreature(dna, isKid, seed, charWidth, charHeight, xOffset);

        // Build CSS animations
        string memory animations = buildAnimations(tempIndex, familyColor, fontSize);

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ',
            LibString.toString(viewSize),
            " ",
            LibString.toString(viewSize),
            '" width="',
            LibString.toString(viewSize),
            '" height="',
            LibString.toString(viewSize),
            '" style="background:#fff">',
            "<defs><style>",
            animations,
            "</style></defs>",
            creature,
            "</svg>"
        );
    }

    /// @notice Build CSS animations based on temperament
    function buildAnimations(uint256 tempIndex, string memory color, uint256 fontSize) private pure returns (string memory) {
        // Base styles
        string memory baseStyle = string.concat(
            "text{font-family:'Courier New',monospace;font-size:",
            LibString.toString(fontSize),
            "px;font-weight:400;fill:",
            color,
            ";dominant-baseline:text-before-edge;}"
        );

        string memory bodyAnim;
        string memory eyeAnim;
        string memory armAnim;
        string memory legAnim;
        string memory antennaAnim;
        string memory mouthAnim;

        if (tempIndex == 0) {
            // Calm
            bodyAnim =
                ".body{animation:body-calm 4s ease-in-out infinite;}@keyframes body-calm{0%,100%{transform:translateY(0px);}50%{transform:translateY(2px);}}";
            eyeAnim =
                ".eye{animation:eye-calm 8s ease-in-out infinite;}@keyframes eye-calm{0%,95%,100%{opacity:1;}96%,99%{opacity:0.2;}}";
            armAnim =
                ".arm{animation:arm-calm 3s ease-in-out infinite;}@keyframes arm-calm{0%,100%{transform:translateY(0px);}50%{transform:translateY(3px);}}";
            legAnim =
                ".leg{animation:leg-calm 2.5s ease-in-out infinite;}@keyframes leg-calm{0%,100%{transform:translateY(0px);}50%{transform:translateY(2px);}}";
            antennaAnim =
                ".antenna,.antenna-tip{animation:antenna-calm 3s ease-in-out infinite;}@keyframes antenna-calm{0%,100%{transform:translateX(0px);}50%{transform:translateX(2px);}}";
            mouthAnim = "";
        } else if (tempIndex == 1) {
            // Balanced
            bodyAnim =
                ".body{animation:body-balanced 3s ease-in-out infinite;}@keyframes body-balanced{0%,100%{transform:translateY(0px);}50%{transform:translateY(2px);}}";
            eyeAnim =
                ".eye{animation:eye-balanced 6s ease-in-out infinite;}@keyframes eye-balanced{0%,94%,100%{opacity:1;}95%,98%{opacity:0.2;}}";
            armAnim =
                ".arm{animation:arm-balanced 2.5s ease-in-out infinite;}@keyframes arm-balanced{0%,100%{transform:translate(0px,0px);}50%{transform:translate(1px,3px);}}";
            legAnim =
                ".leg{animation:leg-balanced 2s ease-in-out infinite;}@keyframes leg-balanced{0%,100%{transform:translateY(0px);}50%{transform:translateY(2px);}}";
            antennaAnim =
                ".antenna,.antenna-tip{animation:antenna-balanced 2.5s ease-in-out infinite;}@keyframes antenna-balanced{0%,100%{transform:translateX(0px);}50%{transform:translateX(2px);}}";
            mouthAnim = "";
        } else if (tempIndex == 2) {
            // Energetic
            bodyAnim =
                ".body{animation:body-energetic 2s ease-in-out infinite;}@keyframes body-energetic{0%,100%{transform:translateY(0px);}50%{transform:translateY(2px);}}";
            eyeAnim =
                ".eye{animation:eye-energetic 3s ease-in-out infinite;}@keyframes eye-energetic{0%,92%,100%{opacity:1;}93%,97%{opacity:0.2;}}";
            armAnim =
                ".arm{animation:arm-energetic 1.5s ease-in-out infinite;}@keyframes arm-energetic{0%,100%{transform:translate(0px,0px);}25%{transform:translate(2px,3px);}75%{transform:translate(-1px,2px);}}";
            legAnim =
                ".leg{animation:leg-energetic 1.5s ease-in-out infinite;}@keyframes leg-energetic{0%,100%{transform:translateY(0px);}50%{transform:translateY(2px);}}";
            antennaAnim =
                ".antenna,.antenna-tip{animation:antenna-energetic 2s ease-in-out infinite;}@keyframes antenna-energetic{0%,100%{transform:translateX(0px)rotate(0deg);}50%{transform:translateX(2px)rotate(5deg);}}";
            mouthAnim = "";
        } else if (tempIndex == 3) {
            // Chaotic
            bodyAnim =
                ".body{animation:body-chaotic 1.5s ease-in-out infinite;}@keyframes body-chaotic{0%,100%{transform:translateY(0px);}25%{transform:translateY(3px);}75%{transform:translateY(-1px);}}";
            eyeAnim =
                ".eye{animation:eye-chaotic 2.5s ease-in-out infinite;}@keyframes eye-chaotic{0%,90%,100%{opacity:1;}91%,96%{opacity:0.2;}}";
            armAnim =
                ".arm{animation:arm-chaotic 1.2s ease-in-out infinite;}@keyframes arm-chaotic{0%,100%{transform:translate(0px,0px);}25%{transform:translate(2px,4px);}50%{transform:translate(-2px,2px);}75%{transform:translate(1px,-1px);}}";
            legAnim =
                ".leg{animation:leg-chaotic 1.3s ease-in-out infinite;}@keyframes leg-chaotic{0%,100%{transform:translateY(0px);}33%{transform:translateY(3px);}66%{transform:translateY(-1px);}}";
            antennaAnim =
                ".antenna,.antenna-tip{animation:antenna-chaotic 1.8s ease-in-out infinite;}@keyframes antenna-chaotic{0%,100%{transform:translateX(0px)rotate(0deg);}33%{transform:translateX(2px)rotate(8deg);}66%{transform:translateX(-2px)rotate(-8deg);}}";
            mouthAnim = "";
        } else if (tempIndex == 4) {
            // Glitchy
            bodyAnim =
                ".body{animation:body-glitchy 1.2s ease-in-out infinite;}@keyframes body-glitchy{0%,100%{transform:translateY(0px);}20%{transform:translateY(2px);}40%{transform:translateY(-1px);}60%{transform:translateY(3px);}80%{transform:translateY(1px);}}";
            eyeAnim =
                ".eye{animation:eye-glitchy 2s steps(4) infinite;}@keyframes eye-glitchy{0%,85%,100%{opacity:1;}86%,92%{opacity:0.2;}93%,97%{opacity:1;}}";
            armAnim =
                ".arm{animation:arm-glitchy 1s ease-in-out infinite;}@keyframes arm-glitchy{0%,100%{transform:translate(0px,0px);}20%{transform:translate(2px,3px);}40%{transform:translate(-2px,4px);}60%{transform:translate(1px,-1px);}80%{transform:translate(-1px,2px);}}";
            legAnim =
                ".leg{animation:leg-glitchy 1.1s ease-in-out infinite;}@keyframes leg-glitchy{0%,100%{transform:translateY(0px);}25%{transform:translateY(2px);}50%{transform:translateY(-1px);}75%{transform:translateY(3px);}}";
            antennaAnim =
                ".antenna,.antenna-tip{animation:antenna-glitchy 1.5s ease-in-out infinite;}@keyframes antenna-glitchy{0%,100%{transform:translate(0px,0px)rotate(0deg);}25%{transform:translate(2px,1px)rotate(10deg);}50%{transform:translate(-2px,-1px)rotate(-10deg);}75%{transform:translate(1px,1px)rotate(5deg);}}";
            mouthAnim = "";
        } else {
            // Unstable
            bodyAnim =
                ".body{animation:body-unstable 1s linear infinite;}@keyframes body-unstable{0%{transform:translateY(0px);}15%{transform:translateY(3px);}30%{transform:translateY(-2px);}45%{transform:translateY(4px);}60%{transform:translateY(-1px);}75%{transform:translateY(2px);}90%{transform:translateY(-3px);}100%{transform:translateY(0px);}}";
            eyeAnim =
                ".eye{animation:eye-unstable 1.8s steps(5) infinite;}@keyframes eye-unstable{0%,80%,100%{opacity:1;}81%,85%{opacity:0.1;}86%,90%{opacity:1;}91%,95%{opacity:0.3;}}";
            armAnim =
                ".arm{animation:arm-unstable 0.9s linear infinite;}@keyframes arm-unstable{0%{transform:translate(0px,0px);}14%{transform:translate(3px,4px);}28%{transform:translate(-3px,2px);}42%{transform:translate(2px,-2px);}57%{transform:translate(-2px,5px);}71%{transform:translate(1px,-3px);}85%{transform:translate(-1px,3px);}100%{transform:translate(0px,0px);}}";
            legAnim =
                ".leg{animation:leg-unstable 0.95s linear infinite;}@keyframes leg-unstable{0%{transform:translateY(0px);}20%{transform:translateY(3px);}40%{transform:translateY(-2px);}60%{transform:translateY(4px);}80%{transform:translateY(-1px);}100%{transform:translateY(0px);}}";
            antennaAnim =
                ".antenna,.antenna-tip{animation:antenna-unstable 1.1s linear infinite;}@keyframes antenna-unstable{0%{transform:translate(0px,0px)rotate(0deg);}16%{transform:translate(3px,1px)rotate(15deg);}33%{transform:translate(-3px,-1px)rotate(-15deg);}50%{transform:translate(2px,2px)rotate(10deg);}66%{transform:translate(-2px,-2px)rotate(-10deg);}83%{transform:translate(1px,1px)rotate(5deg);}100%{transform:translate(0px,0px)rotate(0deg);}}";
            mouthAnim = "";
        }

        return string.concat(baseStyle, bodyAnim, eyeAnim, armAnim, legAnim, antennaAnim, mouthAnim);
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
        if (charIndex == 0) return "&#x2588;";
        if (charIndex == 1) return "&#x2593;";
        if (charIndex == 2) return "&#x2592;";
        return "&#x2591;";
    }

    function getEyeChar(uint256 charIndex) private pure returns (string memory) {
        if (charIndex == 0) return "&#x25cf;";
        if (charIndex == 1) return "&#x25c9;";
        if (charIndex == 2) return "&#x25ce;";
        return "&#x25cb;";
    }

    function getAntennaTip(uint256 tipIndex) private pure returns (string memory) {
        tipIndex = tipIndex % 7;
        if (tipIndex == 0) return "&#x25cf;";
        if (tipIndex == 1) return "&#x25c9;";
        if (tipIndex == 2) return "&#x25cb;";
        if (tipIndex == 3) return "&#x25ce;";
        if (tipIndex == 4) return "&#x2726;";
        if (tipIndex == 5) return "&#x2727;";
        return "&#x2605;";
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

        // Render body
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
                        bool oddColumn = ((uint256(x) + bodyWidth) % 2) == 0;
                        inBody = absX <= 900 && (oddColumn || relY < 800);
                    }
                }

                if (inBody) {
                    result = string.concat(
                        result, _renderTextWithClass(uint256(posX), posY, bodyChar, "body", charWidth, charHeight, xOffset)
                    );
                }
            }
        }

        // Eyes
        uint256 eyeY = bodyStartY + 1;
        seed = _random(seed);
        uint256 eyeCount = 1 + (seed % 3);

        if (isKid) {
            if (eyeCount == 1) {
                result = string.concat(result, _renderTextWithClass(cx, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset));
            } else if (eyeCount == 2) {
                uint256 eyeSpacing = 1;
                result = string.concat(
                    result,
                    _renderTextWithClass(cx - eyeSpacing, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + eyeSpacing, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset)
                );
            } else {
                result = string.concat(
                    result,
                    _renderTextWithClass(cx - 2, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                    _renderTextWithClass(cx + 2, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset)
                );
            }
        } else {
            uint256 eyeSpacing = megaEyes ? 2 : 3;
            result = string.concat(
                result,
                _renderTextWithClass(cx - eyeSpacing, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset),
                _renderTextWithClass(cx + eyeSpacing, eyeY, eyeChar, "eye", charWidth, charHeight, xOffset)
            );
        }

        // Mouth
        seed = _random(seed);
        if ((seed % 10) > 3) {
            uint256 mouthY = eyeY + (isKid ? 2 : 3);
            result =
                string.concat(result, _renderTextWithClass(cx, mouthY, unicode"─", "mouth", charWidth, charHeight, xOffset));
        }

        // Cigarette
        if (hasCigarette) {
            uint256 cigY = eyeY + (isKid ? 2 : 3);
            seed = _random(seed);
            bool cigRight = (seed % 2) == 0;
            uint256 cigX = cigRight ? (cx + 3) : (cx >= 3 ? cx - 3 : 0);
            if (cigX < size) {
                result = string.concat(
                    result, _renderTextWithClass(cigX, cigY, "~", "cigarette", charWidth, charHeight, xOffset)
                );
                // Add ember dot next to cigarette
                if (cigX + 1 < size) {
                    result = string.concat(
                        result, _renderTextWithClass(cigX + 1, cigY, "&#x2219;", "cigarette", charWidth, charHeight, xOffset)
                    );
                }
            }
        }

        // Arms
        seed = _random(seed);
        uint256 armCount = 1 + (seed % 4);
        seed = _random(seed);
        uint256 armLength = isKid ? (1 + (seed % 2)) : (2 + (seed % 4));
        string memory armChar = lineArms ? unicode"─" : "&#x2588;"; // line style uses ─, block style uses solid █

        for (uint256 a = 0; a < armCount; a++) {
            uint256 currentArmY = bodyStartY + 2 + a * (isKid ? 1 : 2);
            if (currentArmY >= bodyStartY + bodyHeight) break;
            for (uint256 i = 1; i <= armLength; i++) {
                if (cx - bodyWidth >= i) {
                    result = string.concat(
                        result, _renderTextWithClass(cx - bodyWidth - i, currentArmY, armChar, "arm", charWidth, charHeight, xOffset)
                    );
                }
                if (cx + bodyWidth + i < size) {
                    result = string.concat(
                        result, _renderTextWithClass(cx + bodyWidth + i, currentArmY, armChar, "arm", charWidth, charHeight, xOffset)
                    );
                }
            }
        }

        // Legs
        seed = _random(seed);
        uint256 legCount = 1 + (seed % 4);
        seed = _random(seed);
        uint256 legLength = isKid ? (1 + (seed % 2)) : (2 + (seed % 3));
        string memory legChar = lineLegs ? unicode"│" : "&#x2588;"; // line style uses │, block style uses solid █
        uint256 legY = bodyStartY + bodyHeight;

        if (legCount == 1) {
            for (uint256 i = 0; i < legLength; i++) {
                result = string.concat(result, _renderTextWithClass(cx, legY + i, legChar, "leg", charWidth, charHeight, xOffset));
            }
        } else if (legCount == 2) {
            uint256 legPos1 = cx - bodyWidth / 2;
            uint256 legPos2 = cx + bodyWidth / 2;
            for (uint256 i = 0; i < legLength; i++) {
                result = string.concat(
                    result,
                    _renderTextWithClass(legPos1, legY + i, legChar, "leg", charWidth, charHeight, xOffset),
                    _renderTextWithClass(legPos2, legY + i, legChar, "leg", charWidth, charHeight, xOffset)
                );
            }
        } else if (legCount >= 3) {
            uint256 legPos1 = cx - bodyWidth;
            uint256 legPos2 = cx;
            uint256 legPos3 = cx + bodyWidth;
            for (uint256 i = 0; i < legLength; i++) {
                result = string.concat(
                    result,
                    _renderTextWithClass(legPos1, legY + i, legChar, "leg", charWidth, charHeight, xOffset),
                    _renderTextWithClass(legPos2, legY + i, legChar, "leg", charWidth, charHeight, xOffset),
                    _renderTextWithClass(legPos3, legY + i, legChar, "leg", charWidth, charHeight, xOffset)
                );
            }
        }

        // Antennas
        seed = _random(seed);
        uint256 antennaCount = 1 + (seed % 4);
        seed = _random(seed);
        uint256 antennaLength = isKid ? 1 : (1 + (seed % 2));

        if (antennaCount == 1) {
            for (uint256 i = 1; i <= antennaLength; i++) {
                string memory aChar = (i == antennaLength) ? antennaTip : unicode"│";
                string memory aClass = (i == antennaLength) ? "antenna-tip" : "antenna";
                result = string.concat(
                    result, _renderTextWithClass(cx, bodyStartY - i, aChar, aClass, charWidth, charHeight, xOffset)
                );
            }
        } else if (antennaCount == 2) {
            uint256 aPos1 = cx - bodyWidth / 2;
            uint256 aPos2 = cx + bodyWidth / 2;
            for (uint256 i = 1; i <= antennaLength; i++) {
                string memory aChar = (i == antennaLength) ? antennaTip : unicode"│";
                string memory aClass = (i == antennaLength) ? "antenna-tip" : "antenna";
                result = string.concat(
                    result,
                    _renderTextWithClass(aPos1, bodyStartY - i, aChar, aClass, charWidth, charHeight, xOffset),
                    _renderTextWithClass(aPos2, bodyStartY - i, aChar, aClass, charWidth, charHeight, xOffset)
                );
            }
        } else if (antennaCount >= 3) {
            uint256 aPos1 = cx - bodyWidth;
            uint256 aPos2 = cx;
            uint256 aPos3 = cx + bodyWidth;
            for (uint256 i = 1; i <= antennaLength; i++) {
                string memory aChar = (i == antennaLength) ? antennaTip : unicode"│";
                string memory aClass = (i == antennaLength) ? "antenna-tip" : "antenna";
                result = string.concat(
                    result,
                    _renderTextWithClass(aPos1, bodyStartY - i, aChar, aClass, charWidth, charHeight, xOffset),
                    _renderTextWithClass(aPos2, bodyStartY - i, aChar, aClass, charWidth, charHeight, xOffset),
                    _renderTextWithClass(aPos3, bodyStartY - i, aChar, aClass, charWidth, charHeight, xOffset)
                );
            }
        }

        // Hat
        if (hatType > 0) {
            uint256 hatY = bodyStartY - antennaLength - 1;
            if (hatType == 1) {
                // Top hat with brim and stem
                for (uint256 dx = 0; dx <= 4; dx++) {
                    if (cx - 2 + dx < size) {
                        result = string.concat(
                            result, _renderTextWithClass(cx - 2 + dx, hatY, unicode"▀", "hat", charWidth, charHeight, xOffset)
                        );
                    }
                }
                // Add stem below brim (match JS renderer)
                if (hatY + 1 < size) {
                    result = string.concat(
                        result, _renderTextWithClass(cx, hatY + 1, "&#x2588;", "hat", charWidth, charHeight, xOffset)
                    );
                }
            } else if (hatType == 2) {
                // Flat hat
                for (uint256 dx = 0; dx <= 4; dx++) {
                    if (cx - 2 + dx < size) {
                        result = string.concat(
                            result, _renderTextWithClass(cx - 2 + dx, hatY, unicode"═", "hat", charWidth, charHeight, xOffset)
                        );
                    }
                }
            } else if (hatType == 3) {
                // Double hat
                for (uint256 dx = 0; dx <= 4; dx++) {
                    if (cx - 2 + dx < size && hatY > 0) {
                        result = string.concat(
                            result,
                            _renderTextWithClass(cx - 2 + dx, hatY - 1, unicode"▀", "hat", charWidth, charHeight, xOffset),
                            _renderTextWithClass(cx - 2 + dx, hatY, unicode"▄", "hat", charWidth, charHeight, xOffset)
                        );
                    }
                }
            } else if (hatType == 4) {
                // Fancy hat
                if (cx >= 2 && cx + 2 < size) {
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
        }

        return result;
    }

    function _random(uint256 seed) private pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed))) % 233280;
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
