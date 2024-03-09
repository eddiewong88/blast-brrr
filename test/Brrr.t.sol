// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Brrr} from "../contracts/Brrr.sol";
import {IBlast} from "../contracts/interfaces/IBlast.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {MockBlast} from "./MockBlast.sol";

contract BrrrTest is Test {
    IBlast public blast;

    address public constant DEPLOYER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // getting from scan
    ProxyAdmin public proxyAdmin;
    TransparentUpgradeableProxy internal proxy;
    Brrr internal brrr;

    address public constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    uint256 public constant MINT_FEE = 1e17;

    function setUp() public {
        blast = IBlast(address(new MockBlast()));

        vm.startPrank(DEPLOYER);

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
        brrr = Brrr(address(proxy));
        brrr.initialize(address(blast), 1e17, 1000); // Mint Fee: 0.1 ETH, Max Supply: 1,000 NFTs

        vm.stopPrank();
    }

    function test_CheckRoyaltyInfo() public {
        deal(ALICE, 1e17);
        vm.prank(ALICE);
        brrr.mint{value: 1e17}();
        (address receiver, uint256 royaltyAmount) = brrr.royaltyInfo(
            1,
            MINT_FEE
        );

        // Receiver of the royalty should be the deployer
        assertEq(receiver, DEPLOYER);
        // Royalty amount should be 10% of MINT_FEE
        assertEq(royaltyAmount, MINT_FEE / 10);
    }

    function test_mint() public {
        deal(ALICE, 5 * 1e17);
        vm.prank(ALICE);
        // ALICE mints 1 NFT
        brrr.mint{value: 1 * 1e17}();
        assertEq(brrr.totalSupply(), 1);
        assertEq(brrr._principal(), 1 * 1e17);
        assertEq(ALICE.balance, 4 * 1e17);

        deal(BOB, 3 * 1e17);
        vm.prank(BOB);
        // BOB mints another 4 NFTs
        brrr.mint{value: 1 * 1e17}();
        // Total supply should be 2, 1 (ALICE) + 1 (BOB)
        assertEq(brrr.totalSupply(), 2);
        assertEq(BOB.balance, 2 * 1e17);
        // Accumulate principal should 9 * MINT_FEE = 1e18
        assertEq(brrr._principal(), 2 * 1e17);
    }

    function test_burn_should_refund_mintfee() public {
        deal(ALICE, 1e17);
        vm.prank(ALICE);
        // ALICE mints 1 NFT which id is `0`, pay mintFee = 0.1 ETH
        brrr.mint{value: 1e17}();
        assertEq(brrr.totalSupply(), 1);
        assertEq(ALICE.balance, 0);
        assertEq(brrr._principal(), 1e17);

        vm.prank(ALICE);
        // ALICE burn her NFT, refund the mintFee = 0.1 ETH
        brrr.burn(1);
        assertEq(brrr.totalSupply(), 0);
        assertEq(ALICE.balance, 1e17); // ALICE get refunded
        assertEq(brrr._principal(), 0);
    }

    function test_nonOwner_cannot_burn() public {
        deal(ALICE, 1e17);
        vm.prank(ALICE);
        // ALICE mints 1 NFT which id is `0`, pay mintFee = 0.1 ETH
        brrr.mint{value: 1e17}();
        assertEq(brrr.totalSupply(), 1);
        assertEq(ALICE.balance, 0);
        assertEq(brrr._principal(), 1e17);

        vm.prank(BOB);
        // ALICE burn her NFT, refund the mintFee = 0.1 ETH
        vm.expectRevert("Caller is not the owner");
        brrr.burn(1);
        assertEq(brrr.totalSupply(), 1);
        assertEq(ALICE.balance, 0); // ALICE not get refunded
        assertEq(brrr._principal(), 1e17);
    }
}
