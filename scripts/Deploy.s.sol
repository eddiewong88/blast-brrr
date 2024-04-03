// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Brrr} from "../contracts/Brrr.sol";
import {IBlast} from "../contracts/interfaces/IBlast.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract Deploy is Script {
    address constant BLAST = 0x4300000000000000000000000000000000000002;

    uint256 internal deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    // Mint Fee: 0.1 ETH, Max Supply: 10,000 NFTs
    uint256 internal constant MINT_FEE = 0.1 ether;
    uint256 internal constant MAX_SUPPLY = 10000;

    function run() public {
        console2.log("Deploying Brrr...");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Brrr impl
        address proxy = Upgrades.deployTransparentProxy(
            "Brrr.sol",
            deployerAddress,
            abi.encodeCall(
                Brrr.initialize,
                (address(BLAST), MINT_FEE, MAX_SUPPLY)
            )
        );

        address proxyAdminAddress = Upgrades.getAdminAddress(proxy);
        vm.stopBroadcast();
        console2.log("Brrr deployed!");
        console2.log("Proxy (Brrr main contract):", proxy);
        console2.log("ProxyAdmin:", proxyAdminAddress);
    }
}
