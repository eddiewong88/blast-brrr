// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Brrr} from "../contracts/Brrr.sol";
import {IBlast} from "../contracts/interfaces/IBlast.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract Reentrancy {
    receive() external payable {
        Brrr(msg.sender).burn(1);
    }
}

contract BrrrTest is Test {
    IBlast public blast = IBlast(0x4300000000000000000000000000000000000002);

    address public constant DEPLOYER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // getting from scan
    ProxyAdmin public proxyAdmin;
    TransparentUpgradeableProxy internal proxy;
    Brrr internal brrr;

    address public constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    uint256 public constant MINT_FEE = 0.1 ether;
    uint256 public constant MAX_SUPPLY = 1000;

    function setUp() public {
        // mockCalls to make test run
        vm.mockCall(
            address(blast),
            abi.encodeWithSelector(blast.configureClaimableGas.selector),
            ""
        );
        vm.mockCall(
            address(blast),
            abi.encodeWithSelector(blast.configureAutomaticYield.selector),
            ""
        );

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
        brrr.initialize(address(blast), MINT_FEE, MAX_SUPPLY); // Mint Fee: 0.1 ETH, Max Supply: 1,000 NFTs

        vm.stopPrank();
    }

    function test_upgrade() public {
        vm.startPrank(DEPLOYER);
        // new implementation of Brrr
        Brrr newBrrrImpl = new Brrr();
        // Deploy new Brrr implementation
        address newImplAddress = address(newBrrrImpl);

        // Use `upgradeAndCall` to upgrade the proxy to the new implementation and call the specified function
        ITransparentUpgradeableProxy upgradeableProxy = ITransparentUpgradeableProxy(
                address(proxy)
            );
        proxyAdmin.upgradeAndCall(
            upgradeableProxy,
            newImplAddress,
            new bytes(0)
        );
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
        assertEq(brrr.principal(), 1 * 1e17);
        assertEq(ALICE.balance, 4 * 1e17);

        deal(BOB, 3 * 1e17);
        vm.prank(BOB);
        // BOB mints another 4 NFTs
        brrr.mint{value: 1 * 1e17}();
        // Total supply should be 2, 1 (ALICE) + 1 (BOB)
        assertEq(brrr.totalSupply(), 2);
        assertEq(BOB.balance, 2 * 1e17);
        // Accumulate principal should 9 * MINT_FEE = 1e18
        assertEq(brrr.principal(), 2 * 1e17);
    }

    function test_mint_multiple() public {
        deal(ALICE, 1 ether);
        uint256 aliceMinted = 0;
        vm.startPrank(ALICE);
        // ALICE mints 1 NFT each loop
        for (uint256 i = 1; i <= 5; i++) {
            brrr.mint{value: 0.1 ether}();
            assertEq(brrr.totalSupply(), i);
            assertEq(brrr.principal(), i * MINT_FEE);
            assertEq(ALICE.balance, 1 ether - (i * MINT_FEE));
            assertEq(brrr.balanceOf(ALICE), i);
            aliceMinted = i;
        }
        vm.stopPrank();

        deal(BOB, 1 ether);
        vm.startPrank(BOB);
        // BOB mints 1 NFT each loop
        for (uint256 j = 1; j <= 5; j++) {
            brrr.mint{value: 0.1 ether}();
            assertEq(brrr.totalSupply(), aliceMinted + j);
            assertEq(brrr.principal(), (aliceMinted + j) * MINT_FEE);
            assertEq(BOB.balance, 1 ether - (j * MINT_FEE));
            assertEq(brrr.balanceOf(BOB), j);
        }
        vm.stopPrank();
    }

    function test_mint_exceed_supply() public {
        deal(ALICE, 10000 ether);
        uint256 aliceMinted = 0;
        vm.startPrank(ALICE);

        // ALICE mints 1 NFT each loop
        for (uint256 i = 1; i <= 1000; i++) {
            brrr.mint{value: 0.1 ether}();
            assertEq(brrr.totalSupply(), i);
            assertEq(brrr.principal(), i * MINT_FEE);
            assertEq(ALICE.balance, 10000 ether - (i * MINT_FEE));
            assertEq(brrr.balanceOf(ALICE), i);
            aliceMinted = i;
        }

        vm.expectRevert("exceed supply");
        brrr.mint{value: 0.1 ether}();
        vm.stopPrank();
    }

    function test_burn_should_refund_mintfee() public {
        deal(ALICE, 1e17);
        vm.prank(ALICE);
        // ALICE mints 1 NFT which id is `0`, pay mintFee = 0.1 ETH
        brrr.mint{value: 1e17}();
        assertEq(brrr.balanceOf(ALICE), 1);
        assertEq(brrr.totalSupply(), 1);
        assertEq(ALICE.balance, 0);
        assertEq(brrr.principal(), 1e17);

        vm.prank(ALICE);
        // ALICE burn her NFT, refund the mintFee = 0.1 ETH
        brrr.burn(1);
        assertEq(brrr.balanceOf(ALICE), 0);
        assertEq(brrr.totalSupply(), 0);
        assertEq(ALICE.balance, 1e17); // ALICE get refunded
        assertEq(brrr.principal(), 0);
    }

    function test_nonOwner_cannot_burn() public {
        deal(ALICE, 1e17);
        vm.prank(ALICE);
        // ALICE mints 1 NFT which id is `0`, pay mintFee = 0.1 ETH
        brrr.mint{value: 1e17}();
        assertEq(brrr.totalSupply(), 1);
        assertEq(ALICE.balance, 0);
        assertEq(brrr.principal(), 1e17);

        vm.prank(BOB);
        // ALICE burn her NFT, refund the mintFee = 0.1 ETH
        vm.expectRevert("Caller is not the owner");
        brrr.burn(1);
        assertEq(brrr.totalSupply(), 1);
        assertEq(ALICE.balance, 0); // ALICE not get refunded
        assertEq(brrr.principal(), 1e17);
    }

    function testSuccess_Claim_OwnerClaim_BalanceShouldIncrease() public {
        // Mint 1 NFT for ALICE
        deal(ALICE, 0.1 ether);
        vm.prank(ALICE);
        brrr.mint{value: 0.1 ether}();

        // Simulate earning yield
        deal(address(brrr), 0.2 ether);

        // Claim success, ALICE should receive 0.1 ether
        uint256 balanceBefore = ALICE.balance;
        vm.prank(ALICE);
        brrr.claim();
        assertEq(ALICE.balance - balanceBefore, 0.1 ether);
    }

    function testRevert_Claim_OwnerClaimButNoYield() public {
        // Mint 1 NFT for ALICE
        deal(ALICE, 0.1 ether);
        vm.prank(ALICE);
        brrr.mint{value: 0.1 ether}();

        // Claim no yield
        vm.prank(ALICE);
        vm.expectRevert("no yield");
        brrr.claim();
    }

    function testRevert_Claim_NonOwnerTryToClaim() public {
        // ALICE can't claim yet due to not owning any NFT
        vm.prank(ALICE);
        vm.expectRevert("no rights to claim");
        brrr.claim();
    }

    function testSuccess_PreviewClaimableYield() public {
        // Nothing yet
        assertEq(brrr.previewClaimableYield(), 0);

        // Principal with no yield
        deal(ALICE, 0.1 ether);
        vm.prank(ALICE);
        brrr.mint{value: 0.1 ether}();
        assertEq(brrr.previewClaimableYield(), 0);

        // Simulate earning yield
        deal(address(brrr), 0.2 ether);

        // There should be yield to claim
        assertEq(brrr.previewClaimableYield(), 0.1 ether);

        // Change in principal should not affect
        // Principal increase
        deal(ALICE, 0.1 ether);
        vm.prank(ALICE);
        brrr.mint{value: 0.1 ether}();
        assertEq(brrr.previewClaimableYield(), 0.1 ether);
        // Principal decrease
        vm.prank(ALICE);
        brrr.burn(1);
        assertEq(brrr.previewClaimableYield(), 0.1 ether);
    }

    function testSuccess_PrintItBabyprincipalShouldIncrease() public {
        // Print 0.1 ether to the contract
        deal(ALICE, 0.1 ether);
        vm.prank(ALICE);
        brrr.printItBaby{value: 0.1 ether}();
        assertEq(brrr.principal(), 0.1 ether);
    }

    function testRevert_Burn_Reentrancy() public {
        // Deploy Reentrancy contract
        address reentrancy = address(new Reentrancy());

        // Mint NFT
        deal(reentrancy, 0.1 ether);
        vm.prank(reentrancy);
        brrr.mint{value: 0.1 ether}();

        // Burn with reentrant
        vm.prank(reentrancy);
        // revert with ERC721NonexistentToken(1) from reentrant call which result in ETH send failure
        vm.expectRevert("Failed to send ETH");
        brrr.burn(1);
    }
}
