// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solady/utils/Base64.sol";
import "solady/utils/LibString.sol";
import "solady/auth/Ownable.sol";
import "solady/utils/SSTORE2.sol";

import "./interfaces/IProtocolitesRenderer.sol";

/// @title ProtocolitesRendererV3
/// @notice DOM-based renderer with per-character animations and temperament system
contract ProtocolitesRendererV3 is Ownable, IProtocolitesRenderer {
    address private renderScriptPointer;

    constructor() {
        _initializeOwner(msg.sender);
    }

    function setRenderScript(string memory _script) external onlyOwner {
        renderScriptPointer = SSTORE2.write(bytes(_script));
    }

    function tokenURI(uint256 tokenId, TokenData memory data) external view returns (string memory) {
        return string.concat("data:application/json;base64,", Base64.encode(bytes(metadata(tokenId, data))));
    }

    function metadata(uint256 tokenId, TokenData memory data) public view returns (string memory) {
        bool isKid = data.isKid;
        uint256 size = isKid ? 16 : 24;

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
            '"description":"Fully on-chain generative ASCII art with DOM-based rendering and per-character animations.",',
            '"animation_url":"data:text/html;base64,',
            Base64.encode(bytes(animation)),
            '",',
            '"attributes":',
            attributes,
            "}"
        );

        return json;
    }

    function renderScript() public view returns (string memory) {
        if (renderScriptPointer == address(0)) return "";
        return string(SSTORE2.read(renderScriptPointer));
    }
}
