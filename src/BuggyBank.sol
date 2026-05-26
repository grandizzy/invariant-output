// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Minimal in-memory bank. Contains a deliberate accounting bug used to
/// produce a reproducible invariant failure for output sampling.
contract BuggyBank {
    uint256 public totalDeposits;
    uint256 public totalWithdrawals;
    mapping(address => uint256) public balanceOf;

    function deposit(uint256 amount) external {
        balanceOf[msg.sender] += amount;
        totalDeposits += amount;
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "balance");
        balanceOf[msg.sender] -= amount;
        totalWithdrawals += amount;
    }

    /// BUG: when sending to a non-zero address, the sender is not debited.
    /// Causes ledger to drift: sum(balanceOf) > totalDeposits - totalWithdrawals.
    function transfer(address to, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "balance");
        if (to == address(0)) {
            balanceOf[msg.sender] -= amount;
        }
        balanceOf[to] += amount;
    }
}
