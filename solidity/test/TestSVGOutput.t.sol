// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ProtocolitesRendererHybrid.sol";

contract TestSVGOutput is Test {
    ProtocolitesRendererHybrid renderer;

    function setUp() public {
        renderer = new ProtocolitesRendererHybrid();
    }

    function testPrintSVG() public view {
        uint256 dna = 0x572ba87b381fdfe1c637a2c29ae69ca357459af895d5a1b23a0b9dddacab00e2;

        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: dna,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: 1
        });

        string memory svg = renderer.generateSVG(3, data);

        // Print first 500 chars to see what's in the SVG
        console.log("SVG output (first 500 chars):");
        console.log(svg);
    }
}
