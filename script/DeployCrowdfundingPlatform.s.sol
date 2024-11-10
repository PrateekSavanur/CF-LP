// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CrowdfundingPlatform.sol";

contract DeployCrowdfundingPlatform is Script {
    // Update these addresses with the correct Uniswap Router and Factory addresses for the network
    address constant UNISWAP_ROUTER_ADDRESS = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;
    address constant UNISWAP_FACTORY_ADDRESS = 0x7E0987E5b3a30e3f2828572Bb659A548460a3003;

    function run() external {
        // Load private key from environment or mnemonic for deploying
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start a broadcast with the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the CrowdfundingPlatform contract
        CrowdfundingPlatform platform = new CrowdfundingPlatform(UNISWAP_ROUTER_ADDRESS, UNISWAP_FACTORY_ADDRESS);

        // Stop the broadcast after deployment
        vm.stopBroadcast();

        // Log the deployed contract address
        console2.log("CrowdfundingPlatform deployed at:", address(platform));
    }
}
