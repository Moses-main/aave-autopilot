// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

interface IKeeperRegistry {
    function registerUpkeep(
        address target,
        uint32 gasLimit,
        address admin,
        bytes calldata checkData
    ) external returns (uint256 id);
    
    function addFunds(uint256 id, uint96 amount) external;
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DirectRegister is Script {
    function run() external {
        // Contract addresses
        address VAULT_ADDRESS = 0xcDe14d966e546D70F9B0b646c203cFC1BdC2a961;
        address KEEPER_REGISTRY = 0x7b3EC232b08BD7b4b3305BE0C044D907B2DF960B;
        address LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        
        // Parameters
        uint32 GAS_LIMIT = 1_000_000;
        uint96 AMOUNT = 5e18; // 5 LINK
        
        // Get private key from .env
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(privateKey);
        
        // Start broadcasting transactions
        vm.startBroadcast(privateKey);
        
        // Approve LINK transfer
        console.log("Approving LINK transfer...");
        IERC20(LINK_TOKEN).approve(KEEPER_REGISTRY, AMOUNT);
        
        // Register the upkeep
        console.log("Registering upkeep...");
        IKeeperRegistry registry = IKeeperRegistry(KEEPER_REGISTRY);
        uint256 upkeepId = registry.registerUpkeep(
            VAULT_ADDRESS,
            GAS_LIMIT,
            admin,
            abi.encode(admin) // Pass admin address as checkData
        );
        
        // Add funds to the upkeep
        console.log("Adding funds to upkeep...");
        registry.addFunds(upkeepId, AMOUNT);
        
        vm.stopBroadcast();
        
        console.log("Upkeep registered successfully with ID:", upkeepId);
        console.log("Admin address:", admin);
    }
}
