// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {Vault} from "../src/Vault.sol";

contract VaultHandler is Test {
    Token public token;
    Vault public vault;

    address[] public actors;
    uint256 public sumDeposited;
    uint256 public sumWithdrawn;
    uint256 public callCount;

    constructor(Token _token, Vault _vault) {
        token = _token;
        vault = _vault;
        for (uint256 i = 0; i < 6; i++) {
            address a = address(uint160(0x2000 + i));
            actors.push(a);
            token.mint(a, 1e30);
            vm.prank(a);
            token.approve(address(vault), type(uint256).max);
        }
    }

    function deposit(uint256 actorSeed, uint256 assets) external {
        callCount++;
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint256 bal = token.balanceOf(actor);
        if (bal == 0) return;
        assets = bound(assets, 0, bal);
        vm.prank(actor);
        vault.deposit(assets, actor);
        sumDeposited += assets;
    }

    function withdraw(uint256 actorSeed, uint256 assets) external {
        callCount++;
        address actor = actors[bound(actorSeed, 0, actors.length - 1)];
        uint256 shares = vault.sharesOf(actor);
        if (shares == 0) return;
        assets = bound(assets, 0, shares);
        vm.prank(actor);
        vault.withdraw(assets, actor, actor);
        sumWithdrawn += assets;
    }

    function transferShares(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        callCount++;
        // No share-transfer surface here; treat as no-op to keep depth high without changing state.
        bound(fromSeed, 0, actors.length - 1);
        bound(toSeed, 0, actors.length - 1);
        bound(amount, 0, 1);
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }
}

contract VaultInvariants is Test {
    Token internal token;
    Vault internal vault;
    VaultHandler internal handler;

    function setUp() public {
        token = new Token();
        vault = new Vault(token);
        handler = new VaultHandler(token, vault);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = VaultHandler.deposit.selector;
        selectors[1] = VaultHandler.withdraw.selector;
        selectors[2] = VaultHandler.transferShares.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /// totalAssets == sumDeposited - sumWithdrawn.
    function invariant_assetsTrackFlows() public view {
        assertEq(vault.totalAssets(), handler.sumDeposited() - handler.sumWithdrawn(), "flow mismatch");
    }

    /// totalShares == totalAssets (1:1 vault).
    function invariant_sharesEqualAssets() public view {
        assertEq(vault.totalShares(), vault.totalAssets(), "share/asset mismatch");
    }

    /// Vault token balance >= totalAssets.
    function invariant_vaultSolvent() public view {
        assertGe(token.balanceOf(address(vault)), vault.totalAssets(), "insolvent");
    }

    /// Sum of per-user shares == totalShares.
    function invariant_sumSharesMatchesTotal() public view {
        uint256 sum;
        for (uint256 i = 0; i < handler.actorsLength(); i++) {
            sum += vault.sharesOf(handler.actors(i));
        }
        assertEq(sum, vault.totalShares(), "shares sum mismatch");
    }
}
