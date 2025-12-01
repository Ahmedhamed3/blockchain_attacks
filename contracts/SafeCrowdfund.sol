// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SafeCrowdfund
/// @notice A fixed version of VulnerableCrowdfund demonstrating
/// Checks-Effects-Interactions (CEI) and proper access control.
contract SafeCrowdfund {
    address public owner;
    uint256 public targetAmount;
    uint256 public deadline;
    uint256 public totalRaised;
    bool public withdrawn;

    mapping(address => uint256) public contributions;

    event ContributionReceived(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(uint256 _targetAmount, uint256 _duration) {
        owner = msg.sender;
        targetAmount = _targetAmount;
        deadline = block.timestamp + _duration;
    }

    /// @notice Contribute ETH to the campaign.
    function contribute() external payable {
        require(msg.value > 0, "must send ETH");
        require(block.timestamp < deadline, "campaign ended");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit ContributionReceived(msg.sender, msg.value);
    }

    /// @notice Request a refund if the campaign failed.
    /// @dev Follows CEI pattern: checks, effects, interactions.
    function refund() external {
        require(block.timestamp >= deadline, "campaign active");
        require(totalRaised < targetAmount, "target met");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "nothing to refund");

        // EFFECTS: update state before interacting with external addresses.
        contributions[msg.sender] = 0;

        // INTERACTION: after state changes, transfer the funds.
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "send failed");

        emit Refunded(msg.sender, amount);
    }

    /// @notice Withdraw raised funds when the target has been met.
    /// @dev Protected by onlyOwner and a withdrawal guard to prevent double spend.
    function withdraw() external onlyOwner {
        require(block.timestamp >= deadline, "campaign active");
        require(totalRaised >= targetAmount, "target not met");
        require(!withdrawn, "already withdrawn");

        uint256 balance = address(this).balance;
        require(balance > 0, "nothing to withdraw");

        // EFFECTS: mark as withdrawn before sending funds to avoid reentrancy.
        withdrawn = true;

        (bool ok, ) = owner.call{value: balance}("");
        require(ok, "withdraw failed");

        emit Withdrawn(owner, balance);
    }
}