// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Brrr} from "../contracts/Brrr.sol";
import {BrrrV2} from "../contracts/BrrrV2.sol";
import {IBlast} from "../contracts/interfaces/IBlast.sol";
import {IBlastPoints} from "../contracts/interfaces/IBlastPoints.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BrrrForkTest is Test {
    IBlast public blast = IBlast(0x4300000000000000000000000000000000000002); // mainnet address
    IBlastPoints public blastPoints =
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800); // mainnet address

    address public constant DEPLOYER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // getting from scan
    address public constant POINT_OPERATOR =
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    ProxyAdmin public proxyAdmin;
    address internal proxy;
    Brrr internal brrr;

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
        vm.mockCall(
            address(blastPoints),
            abi.encodeWithSelector(
                blastPoints.configurePointsOperator.selector
            ),
            ""
        );

        vm.startPrank(DEPLOYER);
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

    function test_ConfigurePointsOperatorOldContractVersion() public {
        vm.startPrank(DEPLOYER);
        vm.expectRevert();
        // call `configurePointsOperator` when proxy not yet upgraded to BrrrV2 contract
        BrrrV2(proxy).configurePointsOperator(
            address(blastPoints),
            POINT_OPERATOR
        );
    }

    function test_ConfigurePointsOperatorNotAllowed() public {
        vm.startPrank(DEPLOYER);
        Upgrades.upgradeProxy(proxy, "BrrrV2.sol", "");
        vm.stopPrank();

        // call `configurePointsOperator` when not owner
        vm.startPrank(POINT_OPERATOR);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                POINT_OPERATOR
            )
        );
        BrrrV2(proxy).configurePointsOperator(
            address(blastPoints),
            POINT_OPERATOR
        );
        vm.stopPrank();
    }

    function test_ConfigurePointsOperator() public {
        vm.startPrank(DEPLOYER);
        Upgrades.upgradeProxy(proxy, "BrrrV2.sol", "");
        // call `configurePointsOperator` when proxy not yet upgraded to BrrrV2 contract
        BrrrV2(proxy).configurePointsOperator(
            address(blastPoints),
            POINT_OPERATOR
        );
        vm.stopPrank();

        vm.assertEq(BrrrV2(proxy).pointsOperator(), POINT_OPERATOR);
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
