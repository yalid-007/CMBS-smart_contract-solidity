// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title GLDToken
 * @notice A simple ERC20 “Gold” token (GLD) with an initial mint.
 *         - Defaults to 18 decimals
 */
contract USDToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("USD", "USDC") {
        _mint(msg.sender, initialSupply);
    }
}
