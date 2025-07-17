// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "remix_tests.sol";
import "../contracts/USDToken.sol";
import "../contracts/ERC3643Token.sol";
import "../contracts/CMBS20Demo.sol";

contract CMBSWaterfallTest {
    USDToken stable;
    ERC3643Token seniorToken;
    ERC3643Token juniorToken;
    CMBS20Demo cmbs;

    function beforeAll() public {
        // 1. Mint more than enough tokens
        stable = new USDToken(2_000_000 ether);

        // 2. Deploy ERC-3643 tokens
        seniorToken = new ERC3643Token();
        juniorToken = new ERC3643Token();

        // 3. Deploy CMBS waterfall
        cmbs = new CMBS20Demo(IERC20(address(stable)), "https://mock.uri");

        // 4. Grant burn rights to CMBS
        bytes32 controller = seniorToken.CONTROLLER_ROLE();
        seniorToken.grantRole(controller, address(cmbs));
        juniorToken.grantRole(controller, address(cmbs));

        // 5. Create tranches using totalSupply
        cmbs.createTranche(seniorToken, 600_000 ether, 800, 0, seniorToken.totalSupply());
        cmbs.createTranche(juniorToken, 400_000 ether, 1200, 1, juniorToken.totalSupply());

        // ✅ Approve max allowance once for CMBS
        stable.approve(address(cmbs), type(uint256).max);
    }

    function testWaterfallOverTwoRounds() public {
        // Round 1
        try cmbs.depositAndDistribute(500_000 ether) {
            Assert.ok(true, "Round 1: deposit succeeded");
        } catch {
            Assert.ok(false, "Round 1: deposit failed");
        }

        uint256 seniorBefore = stable.balanceOf(address(this));
        try cmbs.withdraw(0, 1000 ether) {
            uint256 seniorAfter = stable.balanceOf(address(this));
            Assert.ok(seniorAfter > seniorBefore, "Senior withdrawal succeeded");
        } catch {
            Assert.ok(false, "Senior withdrawal reverted");
        }

        uint256 juniorBefore = stable.balanceOf(address(this));
        try cmbs.withdraw(1, 1000 ether) {
            uint256 juniorAfter = stable.balanceOf(address(this));
            Assert.ok(juniorAfter == juniorBefore, "Junior received nothing in round 1");
        } catch {
            Assert.ok(false, "Junior withdrawal reverted unexpectedly");
        }

        // Round 2
        try cmbs.depositAndDistribute(600_000 ether) {
            Assert.ok(true, "Round 2: deposit succeeded");
        } catch {
            Assert.ok(false, "Round 2: deposit failed");
        }

        uint256 juniorBefore2 = stable.balanceOf(address(this));
        try cmbs.withdraw(1, 1000 ether) {
            uint256 juniorAfter2 = stable.balanceOf(address(this));
            Assert.ok(juniorAfter2 > juniorBefore2, "Junior received funds in round 2");
        } catch {
            Assert.ok(false, "Junior withdrawal failed in round 2");
        }
    }
}
