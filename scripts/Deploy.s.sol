// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Brrr} from "../contracts/Brrr.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract Deploy is Script {
    uint256 internal deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    ProxyAdmin internal proxyAdmin;
    TransparentUpgradeableProxy internal proxy;
    Brrr internal wrappedProxy;

    function run() public {
        console2.log("Deploying Brrr...");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin(address(this));
        // Deploy Brrr impl
        Brrr brrrImpl = new Brrr();
        // deploy proxy contract and point it to implementation
        proxy = new TransparentUpgradeableProxy(
            address(brrrImpl),
            address(proxyAdmin),
            ""
        );

        wrappedProxy = Brrr(address(proxy));
        wrappedProxy.initialize(1e17, 1000); // Mint Fee: 0.1 ETH, Max Supply: 1,000 NFTs

        vm.stopBroadcast();

        console2.log("Brrr deployed!");
        console2.log("Proxy:", address(proxy));
        console2.log("ProxyAdmin:", address(proxyAdmin));
        console2.log("Impl:", address(brrrImpl));
    }
}
