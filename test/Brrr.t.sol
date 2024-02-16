// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { Brrr } from "../contracts/Brrr.sol";
import { IBlast } from "../contracts/interfaces/IBlast.sol";

contract BrrrTest is Test {
    Brrr public brrr;

    IBlast public blast = IBlast(0x4300000000000000000000000000000000000002);

    address public constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // getting from scan

    address public constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    uint256 public constant MINT_FEE = 1e17;

    function setUp() public {
        vm.createSelectFork("https://sepolia.blast.io");

        vm.startPrank(DEPLOYER);
        brrr = new Brrr(
            MINT_FEE, // 0.1 ETH
            1000 // 1,000 NFTs
        );

        vm.stopPrank();
    }

    function test_CheckRoyaltyInfo() public {
        deal(ALICE, 1e17);
        vm.prank(ALICE);
        brrr.mint{ value: 1e17 }(1);
        (address receiver, uint256 royaltyAmount) = brrr.royaltyInfo(1, MINT_FEE);

        // Receiver of the royalty should be the deployer
        assertEq(receiver, DEPLOYER);
        // Royalty amount should be 10% of MINT_FEE
        assertEq(royaltyAmount, MINT_FEE / 10);
    }

    function test_mint_multiple() public {
        deal(ALICE, 5 * 1e17);
        vm.prank(ALICE);
        // ALICE mints 5 NFTs
        brrr.mint{ value: 5 * 1e17 }(5);
        assertEq(brrr.totalSupply(), 5);
        assertEq(brrr._principal(), 5 * 1e17);
        assertEq(ALICE.balance, 0);

        deal(BOB, 4 * 1e17);
        vm.prank(BOB);
        // BOB mints another 4 NFTs
        brrr.mint{ value: 4 * 1e17 }(4);
        // Total supply should be 9, 5 (ALICE) + 4 (BOB)
        assertEq(brrr.totalSupply(), 9);
        assertEq(BOB.balance, 0);
        // Accumulate principal should 9 * MINT_FEE = 1e18
        assertEq(brrr._principal(), 9 * 1e17);
    }

    function test_burn_should_refund_mintfee() public {
        deal(ALICE, 1e17);
        vm.prank(ALICE);
        // ALICE mints 1 NFT which id is `0`, pay mintFee = 0.1 ETH
        brrr.mint{ value: 1e17 }(1);
        assertEq(brrr.totalSupply(), 1);
        assertEq(ALICE.balance, 0);
        assertEq(brrr._principal(), 1e17);

        vm.prank(ALICE);
        // ALICE burn her NFT, refund the mintFee = 0.1 ETH
        brrr.burn(0);
        assertEq(brrr.totalSupply(), 0);
        assertEq(ALICE.balance, 1e17); // ALICE get refunded
        assertEq(brrr._principal(), 0);
    }
}
