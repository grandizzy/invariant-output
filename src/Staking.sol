// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Token} from "./Token.sol";

/// Stake tokens for points. Points = staked * blocks held (rough).
contract Staking {
    Token public immutable token;
    uint256 public totalStaked;
    mapping(address => uint256) public stakedOf;
    mapping(address => uint256) public lastBlock;
    mapping(address => uint256) public points;

    constructor(Token _token) {
        token = _token;
    }

    function _accrue(address user) internal {
        uint256 last = lastBlock[user];
        if (last != 0 && stakedOf[user] != 0) {
            points[user] += stakedOf[user] * (block.number - last);
        }
        lastBlock[user] = block.number;
    }

    function stake(uint256 amount) external {
        _accrue(msg.sender);
        token.transferFrom(msg.sender, address(this), amount);
        stakedOf[msg.sender] += amount;
        totalStaked += amount;
    }

    function unstake(uint256 amount) external {
        require(stakedOf[msg.sender] >= amount, "stake");
        _accrue(msg.sender);
        stakedOf[msg.sender] -= amount;
        totalStaked -= amount;
        token.transfer(msg.sender, amount);
    }

    function claim() external returns (uint256 claimed) {
        _accrue(msg.sender);
        claimed = points[msg.sender];
        points[msg.sender] = 0;
    }
}
