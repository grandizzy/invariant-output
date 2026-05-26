// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "./Token.sol";

/// Minimal yield-less ERC4626-ish vault. shares == assets, no fees.
contract Vault {
    Token public immutable asset;
    uint256 public totalShares;
    uint256 public totalAssets;
    mapping(address => uint256) public sharesOf;

    constructor(Token _asset) {
        asset = _asset;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(receiver != address(0), "zero");
        asset.transferFrom(msg.sender, address(this), assets);
        shares = assets;
        totalShares += shares;
        totalAssets += assets;
        sharesOf[receiver] += shares;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        require(receiver != address(0), "zero");
        shares = assets;
        require(sharesOf[owner] >= shares, "shares");
        require(msg.sender == owner, "auth");
        sharesOf[owner] -= shares;
        totalShares -= shares;
        totalAssets -= assets;
        asset.transfer(receiver, assets);
    }
}
