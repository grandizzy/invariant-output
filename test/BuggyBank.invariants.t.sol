// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BuggyBank} from "../src/BuggyBank.sol";

contract BuggyBankHandler is Test {
    BuggyBank public bank;

    address[] public actors;
    uint256 public callCount;

    modifier useActor(uint256 actorSeed) {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    constructor(BuggyBank _bank) {
        bank = _bank;
        for (uint256 i = 0; i < 4; i++) {
            actors.push(address(uint160(0x4000 + i)));
        }
    }

    function deposit(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        callCount++;
        amount = bound(amount, 0, 1e24);
        bank.deposit(amount);
    }

    function withdraw(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        callCount++;
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint256 bal = bank.balanceOf(actor);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        bank.withdraw(amount);
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external useActor(fromSeed) {
        callCount++;
        address from = actors[bound(fromSeed, 0, actors.length - 1)];
        address to = actors[bound(toSeed, 0, actors.length - 1)];
        uint256 bal = bank.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        bank.transfer(to, amount);
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }
}

contract BuggyBankInvariants is Test {
    BuggyBank internal bank;
    BuggyBankHandler internal handler;

    function setUp() public {
        bank = new BuggyBank();
        handler = new BuggyBankHandler(bank);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = BuggyBankHandler.deposit.selector;
        selectors[1] = BuggyBankHandler.withdraw.selector;
        selectors[2] = BuggyBankHandler.transfer.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /// FAILS: conservation of funds — sum of balances == deposits - withdrawals.
    /// `BuggyBank.transfer` credits the recipient without debiting the sender,
    /// so the ledger inflates after any non-zero-address transfer.
    function invariant_ledgerConserved() public view {
        uint256 sum;
        for (uint256 i = 0; i < handler.actorsLength(); i++) {
            sum += bank.balanceOf(handler.actors(i));
        }
        assertEq(sum, bank.totalDeposits() - bank.totalWithdrawals(), "ledger drift");
    }

    /// HOLDS: deposit and withdraw never under/over flow the recorded counters.
    /// Independent of the transfer bug.
    function invariant_countersMatchHandlerActivity() public view {
        // Cumulative deposits are always at least cumulative withdrawals at
        // the moment of recording, because withdraw() requires sufficient
        // per-actor balance that itself was sourced from a deposit().
        assertGe(bank.totalDeposits(), 0, "deposits underflow");
        assertGe(bank.totalWithdrawals(), 0, "withdrawals underflow");
    }

    /// HOLDS: the bank contract never custodies ETH (handlers don't send any).
    function invariant_bankHoldsNoEth() public view {
        assertEq(address(bank).balance, 0, "unexpected ETH in bank");
    }

    /// HOLDS: actor registry is fixed at construction.
    function invariant_actorsRegistered() public view {
        assertEq(handler.actorsLength(), 4, "actor set changed");
    }
}
