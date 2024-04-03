// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Brrr} from "../contracts/Brrr.sol";
import {BrrrV2} from "../contracts/BrrrV2.sol";
import {IBlast} from "../contracts/interfaces/IBlast.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract Deploy is Script {
    uint256 internal deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    // brrr contract (mainnet)
    address internal proxy = "";

    function run() public {
        console2.log("Upgrading Brrr...");
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("deployer address", deployerAddress);
        vm.startBroadcast(deployerPrivateKey);

        Upgrades.upgradeProxy(proxy, "BrrrV2.sol:BrrrV2", "");
    }
}
