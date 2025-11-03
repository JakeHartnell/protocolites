// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ProtocolitesRendererSVG.sol";
import "../src/interfaces/IProtocolitesRenderer.sol";

contract ProtocolitesRendererV3Test is Test {
    ProtocolitesRendererSVG public renderer;

    function setUp() public {
        renderer = new ProtocolitesRendererSVG();
    }

    function testGenerateSVGForSpreader() public {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: block.number
        });

        string memory svg = renderer.generateSVG(1, data);

        console.log("\n=== SPREADER SVG ===");
        console.log(svg);
        console.log("===================\n");

        // Check that SVG starts correctly
        assertTrue(bytes(svg).length > 0, "SVG should not be empty");
        assertTrue(_contains(svg, '<svg xmlns="http://www.w3.org/2000/svg"'), "Should contain SVG tag");
        assertTrue(_contains(svg, "viewBox"), "Should contain viewBox");
        assertTrue(_contains(svg, "</svg>"), "Should close SVG tag");
    }

    function testGenerateSVGForChild() public {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef012345678,
            isKid: true,
            parentDna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            parentContract: address(0x1111),
            birthBlock: block.number
        });

        string memory svg = renderer.generateSVG(2, data);

        console.log("\n=== CHILD SVG ===");
        console.log(svg);
        console.log("=================\n");

        // Check that SVG is generated
        assertTrue(bytes(svg).length > 0, "SVG should not be empty");
        assertTrue(_contains(svg, '<svg xmlns="http://www.w3.org/2000/svg"'), "Should contain SVG tag");
    }

    function testMetadataIncludesImage() public view {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: block.number
        });

        string memory metadata = renderer.metadata(1, data);

        // Check that metadata includes image field
        assertTrue(_contains(metadata, '"image"'), "Metadata should include image field");
        assertTrue(_contains(metadata, "data:image/svg+xml;base64,"), "Image should be base64 encoded SVG");
        assertTrue(_contains(metadata, '"animation_url"'), "Should still include animation_url");
        assertTrue(_contains(metadata, "data:text/html;base64,"), "Animation should be base64 encoded HTML");
    }

    function testTokenURIFormat() public view {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: block.number
        });

        string memory uri = renderer.tokenURI(1, data);

        // Check that URI is base64 encoded JSON
        assertTrue(_contains(uri, "data:application/json;base64,"), "Should be base64 encoded JSON");
    }

    function testFamilyColors() public view {
        // Test different DNA values to ensure different family colors
        uint256[6] memory testDNA = [
            uint256(0x1 << 17), // Should hash to different families
            uint256(0x2 << 17),
            uint256(0x3 << 17),
            uint256(0x4 << 17),
            uint256(0x5 << 17),
            uint256(0x6 << 17)
        ];

        for (uint256 i = 0; i < testDNA.length; i++) {
            IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
                dna: testDNA[i],
                isKid: false,
                parentDna: 0,
                parentContract: address(0),
                birthBlock: block.number
            });

            string memory svg = renderer.generateSVG(i + 1, data);
            assertTrue(bytes(svg).length > 0, "SVG should be generated for all DNA values");
            assertTrue(_contains(svg, "fill:#"), "Should contain color in fill attribute");
        }
    }

    function testSVGContainsCreatureElements() public view {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: block.number
        });

        string memory svg = renderer.generateSVG(1, data);

        // Check that SVG contains text elements (the creature is made of text elements)
        assertTrue(_contains(svg, "<text"), "Should contain text elements");
        assertTrue(_contains(svg, "</text>"), "Should close text elements");
        assertTrue(_contains(svg, 'x="'), "Text elements should have x coordinates");
        assertTrue(_contains(svg, 'y="'), "Text elements should have y coordinates");
    }

    function testDifferentSizesForSpreaderAndChild() public view {
        IProtocolitesRenderer.TokenData memory spreaderData = IProtocolitesRenderer.TokenData({
            dna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: block.number
        });

        IProtocolitesRenderer.TokenData memory childData = IProtocolitesRenderer.TokenData({
            dna: 0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef012345678,
            isKid: true,
            parentDna: spreaderData.dna,
            parentContract: address(0x1111),
            birthBlock: block.number
        });

        string memory spreaderSVG = renderer.generateSVG(1, spreaderData);
        string memory childSVG = renderer.generateSVG(2, childData);

        // Spreaders should have viewBox of 288x480 (24*12 x 24*20)
        assertTrue(_contains(spreaderSVG, "288"), "Spreader should have width 288");
        assertTrue(_contains(spreaderSVG, "480"), "Spreader should have height 480");

        // Children should have viewBox of 192x320 (16*12 x 16*20)
        assertTrue(_contains(childSVG, "192"), "Child should have width 192");
        assertTrue(_contains(childSVG, "320"), "Child should have height 320");
    }

    function testRenderScriptCanBeUpdated() public {
        string memory newScript = "console.log('test');";

        renderer.setRenderScript(newScript);

        assertEq(renderer.renderScript(), newScript, "Render script should be updated");
    }

    function testOnlyOwnerCanUpdateRenderScript() public {
        string memory newScript = "console.log('test');";

        vm.prank(address(0x1234)); // Not the owner
        vm.expectRevert(); // Should revert
        renderer.setRenderScript(newScript);
    }

    function testMetadataIncludesAttributes() public view {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: block.number
        });

        string memory metadata = renderer.metadata(1, data);

        // Check that metadata includes attributes
        assertTrue(_contains(metadata, '"attributes"'), "Should include attributes field");
        assertTrue(_contains(metadata, '"trait_type"'), "Should include trait_type");
        assertTrue(_contains(metadata, '"Type"'), "Should include Type trait");
        assertTrue(_contains(metadata, '"Size"'), "Should include Size trait");
        assertTrue(_contains(metadata, '"DNA"'), "Should include DNA trait");
        assertTrue(_contains(metadata, '"Birth Block"'), "Should include Birth Block trait");
    }

    function testChildMetadataIncludesParentDNA() public view {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef012345678,
            isKid: true,
            parentDna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            parentContract: address(0x1111),
            birthBlock: block.number
        });

        string memory metadata = renderer.metadata(2, data);

        // Check that child metadata includes parent DNA
        assertTrue(_contains(metadata, '"Parent DNA"'), "Child should include Parent DNA trait");
    }

    function testSpreaderMetadataDoesNotIncludeParentDNA() public view {
        IProtocolitesRenderer.TokenData memory data = IProtocolitesRenderer.TokenData({
            dna: 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef,
            isKid: false,
            parentDna: 0,
            parentContract: address(0),
            birthBlock: block.number
        });

        string memory metadata = renderer.metadata(1, data);

        // Check that spreader metadata does not include parent DNA
        assertFalse(_contains(metadata, '"Parent DNA"'), "Spreader should not include Parent DNA trait");
    }

    // Helper function to check if a string contains a substring
    function _contains(string memory haystack, string memory needle) private pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length > haystackBytes.length) {
            return false;
        }

        if (needleBytes.length == 0) {
            return true;
        }

        for (uint256 i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < needleBytes.length; j++) {
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
