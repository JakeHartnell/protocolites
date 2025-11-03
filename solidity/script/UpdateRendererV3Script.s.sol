// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ProtocolitesRendererV3} from "../src/ProtocolitesRendererV3.sol";

/**
 * @title UpdateRendererV3Script
 * @author Protocolites Team
 * @notice Script to update the JavaScript render script in an existing V3 renderer
 * @dev This script ONLY updates the render script, does not deploy a new renderer
 *
 *      Usage:
 *      export RENDERER_V3_ADDRESS=0x... (your existing V3 renderer contract address)
 *      forge script script/UpdateRendererV3Script.s.sol:UpdateRendererV3Script \
 *        --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 *
 *      This will:
 *      1. Read renderer-v3.js from repository root
 *      2. Call setRenderScript() on the existing V3 renderer
 *      3. Store the updated script on-chain via SSTORE2
 */
contract UpdateRendererV3Script is Script {
    /**
     * @notice Main update function
     * @dev Reads PRIVATE_KEY and RENDERER_V3_ADDRESS from environment
     *      Requires caller to be owner of the V3 renderer contract
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get existing V3 renderer contract address from environment
        address rendererAddress = vm.envAddress("RENDERER_V3_ADDRESS");

        console.log("Updating ProtocolitesRendererV3 script");
        console.log("Deployer address:", deployer);
        console.log("Target V3 Renderer:", rendererAddress);

        // Load the existing V3 renderer contract
        ProtocolitesRendererV3 renderer = ProtocolitesRendererV3(rendererAddress);

        // Verify deployer is owner of renderer contract
        require(renderer.owner() == deployer, "Deployer must be owner of V3 renderer contract");
        console.log("[OK] Ownership verified");

        // Read the JavaScript file from the repository root
        string memory jsFilePath = string.concat(vm.projectRoot(), "/renderer-v3.js");
        console.log("\nReading JavaScript file from:", jsFilePath);
        string memory renderScript = vm.readFile(jsFilePath);
        console.log("[OK] JavaScript file loaded");
        console.log("   Script size:", bytes(renderScript).length, "bytes");

        vm.startBroadcast(deployerPrivateKey);

        // Update the render script (will be stored via SSTORE2)
        console.log("\nUpdating render script via SSTORE2...");
        renderer.setRenderScript(renderScript);
        console.log("[OK] Render script updated on-chain");

        // Summary
        console.log("\n=== UPDATE COMPLETE ===");
        console.log("V3 Renderer Address:", rendererAddress);
        console.log("Script size:", bytes(renderScript).length, "bytes");
        console.log("");
        console.log("All NFTs using this renderer will now use the updated script!");

        vm.stopBroadcast();
    }
}
