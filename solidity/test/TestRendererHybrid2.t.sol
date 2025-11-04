// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ProtocolitesRendererHybrid2.sol";
import "../src/interfaces/IProtocolitesRenderer.sol";

contract TestRendererHybrid2 is Test {
    ProtocolitesRendererHybrid2 renderer;

    function setUp() public {
        renderer = new ProtocolitesRendererHybrid2();
    }

    function testAnimatedSVGGeneration() public {
        // Create test token data
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x1234567890abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: 1000000
        });

        // Generate animated SVG
        string memory svg = renderer.generateSVG(1, data);

        // Check that SVG is generated
        assertTrue(bytes(svg).length > 0);

        // Check for SVG tag
        assertTrue(contains(svg, "<svg"));
        assertTrue(contains(svg, "</svg>"));

        // Check for SVG structure and embedded JavaScript animation
        assertTrue(contains(svg, "<svg"));
        assertTrue(contains(svg, "</svg>"));
        assertTrue(contains(svg, "<script>"));
        assertTrue(contains(svg, "requestAnimationFrame"));

        console.log("Animated SVG length:", bytes(svg).length);
    }

    function testKidAnimatedSVG() public {
        // Test kid (16x16)
        IProtocolitesRenderer.TokenData memory kidData = IProtocolitesRenderer.TokenData({
            dna: 0x1234567890abcdef,
            isKid: true,
            parentDna: 0x9876543210fedcba,
            parentContract: address(0),
            birthBlock: 1000000
        });

        string memory kidSvg = renderer.generateSVG(2, kidData);

        // Kids should have smaller viewBox (144x256)
        assertTrue(contains(kidSvg, "viewBox=\"0 0 144 256"));

        // Should have JavaScript animations
        assertTrue(contains(kidSvg, "<script>"));

        console.log("Kid animated SVG length:", bytes(kidSvg).length);
    }

    function testAdultAnimatedSVG() public {
        // Test adult (24x24)
        IProtocolitesRenderer.TokenData memory adultData = IProtocolitesRenderer.TokenData({
            dna: 0x1234567890abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: 1000000
        });

        string memory adultSvg = renderer.generateSVG(1, adultData);

        // Adults should have larger viewBox (288x480)
        assertTrue(contains(adultSvg, "viewBox=\"0 0 288 480"));

        // Should have JavaScript animations
        assertTrue(contains(adultSvg, "<script>"));

        console.log("Adult animated SVG length:", bytes(adultSvg).length);
    }

    function testMetadataNoAnimationUrl() public {
        // Create test token data
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x1234567890abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: 1000000
        });

        // Generate metadata
        string memory metadata = renderer.metadata(1, data);

        // Should have image field with SVG
        assertTrue(contains(metadata, '"image"'));
        assertTrue(contains(metadata, "data:image/svg+xml"));

        // Should NOT have animation_url field (using animated SVG as image)
        assertFalse(contains(metadata, '"animation_url"'));

        // Should mention animated SVG in description
        assertTrue(contains(metadata, "animated SVG"));

        console.log("Metadata length:", bytes(metadata).length);
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
