// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "remix_tests.sol"; // Remix test runner
import "../contracts/USDToken.sol";
import "../contracts/ERC3643Token.sol";
import "../contracts/CMBS20Demo.sol";

contract CMBSWaterfallTest {
    USDToken stable;
    ERC3643Token tranche;
    CMBS20Demo cmbs;

    function beforeAll() public {
        // Deploy stablecoin
        stable = new USDToken(1_000_000 ether);

        // Deploy ERC3643-compliant tranche token
        tranche = new ERC3643Token();

        // Deploy CMBS waterfall contract
        cmbs = new CMBS20Demo(IERC20(address(stable)), "https://mock.uri");

        // Grant CONTROLLER_ROLE to CMBS for burning tokens
        bytes32 controllerRole = tranche.CONTROLLER_ROLE();
        tranche.grantRole(controllerRole, address(cmbs));

        // Create a tranche
        cmbs.createTranche(
            tranche,
            1_000_000 ether, // principal
            800,             // 8% coupon
            0,               // seniority
            tranche.totalSupply()
        );

        // Allocate tranche tokens to this contract (acting as investor)
        // Already true by default since msg.sender minted them

        // Allocate stable tokens to this contract and approve CMBS
        stable.approve(address(cmbs), 50_000 ether);
    }

    function testDepositAndWithdraw() public {
        // Deposit stablecoins into CMBS
        cmbs.depositAndDistribute(50_000 ether);

        // Withdraw funds as tranche token holder (address(this))
        uint256 before = stable.balanceOf(address(this));
        cmbs.withdraw(0, 1000 ether);
        uint256 afterBal = stable.balanceOf(address(this));

        Assert.ok(afterBal > before, "Investor should receive funds");
    }
}
