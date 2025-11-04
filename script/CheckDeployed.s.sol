// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AaveAutopilot.sol";

contract CheckDeployed is Script {
    AaveAutopilot public autopilot = AaveAutopilot(payable(0xb896DaacC1987B2A547e101EA8334Cf3aB0AC19a));
    
    function run() external view {
        console.log("AaveAutopilot at: %s", address(autopilot));
        console.log("Asset: %s", autopilot.asset());
        console.log("Aave Pool: %s", autopilot.aavePool());
        console.log("Aave Data Provider: %s", autopilot.aaveDataProvider());
        console.log("Current Health Factor: %s", autopilot.getCurrentHealthFactor());
    }
}
