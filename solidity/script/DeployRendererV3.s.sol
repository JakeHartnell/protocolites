// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ProtocolitesMaster} from "../src/ProtocolitesMaster.sol";
import {ProtocolitesRendererV3} from "../src/ProtocolitesRendererV3.sol";

/**
 * @title DeployRendererV3
 * @author Protocolites Team
 * @notice Deployment script for upgrading to the V3 DOM-based renderer with SSTORE2 script storage
 * @dev This script deploys the new V3 renderer, reads the JavaScript file, and updates the existing Master contract
 *
 *      Deployment steps:
 *      1. Deploy ProtocolitesRendererV3 (DOM-based animations with SSTORE2)
 *      2. Read renderer-v3.js file and set it via setRenderScript()
 *      3. Update existing ProtocolitesMaster to use the new renderer
 *
 *      Usage:
 *      export MASTER_ADDRESS=0x... (your existing Master contract address)
 *      forge script script/DeployRendererV3.s.sol:DeployRendererV3Script \
 *        --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
 *
 *      Features of V3 renderer:
 *      - DOM-based rendering with per-character positioning
 *      - Crisp text rendering (no canvas blur)
 *      - Temperament system (calm, balanced, energetic, chaotic, glitchy, unstable)
 *      - Per-character type tracking (body, eye, arm, leg, antenna, etc.)
 *      - Attribute-specific animations (breathing, blinking, waving, marching)
 *      - Row-based glitches and character corruption
 *      - JavaScript stored on-chain via SSTORE2
 */
contract DeployRendererV3Script is Script {
    /**
     * @notice Main deployment function
     * @dev Reads PRIVATE_KEY and MASTER_ADDRESS from environment
     *      Requires caller to be owner of the Master contract
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get existing master contract address from environment
        address masterAddress = vm.envAddress("MASTER_ADDRESS");

        console.log("Deploying ProtocolitesRendererV3 (DOM-based with SSTORE2)");
        console.log("Deployer address:", deployer);
        console.log("Target Master contract:", masterAddress);

        // Load the existing master contract
        ProtocolitesMaster master = ProtocolitesMaster(payable(masterAddress));

        // Verify deployer is owner of master contract
        require(master.owner() == deployer, "Deployer must be owner of Master contract");
        console.log("[OK] Ownership verified");

        // Read the JavaScript file from the repository root
        string memory jsFilePath = string.concat(vm.projectRoot(), "/renderer-v3.js");
        console.log("\nReading JavaScript file from:", jsFilePath);
        string memory renderScript = vm.readFile(jsFilePath);
        console.log("[OK] JavaScript file loaded");
        console.log("   Script size:", bytes(renderScript).length, "bytes");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy new V3 renderer
        console.log("\nDeploying ProtocolitesRendererV3...");
        ProtocolitesRendererV3 newRenderer = new ProtocolitesRendererV3();
        console.log("[OK] RendererV3 deployed at:", address(newRenderer));

        // Step 2: Set the render script (will be stored via SSTORE2)
        console.log("\nSetting render script via SSTORE2...");
        newRenderer.setRenderScript(renderScript);
        console.log("[OK] Render script stored on-chain");

        // Step 3: Update master contract to use new renderer
        console.log("\nUpdating Master contract...");
        address oldRenderer = address(master.renderer());
        console.log("   Old renderer:", oldRenderer);

        master.setRenderer(address(newRenderer));
        console.log("[OK] Master.setRenderer() called");
        console.log("   New renderer:", address(master.renderer()));

        // Step 4: Deployment summary
        console.log("\n=== UPGRADE COMPLETE ===");
        console.log("Contract Addresses:");
        console.log("   Master Contract:", masterAddress);
        console.log("   Old Renderer:", oldRenderer);
        console.log("   New V3 Renderer:", address(newRenderer));
        console.log("");
        console.log("V3 Features:");
        console.log("   - DOM-based rendering (crisp text, no blur)");
        console.log("   - Per-character absolute positioning");
        console.log("   - Character type tracking system");
        console.log("   - Temperament-based animation intensity");
        console.log("   - Breathing, blinking, waving, marching animations");
        console.log("   - Row glitches and character corruption effects");
        console.log("   - JavaScript stored on-chain via SSTORE2");
        console.log("   - Upgradeable render script");
        console.log("");
        console.log("All existing and future NFTs will now use the V3 renderer!");

        vm.stopBroadcast();
    }
}
