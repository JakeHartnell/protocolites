// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ProtocolitesMaster} from "../src/ProtocolitesMaster.sol";
import {ProtocolitesRendererSVG} from "../src/ProtocolitesRendererSVG.sol";

/**
 * @title DeployRendererSVG
 * @author Protocolites Team
 * @notice Deployment script for upgrading to the SVG renderer with CSS animations
 * @dev This script deploys the new SVG renderer and updates the existing Master contract
 *
 *      Deployment steps:
 *      1. Deploy ProtocolitesRendererSVG (pure CSS animations, no JavaScript)
 *      2. Update existing ProtocolitesMaster to use the new renderer
 *
 *      Usage:
 *      export MASTER_ADDRESS=0x... (your existing Master contract address)
 *      forge script script/DeployRendererSVG.s.sol:DeployRendererSVGScript \
 *        --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
 *
 *      Features of SVG renderer:
 *      - Fully static SVG with CSS animations
 *      - No JavaScript required (marketplace compatible)
 *      - White square background for proper display
 *      - Temperament-based animation intensity
 *      - CSS keyframe animations for all creature parts
 *      - Matches V3 JavaScript renderer aesthetics
 */
contract DeployRendererSVGScript is Script {
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

        console.log("Deploying ProtocolitesRendererSVG (CSS animations)");
        console.log("Deployer address:", deployer);
        console.log("Target Master contract:", masterAddress);

        // Load the existing master contract
        ProtocolitesMaster master = ProtocolitesMaster(payable(masterAddress));

        // Verify deployer is owner of master contract
        require(master.owner() == deployer, "Deployer must be owner of Master contract");
        console.log("[OK] Ownership verified");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy new SVG renderer
        console.log("\nDeploying ProtocolitesRendererSVG...");
        ProtocolitesRendererSVG newRenderer = new ProtocolitesRendererSVG();
        console.log("[OK] RendererSVG deployed at:", address(newRenderer));

        // Step 2: Update master contract to use new renderer
        console.log("\nUpdating Master contract...");
        address oldRenderer = address(master.renderer());
        console.log("   Old renderer:", oldRenderer);

        master.setRenderer(address(newRenderer));
        console.log("[OK] Master.setRenderer() called");
        console.log("   New renderer:", address(master.renderer()));

        // Step 3: Deployment summary
        console.log("\n=== UPGRADE COMPLETE ===");
        console.log("Contract Addresses:");
        console.log("   Master Contract:", masterAddress);
        console.log("   Old Renderer:", oldRenderer);
        console.log("   New SVG Renderer:", address(newRenderer));
        console.log("");
        console.log("SVG Renderer Features:");
        console.log("   - Pure SVG with CSS animations (no JavaScript)");
        console.log("   - White square background for marketplace compatibility");
        console.log("   - Correct character spacing (kids: 9.6px, spreaders: 12px)");
        console.log("   - Temperament-based animation intensity");
        console.log("   - Breathing, blinking, waving, marching animations");
        console.log("   - Matches V3 JavaScript renderer aesthetics");
        console.log("   - OpenSea and Rarible compatible");
        console.log("");
        console.log("All existing and future NFTs will now use the SVG renderer!");

        vm.stopBroadcast();
    }
}
