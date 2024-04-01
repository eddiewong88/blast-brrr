// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Brrr} from "../contracts/Brrr.sol";
import {IBlast} from "../contracts/interfaces/IBlast.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BrrrForkTest is Test {
    IBlast public blast = IBlast(0x4300000000000000000000000000000000000002);

    address public constant DEPLOYER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // getting from scan
    ProxyAdmin public proxyAdmin;
    address internal proxy;
    Brrr internal brrr;

    address public constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    uint256 public constant MINT_FEE = 0.1 ether;
    uint256 public constant MAX_SUPPLY = 1000;

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/blast");

        // `configureAutomaticYield` doesn't work yet. mockCall it to bypass the issue.
        vm.mockCall(
            address(blast),
            abi.encodeWithSelector(blast.configureAutomaticYield.selector),
            ""
        );

        vm.startPrank(DEPLOYER);

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin(DEPLOYER);
        // deploy proxy contract and point it to implementation
        proxy = Upgrades.deployTransparentProxy(
            "Brrr.sol",
            DEPLOYER,
            abi.encodeCall(
                Brrr.initialize,
                (address(blast), MINT_FEE, MAX_SUPPLY)
            )
        );
        brrr = Brrr(proxy);
        vm.stopPrank();
    }

    function test_Upgrade() public {
        vm.startPrank(DEPLOYER);
        Upgrades.upgradeProxy(proxy, "BrrrV2.sol", "");
        vm.stopPrank();
    }

    function test_DeployerIsGovernor() public {
        // Check if deployer is governor after deployment
        vm.prank(DEPLOYER);
        assertTrue(blast.isAuthorized(address(brrr)));

        // Check if deployer can claim gas
        vm.prank(DEPLOYER);
        vm.expectRevert("must withdraw non-zero amount");
        blast.claimAllGas(address(brrr), DEPLOYER);

        // Check if deployer can return govern rights back to contract itself
        vm.prank(DEPLOYER);
        blast.configureGovernorOnBehalf(address(brrr), address(brrr));
        vm.prank(address(brrr));
        assertTrue(blast.isAuthorized(address(brrr)));
    }
}
