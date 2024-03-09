// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommonBase} from "forge-std/Base.sol";

/// @title MockBlast - Mock contract for Blast system contract. Testing only.
contract MockBlast is CommonBase {
    uint256 public nextYield;

    function configureClaimableYield() external {}

    function setNextYield(uint256 _yield) external {
        nextYield = _yield;
    }

    function readClaimableYield(address) external view returns (uint256) {
        return nextYield;
    }

    function claimAllYield(address, address _to) external returns (uint256) {
        uint256 _yield = nextYield;
        nextYield = 0;
        vm.deal(_to, _to.balance + _yield);
        return _yield;
    }

    function configureClaimableGas() external {}

    function configureGovernor(address) external {}

    function claimAllGas(address, address) external pure returns (uint256) {
        return 0;
    }
}
