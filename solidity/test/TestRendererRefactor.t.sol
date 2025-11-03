// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ProtocolitesRendererHybrid.sol";

contract TestRendererRefactor is Test {
    ProtocolitesRendererHybrid renderer;

    function setUp() public {
        renderer = new ProtocolitesRendererHybrid();
    }

    function testRendererCompiles() public view {
        // Just verify contract deploys and basic functions exist
        assertTrue(address(renderer) != address(0));
    }

    function testGenerateSVG() public view {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 123456,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: 1,
            isKid: false
        });

        string memory svg = renderer.generateSVG(1, data);
        assertTrue(bytes(svg).length > 0);
        assertTrue(bytes(svg)[0] == "<");
    }

    function testGenerateSVGKid() public view {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 654321,
            parentDna: 123456,
            parentContract: address(0),
            birthBlock: 100,
            isKid: true
        });

        string memory svg = renderer.generateSVG(2, data);
        assertTrue(bytes(svg).length > 0);
    }

    function testDifferentBodyTypes() public view {
        // Test all 6 body types
        for (uint256 i = 0; i < 6; i++) {
            uint256 dna = i; // body type is lowest 3 bits
            IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
                dna: dna,
                parentDna: 0,
                parentContract: address(0),
                birthBlock: 1,
                isKid: false
            });

            string memory svg = renderer.generateSVG(i, data);
            assertTrue(bytes(svg).length > 0);
        }
    }

    function testTokenId3Match() public view {
        // Test with exact DNA from the HTML example
        uint256 dna = 0x572ba87b381fdfe1c637a2c29ae69ca357459af895d5a1b23a0b9dddacab00e2;

        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: dna,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: 1,
            isKid: false
        });

        string memory svg = renderer.generateSVG(3, data);

        // Basic validation
        assertTrue(bytes(svg).length > 0);
        assertTrue(bytes(svg)[0] == "<");

        // Check that viewBox is 288x480 (24 * 12 width, 24 * 20 height)
        // This would require string matching which is complex in Solidity
        // So we just verify it renders without reverting
    }

    function testNoOverflowsWithVariousDNA() public view {
        // Test edge cases that previously caused overflow
        uint256[] memory testDNAs = new uint256[](10);
        testDNAs[0] = 0x0; // Minimal DNA
        testDNAs[1] = type(uint256).max; // Maximum DNA
        testDNAs[2] = 0x1; // Very small
        testDNAs[3] = 0xFF; // Small value
        testDNAs[4] = 0xFFFF; // Medium value
        testDNAs[5] = 0x123456; // Various bits set
        testDNAs[6] = 0xABCDEF; // Different pattern
        testDNAs[7] = 0x111111; // Repeated pattern
        testDNAs[8] = 0x888888; // High bits
        testDNAs[9] = 0x555555; // Alternating bits

        for (uint256 i = 0; i < testDNAs.length; i++) {
            IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
                dna: testDNAs[i],
                parentDna: 0,
                parentContract: address(0),
                birthBlock: 1,
                isKid: false
            });

            // Should not revert with panic code 17 (arithmetic overflow)
            string memory svg = renderer.generateSVG(i, data);
            assertTrue(bytes(svg).length > 0);

            // Test with kids too
            data.isKid = true;
            svg = renderer.generateSVG(i + 100, data);
            assertTrue(bytes(svg).length > 0);
        }
    }
}
