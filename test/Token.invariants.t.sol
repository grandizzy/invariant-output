// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";

contract TokenHandler is Test {
    Token public token;

    address[] public actors;
    mapping(address => bool) public isActor;

    uint256 public ghostMinted;
    uint256 public ghostBurned;
    uint256 public callCount;

    modifier useActor(uint256 actorSeed) {
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    constructor(Token _token) {
        token = _token;
        for (uint256 i = 0; i < 5; i++) {
            address a = address(uint160(0x1000 + i));
            actors.push(a);
            isActor[a] = true;
        }
    }

    function mint(uint256 toSeed, uint256 amount) external {
        callCount++;
        address to = actors[bound(toSeed, 0, actors.length - 1)];
        amount = bound(amount, 0, 1e24);
        token.mint(to, amount);
        ghostMinted += amount;
    }

    function burn(uint256 fromSeed, uint256 amount) external useActor(fromSeed) {
        callCount++;
        address from = actors[bound(fromSeed, 0, actors.length - 1)];
        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        token.burn(from, amount);
        ghostBurned += amount;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external useActor(fromSeed) {
        callCount++;
        address from = actors[bound(fromSeed, 0, actors.length - 1)];
        address to = actors[bound(toSeed, 0, actors.length - 1)];
        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        token.transfer(to, amount);
    }

    function approveAndTransferFrom(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amount)
        external
    {
        callCount++;
        address owner = actors[bound(ownerSeed, 0, actors.length - 1)];
        address spender = actors[bound(spenderSeed, 0, actors.length - 1)];
        address to = actors[bound(toSeed, 0, actors.length - 1)];
        uint256 bal = token.balanceOf(owner);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        vm.prank(owner);
        token.approve(spender, amount);
        vm.prank(spender);
        token.transferFrom(owner, to, amount);
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }
}

contract TokenInvariants is Test {
    Token internal token;
    TokenHandler internal handler;

    function setUp() public {
        token = new Token();
        handler = new TokenHandler(token);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = TokenHandler.mint.selector;
        selectors[1] = TokenHandler.burn.selector;
        selectors[2] = TokenHandler.transfer.selector;
        selectors[3] = TokenHandler.approveAndTransferFrom.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /// totalSupply == sum of balances.
    function invariant_totalSupplyEqualsSumOfBalances() public view {
        uint256 sum;
        for (uint256 i = 0; i < handler.actorsLength(); i++) {
            sum += token.balanceOf(handler.actors(i));
        }
        assertEq(sum, token.totalSupply(), "supply mismatch");
    }

    /// totalSupply == ghostMinted - ghostBurned.
    function invariant_totalSupplyMatchesGhost() public view {
        assertEq(token.totalSupply(), handler.ghostMinted() - handler.ghostBurned(), "ghost mismatch");
    }

    /// No individual balance exceeds totalSupply.
    function invariant_balancesBoundedBySupply() public view {
        uint256 supply = token.totalSupply();
        for (uint256 i = 0; i < handler.actorsLength(); i++) {
            assertLe(token.balanceOf(handler.actors(i)), supply, "bal > supply");
        }
    }

    function afterInvariant() public view {
        // Cheap diagnostic so progress output shows activity.
        assertGt(handler.callCount(), 0, "no calls made");
    }
}
