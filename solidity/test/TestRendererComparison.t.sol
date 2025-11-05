// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ProtocolitesRendererHybrid.sol";
import "../src/interfaces/IProtocolitesRenderer.sol";

contract TestRendererComparison is Test {
    ProtocolitesRendererHybrid renderer;

    function setUp() public {
        renderer = new ProtocolitesRendererHybrid();
    }

    function testRandomSequence() public {
        // Test that the random sequence matches JS LCG
        uint256 seed = 12345;

        // First random: (12345 * 9301 + 49297) % 233280 = 114870142 % 233280 = 96382
        uint256 r1 = (seed * 9301 + 49297) % 233280;
        assertEq(r1, 96382);

        // Second random: (96382 * 9301 + 49297) % 233280 = 896498279 % 233280 = 3239
        uint256 r2 = (r1 * 9301 + 49297) % 233280;
        assertEq(r2, 3239);

        // Third random: (3239 * 9301 + 49297) % 233280 = 30175236 % 233280 = 82116
        uint256 r3 = (r2 * 9301 + 49297) % 233280;
        assertEq(r3, 82116);
    }

    function testSVGGeneration() public {
        // Create test token data
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x1234567890abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: 1000000
        });

        // Generate SVG
        string memory svg = renderer.generateSVG(1, data);

        // Check that SVG is generated
        assertTrue(bytes(svg).length > 0);

        // Check for SVG tag
        assertTrue(contains(svg, "<svg"));
        assertTrue(contains(svg, "</svg>"));

        // Check for text elements (body parts)
        assertTrue(contains(svg, "<text"));

        console.log("SVG length:", bytes(svg).length);
    }

    function testKidVsAdult() public {
        uint256 testDna = 0x1234567890abcdef;

        // Test adult (24x24)
        IProtocolitesRenderer.TokenData memory adultData = IProtocolitesRenderer.TokenData({
            dna: testDna,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: 1000000
        });

        string memory adultSvg = renderer.generateSVG(1, adultData);

        // Test kid (16x16)
        IProtocolitesRenderer.TokenData memory kidData = IProtocolitesRenderer.TokenData({
            dna: testDna,
            isKid: true,
            parentDna: 0x9876543210fedcba,
            parentContract: address(0),
            birthBlock: 1000000
        });

        string memory kidSvg = renderer.generateSVG(2, kidData);

        // Log full outputs
        console.log("=== ADULT SVG ===");
        console.log(adultSvg);
        console.log("");
        console.log("=== KID SVG ===");
        console.log(kidSvg);
        console.log("");

        // Adults should have larger viewBox (square viewBox based on max dimension)
        // Adult: fontSize=20, charWidth=12, width=288, height=480, maxDim=480
        assertTrue(contains(adultSvg, "viewBox=\"0 0 480 480"));
        // Kid: fontSize=16, charWidth=9 (rounded), width=144, height=256, maxDim=256
        assertTrue(contains(kidSvg, "viewBox=\"0 0 256 256"));

        console.log("Adult SVG length:", bytes(adultSvg).length);
        console.log("Kid SVG length:", bytes(kidSvg).length);
    }

    function contains(string memory haystack, string memory needle) private pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length > haystackBytes.length) {
            return false;
        }

        for (uint i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }
}