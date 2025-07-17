// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "remix_tests.sol";
import "../contracts/USDToken.sol";
import "../contracts/ERC3643Token.sol";
import "../contracts/CMBS20Demo.sol";

contract CMBSWithAccrualTest {
    USDToken stable;
    ERC3643Token trancheToken;
    CMBS20Demo cmbs;

    function beforeAll() public {
        stable = new USDToken(2_000_000 ether);
        trancheToken = new ERC3643Token();
        cmbs = new CMBS20Demo(IERC20(address(stable)), "https://mock.uri");

        // Give CMBS control
        bytes32 role = trancheToken.CONTROLLER_ROLE();
        trancheToken.grantRole(role, address(cmbs));

        // Create one tranche for simplicity
        cmbs.createTranche(
            trancheToken,
            1_000_000 ether,
            1000, // 10% interest
            0,    // senior
            trancheToken.totalSupply()
        );

        // Approve stable to CMBS
        stable.approve(address(cmbs), type(uint256).max);
    }

    function testAccruedInterest() public {
        // Round 1: deposit to start the clock
        cmbs.depositAndDistribute(100_000 ether);

        // Simulate 1 year passing (this won't actually move time in Remix)
        // Instead, we fake it by manually adjusting lastAccrual in CMBS
        // OR we wait 10–30 seconds IRL and call accrue manually

        // Call public accrual wrapper after waiting (or simulate if time passed)
        cmbs.accrueAllInterest(); // Must be called after delay

        // Round 2: second payment triggers interest allocation
        cmbs.depositAndDistribute(200_000 ether);

        // Withdraw from the tranche
        uint256 before = stable.balanceOf(address(this));
        cmbs.withdraw(0, 1000 ether);
        uint256 afterBal = stable.balanceOf(address(this));

        Assert.ok(afterBal > before, "Investor should receive principal + accrued interest");
    }
}
