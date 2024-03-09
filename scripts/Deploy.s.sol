// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Brrr} from "../contracts/Brrr.sol";
import {IBlast} from "../contracts/interfaces/IBlast.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract Deploy is Script {
    address constant BLAST = 0x4300000000000000000000000000000000000002;

    uint256 internal deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    // Mint Fee: 0.1 ETH, Max Supply: 1,000 NFTs
    uint256 internal constant MINT_FEE = 0.1 ether;
    uint256 internal constant MAX_SUPPLY = 1000;

    function run() public {
        console2.log("Deploying Brrr...");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ProxyAdmin
        address proxyAdmin = address(new ProxyAdmin(address(this)));
        // Deploy Brrr impl
        address brrrImpl = address(new Brrr());
        // Deploy proxy contract and point it to implementation
        address brrrProxy = address(
            new TransparentUpgradeableProxy(brrrImpl, proxyAdmin, "")
        );
        // Initialize Brrr contract
        Brrr(brrrProxy).initialize(BLAST, MINT_FEE, MAX_SUPPLY);

        // Use this if can't config within constructor. it fails simulation but works on-chain
        // IBlast(BLAST).configureAutomaticYieldOnBehalf(
        //     brrrProxy
        // );

        vm.stopBroadcast();

        // console2.log("Brrr deployed!");
        // console2.log("ProxyAdmin:", proxyAdmin);
        // console2.log("Proxy:", brrrProxy);
        // console2.log("Impl:", brrrImpl);
    }
}
