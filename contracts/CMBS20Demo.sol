// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ERC3643Token.sol"; // <- Import the new token here

contract CMBS20Demo is AccessControl, Pausable {
    bytes32 public constant SERVICER_ROLE = keccak256("SERVICER_ROLE");

    struct Tranche {
        ERC3643Token token; // now using ERC3643-compliant token
        uint256 principal;
        uint256 couponBps;
        uint8 seniority;
        uint256 accruedInterest;
        uint256 cashAvailable;
    }

    string public uri;
    IERC20 public immutable stable;
    uint256 public nextTrancheId;
    uint256 public lastAccrual;
    mapping(uint256 => Tranche) public tranches;

    event TrancheCreated(uint256 indexed id, uint256 principal, uint256 couponBps, uint8 seniority, uint256 supply);
    event PaymentAllocated(uint256 indexed id, uint256 interestPaid, uint256 principalPaid);
    event Distribution(uint256 indexed id, address indexed investor, uint256 amount);
    event Withdraw(address indexed investor, uint256 indexed id, uint256 amount);

    constructor(IERC20 _stable, string memory _uri) {
        uri = _uri;
        stable = _stable;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SERVICER_ROLE, msg.sender);
        lastAccrual = block.timestamp;
    }

    // ------------------------------------------------------
    //  ADMIN / ISSUANCE
    // ------------------------------------------------------

    function createTranche(
        ERC3643Token token,
        uint256 principal,
        uint256 couponBps,
        uint8 seniority,
        uint256 supply
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(principal > 0, "INVALID_PRINCIPAL");
        require(supply > 0, "INVALID_SUPPLY");
        require(supply == token.totalSupply(), "INVALID_TOKEN_SUPPLY");

        uint256 id = nextTrancheId;
        nextTrancheId = id + 1;

        tranches[id] = Tranche({
            token: token,
            principal: principal,
            couponBps: couponBps,
            seniority: seniority,
            accruedInterest: 0,
            cashAvailable: 0
        });

        emit TrancheCreated(id, principal, couponBps, seniority, supply);
    }

    function distributeToInvestors(
        uint256 id,
        address[] calldata investors,
        uint256[] calldata amounts
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ERC3643Token token = tranches[id].token;
        require(investors.length == amounts.length, "ARRAY_LENGTH_MISMATCH");
        require(token.balanceOf(address(this)) >= _totalAmount(amounts), "INSUFFICIENT_ADMIN_BAL");

        for (uint256 i = 0; i < investors.length; ++i) {
            token.transfer(investors[i], amounts[i]);
            emit Distribution(id, investors[i], amounts[i]);
        }
    }

    function _totalAmount(uint256[] memory arr) internal pure returns (uint256 sum) {
        for (uint256 i = 0; i < arr.length; ++i) {
            sum += arr[i];
        }
    }

    // ------------------------------------------------------
    //  INTEREST ACCRUAL
    // ------------------------------------------------------


    function accrueAllInterest() public {
    _accrueAllInterest();
}


    function _accrueAllInterest() internal {
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0) return;
        lastAccrual = block.timestamp;


        for (uint256 id = 0; id < nextTrancheId; ++id) {
            Tranche storage t = tranches[id];
            if (t.principal == 0) continue;
            uint256 interest = (t.principal * t.couponBps * dt) / (365 days * 10_000);
            t.accruedInterest += interest;
        }
    }

    // ------------------------------------------------------
    //  WATERFALL DISTRIBUTION
    // ------------------------------------------------------

    function depositAndDistribute(uint256 amount)
        external
        whenNotPaused
        onlyRole(SERVICER_ROLE)
    {
        require(stable.transferFrom(msg.sender, address(this), amount), "TRANSFER_FAILED");
        _accrueAllInterest();

        uint256 remaining = amount;

        for (uint8 s = 0; s < 255 && remaining > 0; ++s) {
            for (uint256 id = 0; id < nextTrancheId && remaining > 0; ++id) {
                Tranche storage t = tranches[id];
                if (t.seniority != s) continue;

                uint256 payInt = t.accruedInterest <= remaining ? t.accruedInterest : remaining;
                t.accruedInterest -= payInt;
                t.cashAvailable  += payInt;
                remaining        -= payInt;

                uint256 payPrin = t.principal <= remaining ? t.principal : remaining;
                t.principal     -= payPrin;
                t.cashAvailable += payPrin;
                remaining       -= payPrin;

                emit PaymentAllocated(id, payInt, payPrin);
            }
        }

        emit PaymentAllocated(type(uint256).max, 0, remaining); // excess spread
    }

    // ------------------------------------------------------
    //  WITHDRAWALS
    // ------------------------------------------------------

    function withdraw(uint256 id, uint256 amount) external whenNotPaused {
        Tranche storage t = tranches[id];
        ERC3643Token token = t.token;
        require(token.balanceOf(msg.sender) >= amount, "INSUFFICIENT_BAL");

        uint256 proRata = (t.cashAvailable * amount) / token.totalSupply();
        t.cashAvailable -= proRata;

        token.burn(msg.sender, amount); // must be allowed by CONTROLLER_ROLE
        require(stable.transfer(msg.sender, proRata), "STABLE_TRANSFER_FAILED");
        emit Withdraw(msg.sender, id, proRata);
    }

    // ------------------------------------------------------
    //  PAUSE / SWEEP
    // ------------------------------------------------------

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }

    function sweep(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(stable.transfer(to, amount), "SWEEP_FAILED");
    }

    // ------------------------------------------------------
    //  VIEWS
    // ------------------------------------------------------

    function totalSupply(uint256 id) public view returns (uint256) {
        return tranches[id].token.totalSupply();
    }

    function totalSupply() public view returns (uint256 total) {
        for (uint256 id = 0; id < nextTrancheId; ++id) {
            total += totalSupply(id);
        }
    }

    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return tranches[id].token.balanceOf(account);
    }
}
