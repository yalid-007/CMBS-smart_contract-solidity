// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ERC3643Token is ERC20, AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("TrancheTokenA", "TTA") {
        address controller = 0x47574C311cD6C7F8b07CF18d776a25719c61EE22; // dummy controller address
        address minter     = 0x47574C311cD6C7F8b07CF18d776a25719c61EE22; // dummy minter address
        uint256 initialSupply = 1_000_000 * 10**decimals(); // mint 1M tokens

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONTROLLER_ROLE, controller);
        _grantRole(MINTER_ROLE, minter);

        _mint(msg.sender, initialSupply);
    }

    function burn(address from, uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        _burn(from, amount);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, amount); // Add compliance hooks here if needed
    }
}

