// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {Staking} from "../src/Staking.sol";

contract StakingHandler is Test {
    Token public token;
    Staking public staking;

    address[] public actors;
    uint256 public sumStaked;
    uint256 public sumUnstaked;
    uint256 public callCount;

    constructor(Token _token, Staking _staking) {
        token = _token;
        staking = _staking;
        for (uint256 i = 0; i < 4; i++) {
            address a = address(uint160(0x3000 + i));
            actors.push(a);
            token.mint(a, 1e30);
            vm.prank(a);
            token.approve(address(staking), type(uint256).max);
        }
    }

    function stake(uint256 actorSeed, uint256 amount) external {
        callCount++;
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint256 bal = token.balanceOf(actor);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        vm.prank(actor);
        staking.stake(amount);
        sumStaked += amount;
    }

    function unstake(uint256 actorSeed, uint256 amount) external {
        callCount++;
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint256 staked = staking.stakedOf(actor);
        if (staked == 0) return;
        amount = bound(amount, 0, staked);
        vm.prank(actor);
        staking.unstake(amount);
        sumUnstaked += amount;
    }

    function roll(uint256 blocks) external {
        callCount++;
        blocks = bound(blocks, 1, 100);
        vm.roll(block.number + blocks);
    }

    function claim(uint256 actorSeed) external {
        callCount++;
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.prank(actor);
        staking.claim();
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }
}

contract StakingInvariants is Test {
    Token internal token;
    Staking internal staking;
    StakingHandler internal handler;

    function setUp() public {
        token = new Token();
        staking = new Staking(token);
        handler = new StakingHandler(token, staking);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = StakingHandler.stake.selector;
        selectors[1] = StakingHandler.unstake.selector;
        selectors[2] = StakingHandler.roll.selector;
        selectors[3] = StakingHandler.claim.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /// totalStaked == sumStaked - sumUnstaked.
    function invariant_totalStakedTracksFlows() public view {
        assertEq(staking.totalStaked(), handler.sumStaked() - handler.sumUnstaked(), "flow mismatch");
    }

    /// Staking holds at least totalStaked tokens.
    function invariant_stakingSolvent() public view {
        assertGe(token.balanceOf(address(staking)), staking.totalStaked(), "insolvent");
    }

    /// Sum of per-user stakes == totalStaked.
    function invariant_sumStakesMatchesTotal() public view {
        uint256 sum;
        for (uint256 i = 0; i < handler.actorsLength(); i++) {
            sum += staking.stakedOf(handler.actors(i));
        }
        assertEq(sum, staking.totalStaked(), "stake sum mismatch");
    }
}
