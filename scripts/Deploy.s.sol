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
        deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Brrr impl
        proxy = Upgrades.deployTransparentProxy(
            "Brrr.sol",
            DEPLOYER,
            abi.encodeCall(
                Brrr.initialize,
                (address(blast), MINT_FEE, MAX_SUPPLY)
            )
        );

        // // Use this if can't config within constructor. it fails simulation but works on-chain
        // // IBlast(BLAST).configureAutomaticYieldOnBehalf(
        // //     brrrProxy
        // // );

        address proxyAdminAddress = Upgrades.getAdminAddress(brrrProxy);
        vm.stopBroadcast();
        console2.log("Brrr deployed!");
        console2.log("Proxy (Brrr main contract):", proxy);
        console2.log("ProxyAdmin:", proxyAdminAddress);
        console2.log(
            "Impl:",
            TransparentUpgradeableProxy(proxy)._implementation()
        );
    }
}
