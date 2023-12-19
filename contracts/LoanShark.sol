// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
    Supply native currency ETHER as collateral to receive stablecoin as loan for a fee and pay back anytime.
 */
contract LoanShark is Ownable, ReentrancyGuard {
    address public immutable stablecoin;

    // Fees in Ether
    uint256 public fee;
    uint256 public collectedFees;

    // Ratio of Stablecoin-ETH. If Ratio = 2 => Get 2 * x Stablecoins for x Ether
    uint256 public immutable ratio;

    // Currently borrowed amount of stablecoin
    uint256 public currentlyLent;
    mapping(address => uint256) public borrowed;

    // Allow borrowing or not
    bool public active = true;

    event SetFee(uint256 oldFee, uint256 newFee, address indexed owner);
    event SetActive(bool active, address indexed owner);
    event Borrow(
        address indexed borrower,
        address indexed stablecoin,
        uint256 amount,
        uint256 timestamp
    );
    event Repay(
        address indexed borrower,
        address indexed stablecoin,
        uint256 amount,
        uint256 timestamp
    );

    constructor(
        address _stablecoin,
        uint256 _ratio,
        uint256 _fee
    ) {
        require(_ratio > 0, "Zero ratio");
        stablecoin = _stablecoin;
        ratio = _ratio;
        fee = _fee;
    }

    // Owner specific functions
    function claimFees() external onlyOwner {
        uint256 amount = collectedFees;
        collectedFees = 0;

        payable(owner()).transfer(amount);
    }

    function claim(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }

    function setFee(uint256 _fee) external onlyOwner {
        emit SetFee(fee, _fee, msg.sender);
        fee = _fee;
    }

    function setActive(bool _active) external onlyOwner {
        emit SetActive(_active, msg.sender);
        active = _active;
    }

    // Main functions
    function ethBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function borrow() external payable nonReentrant {
        require(active, "Borrowing is paused");
        uint256 amount = msg.value;
        IERC20 token = IERC20(stablecoin);
        uint256 balance = token.balanceOf(address(this));

        require(
            amount > 0 && (amount * ratio) / 10**18 <= balance,
            "Cannot process amount"
        );

        currentlyLent += (amount * ratio) / 1e18;

        borrowed[msg.sender] += (amount * ratio) / 1e18;

        token.transfer(msg.sender, (amount * ratio) / 1e18);

        emit Borrow(msg.sender, stablecoin, amount, block.timestamp);
    }

    function repay(uint256 _amount) external nonReentrant {
        require(borrowed[msg.sender] >= _amount, "No Repay");

        uint256 finalAmount = (_amount / (ratio / 10**18)) - fee;
        require(ethBalance() >= finalAmount, "Insufficient ETH in Contract");

        collectedFees += fee;
        currentlyLent -= _amount;

        borrowed[msg.sender] -= _amount;

        IERC20 token = IERC20(stablecoin);
        token.transferFrom(msg.sender, address(this), _amount);
        payable(msg.sender).transfer(finalAmount);

        emit Repay(msg.sender, stablecoin, _amount, block.timestamp);
    }
}
