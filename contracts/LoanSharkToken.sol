// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
    Supply ANY ERC20 Token as collateral to receive stablecoin as loan for a fee and pay back anytime.
    CT = Collateral Token
    ST = Stablecoin Token
 */
contract LoanSharkToken is Ownable, ReentrancyGuard {
    address public immutable stablecoin;
    address public immutable collateralToken;

    // Fees in Ether
    uint256 public fee;
    uint256 public collectedFees;
    uint256 public totalCollectedFees;

    // Ratio of Stablecoin-CollateralToken(CT). If Ratio = 2 => Get 2 ST for 1 CT
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
        address indexed collateralToken,
        uint256 amount,
        uint256 timestamp
    );
    event Repay(
        address indexed borrower,
        address indexed stablecoin,
        address indexed collateralToken,
        uint256 amount,
        uint256 timestamp
    );

    constructor(
        address _stablecoin,
        address _collateralToken,
        uint256 _ratio,
        uint256 _fee
    ) {
        require(_ratio > 0, "Zero ratio");
        stablecoin = _stablecoin;
        collateralToken = _collateralToken;
        ratio = _ratio;
        fee = _fee;
    }

    // Owner specific functions

    // Can also call normal claim() function with the collateral token address and any amount
    function claimFees() external onlyOwner {
        uint256 amount = collectedFees;
        collectedFees = 0;

        IERC20(collateralToken).transfer(owner(), amount);
    }

    function claim(address _token, uint256 _amount) external onlyOwner {
        if (_token == collateralToken && _amount > collectedFees) {
            revert("Collateral token amount more than the collected fees");
        }
        IERC20(_token).transfer(owner(), _amount);
    }

    // Just in case someone sends native token to this contract accidently
    function claimETH() external onlyOwner {
        payable(owner()).transfer(ethBalance());
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

    // _amount is the Collateral Amount
    function borrow(uint256 _amount) external nonReentrant {
        require(active, "Borrowing is paused");

        // Transfer _amount of collateral token to the Smart Contract
        IERC20(collateralToken).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // Check if Smart Contract has enough stablecoin to loan out
        IERC20 token = IERC20(stablecoin);
        uint256 balance = token.balanceOf(address(this));

        require(
            _amount > 0 && (_amount * ratio) / 1e18 <= balance,
            "Cannot process amount"
        );

        currentlyLent += (_amount * ratio) / 1e18;

        collectedFees += fee;
        totalCollectedFees += fee;

        borrowed[msg.sender] += (_amount * ratio) / 1e18;

        // Transfer stablecoins to the borrower
        token.transfer(msg.sender, (_amount * ratio) / 1e18);

        emit Borrow(
            msg.sender,
            stablecoin,
            collateralToken,
            _amount,
            block.timestamp
        );
    }

    // Amount is the StableCoin amount
    function repay(uint256 _amount) external nonReentrant {
        require(borrowed[msg.sender] >= _amount, "No Repay");

        uint256 finalAmount = (_amount / (ratio / 1e18)) - fee;
        require(
            IERC20(collateralToken).balanceOf(address(this)) >= finalAmount,
            "Insufficient Collateral in Contract"
        );

        currentlyLent -= _amount;

        borrowed[msg.sender] -= _amount;

        // Get back the stablecoin loaned, from borrower
        IERC20(stablecoin).transferFrom(msg.sender, address(this), _amount);

        // Give back the collateral token minus the fees
        IERC20(collateralToken).transfer(msg.sender, finalAmount);

        emit Repay(
            msg.sender,
            stablecoin,
            collateralToken,
            _amount,
            block.timestamp
        );
    }
}
