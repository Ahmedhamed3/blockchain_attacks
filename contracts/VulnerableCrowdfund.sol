// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VulnerableCrowdfund
/// @notice Educational crowdfunding contract intentionally containing
/// reentrancy and access-control vulnerabilities. This contract is NOT safe
/// for production; it exists only to illustrate common pitfalls.
contract VulnerableCrowdfund {
    address public owner;
    uint256 public targetAmount;
    uint256 public deadline;
    uint256 public totalRaised;

    // Tracks how much each address contributed.
    mapping(address => uint256) public contributions;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    /// @param _targetAmount Goal for the crowdfunding campaign.
    /// @param _duration Duration in seconds from deployment until deadline.
    constructor(uint256 _targetAmount, uint256 _duration) {
        owner = msg.sender;
        targetAmount = _targetAmount;
        deadline = block.timestamp + _duration;
    }

    /// @notice Contribute ETH to the campaign.
    /// @dev No reentrancy risk here because only state is updated.
    function contribute() external payable {
        require(msg.value > 0, "must send ETH");
        require(block.timestamp < deadline, "campaign ended");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }

    /// @notice Request a refund if the campaign failed.
    /// @dev INTENTIONALLY VULNERABLE: follows "Interactions" before "Effects"
    /// which allows a reentrancy attack. The attacker can re-enter before
    /// their contribution is zeroed out, draining the contract.
    function refund() external {
        require(block.timestamp >= deadline, "campaign active");
        require(totalRaised < targetAmount, "target met");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "nothing to refund");

        // VULNERABILITY: External call before state update enables reentrancy.
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "send failed");

        // EFFECTS happen after the interaction, leaving the door open for
        // reentrancy to exploit the still-nonzero contributions balance.
        contributions[msg.sender] = 0;

        emit Refunded(msg.sender, amount);
    }

    /// @notice Withdraw all raised funds.
    /// @dev INTENTIONALLY VULNERABLE ACCESS CONTROL: anyone can withdraw or
    /// the check could be bypassed by tx.origin. There is no guard to stop
    /// double withdrawals either.
    function withdraw() external {
        // BUG: Missing onlyOwner modifier, so any caller can drain the funds.
        // Alternatively, using tx.origin here would also be insecure because
        // a malicious contract could trick the owner into calling it.

        uint256 balance = address(this).balance;
        require(balance > 0, "nothing to withdraw");

        (bool ok, ) = msg.sender.call{value: balance}("");
        require(ok, "withdraw failed");

        emit Withdrawn(msg.sender, balance);
    }
}