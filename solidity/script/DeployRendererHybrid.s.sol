// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ProtocolitesMaster} from "../src/ProtocolitesMaster.sol";
import {ProtocolitesRendererHybrid} from "../src/ProtocolitesRendererHybrid.sol";

/**
 * @title DeployRendererHybrid
 * @author Protocolites Team
 * @notice Deployment script for upgrading to the Hybrid renderer with static SVG and optional JavaScript animations
 * @dev This script deploys the new Hybrid renderer, optionally reads a JavaScript file, and updates the existing Master contract
 *
 *      Deployment steps:
 *      1. Deploy ProtocolitesRendererHybrid (static SVG + optional JS animations)
 *      2. Optionally read renderer script file and set it via setRenderScript()
 *      3. Update existing ProtocolitesMaster to use the new renderer
 *
 *      Usage:
 *      export MASTER_ADDRESS=0x... (your existing Master contract address)
 *
 *      # Deploy with JavaScript animation support:
 *      export RENDERER_SCRIPT_PATH=renderer-v3.js
 *      forge script script/DeployRendererHybrid.s.sol:DeployRendererHybridScript \
 *        --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
 *
 *      # Deploy with static SVG only (no animation_url):
 *      forge script script/DeployRendererHybrid.s.sol:DeployRendererHybridScript \
 *        --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
 *
 *      Note: RENDERER_SCRIPT_PATH is relative to project root (where foundry.toml is located)
 *
 *      Features of Hybrid renderer:
 *      - Static SVG image (no CSS animations, pure SVG)
 *      - Optional JavaScript animation via animation_url
 *      - DOM-based rendering when JS is enabled
 *      - Temperament system (calm, balanced, energetic, chaotic, glitchy, unstable)
 *      - Per-character type tracking (body, eye, arm, leg, antenna, etc.)
 *      - Attribute-specific animations (breathing, blinking, waving, marching)
 *      - Row-based glitches and character corruption
 *      - JavaScript stored on-chain via SSTORE2 (optional)
 *      - Upgradeable render script
 */
contract DeployRendererHybridScript is Script {
    /**
     * @notice Main deployment function
     * @dev Reads PRIVATE_KEY and MASTER_ADDRESS from environment
     *      Optionally reads RENDERER_SCRIPT_PATH for JavaScript animation support
     *      Requires caller to be owner of the Master contract
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get existing master contract address from environment
        address masterAddress = vm.envAddress("MASTER_ADDRESS");

        console.log("Deploying ProtocolitesRendererHybrid (static SVG + optional JS)");
        console.log("Deployer address:", deployer);
        console.log("Target Master contract:", masterAddress);

        // Load the existing master contract
        ProtocolitesMaster master = ProtocolitesMaster(payable(masterAddress));

        // Verify deployer is owner of master contract
        require(master.owner() == deployer, "Deployer must be owner of Master contract");
        console.log("[OK] Ownership verified");

        // Check if RENDERER_SCRIPT_PATH is set
        string memory renderScript = "";
        bool hasScript = false;
        try vm.envString("RENDERER_SCRIPT_PATH") returns (string memory scriptPath) {
            if (bytes(scriptPath).length > 0) {
                // Build absolute path from project root
                string memory jsFilePath = string.concat(vm.projectRoot(), "/", scriptPath);
                console.log("\nReading JavaScript file from:", jsFilePath);
                renderScript = vm.readFile(jsFilePath);
                hasScript = true;
                console.log("[OK] JavaScript file loaded");
                console.log("   Script size:", bytes(renderScript).length, "bytes");
            }
        } catch {
            console.log("\nNo RENDERER_SCRIPT_PATH set - deploying without animation_url");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy new Hybrid renderer
        console.log("\nDeploying ProtocolitesRendererHybrid...");
        ProtocolitesRendererHybrid newRenderer = new ProtocolitesRendererHybrid();
        console.log("[OK] RendererHybrid deployed at:", address(newRenderer));

        // Step 2: Set the render script if provided (will be stored via SSTORE2)
        if (hasScript) {
            console.log("\nSetting render script via SSTORE2...");
            newRenderer.setRenderScript(renderScript);
            console.log("[OK] Render script stored on-chain");
            console.log("   animation_url will be included in metadata");
        } else {
            console.log("\nNo render script provided - static SVG only");
            console.log("   Only 'image' field will be in metadata (no animation_url)");
        }

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
        console.log("   New Hybrid Renderer:", address(newRenderer));
        console.log("");
        console.log("Hybrid Renderer Features:");
        console.log("   - Static SVG image (always available)");
        if (hasScript) {
            console.log("   - Animated HTML via animation_url (JS enabled)");
            console.log("   - DOM-based rendering (crisp text, no blur)");
            console.log("   - Per-character absolute positioning");
            console.log("   - Character type tracking system");
            console.log("   - Temperament-based animation intensity");
            console.log("   - Breathing, blinking, waving, marching animations");
            console.log("   - Row glitches and character corruption effects");
            console.log("   - JavaScript stored on-chain via SSTORE2");
        } else {
            console.log("   - No animation_url (can be added later via setRenderScript)");
        }
        console.log("   - Upgradeable render script (owner only)");
        console.log("");
        console.log("All existing and future NFTs will now use the Hybrid renderer!");
        if (!hasScript) {
            console.log("");
            console.log("To add JavaScript animations later, call:");
            console.log("   newRenderer.setRenderScript(javascriptCode)");
        }

        vm.stopBroadcast();
    }
}
