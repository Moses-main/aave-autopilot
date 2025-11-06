// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKeeperRegistry {
    function register(
        string memory name,
        bytes calldata encryptedEmail,
        address upkeepContract,
        uint32 gasLimit,
        address adminAddress,
        bytes calldata checkData,
        bytes calldata offchainConfig,
        uint96 amount,
        address sender
    ) external;
}

contract SimpleRegister is Script {
    function run() external {
        // Contract addresses - Update these with your deployed contract addresses
        address VAULT_ADDRESS = 0xcDe14d966e546D70F9B0b646c203cFC1BdC2a961;
        address KEEPER_REGISTRY = 0x7b3EC232b08BD7b4b3305BE0C044D907B2DF960B;
        address LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        
        // Hardcoded admin and sender address (using the wallet with LINK balance)
        address admin = 0xe81e8078f2D284C92D6d97B5d4769af81e0cA11C; // Checksum format
        
        // Get private key from .env
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
        // Log the admin address for verification
        console.log("Admin address:", admin);
        
        // Start broadcasting
        vm.startBroadcast(privateKey);
        
        // Get LINK token interface
        IERC20 link = IERC20(LINK_TOKEN);
        
        // First, approve the Keeper Registry to spend LINK
        console.log("Approving LINK transfer...");
        bool success = link.approve(KEEPER_REGISTRY, 5e18);
        require(success, "LINK approval failed");
        
        // Small delay to ensure the approval is processed
        console.log("LINK approved. Registering upkeep...");
        
        // Register the upkeep
        IKeeperRegistry registry = IKeeperRegistry(KEEPER_REGISTRY);
        registry.register(
            "AaveAutopilot Keeper", // name
            "",                     // encryptedEmail
            VAULT_ADDRESS,          // upkeepContract
            1000000,                // gasLimit
            admin,                  // adminAddress
            "",                     // checkData
            "",                     // offchainConfig
            5e18,                   // amount (5 LINK)
            admin                   // sender
        );
        
        console.log("Upkeep registration submitted!");
        console.log("Please check your wallet to confirm the transaction.");
        vm.stopBroadcast();
    }
}
