//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error FragmentPurchase__NftPriceMustBeGreaterThanZero();
error FragmentPurchase__PurchaseQuantityExceedsSupplyLimit();
error FragmentPurchase__InsufficientUSDTBalance();
error FragmentPurchase__InsufficientAllowance();
error FragmentPurchase__SalesAreCurrentlyDisabled();
error FragmentPurchase__InsufficientWithdrawUSDTBalance();
error FragmentPurchase__TransferFailedInPurchaseNFT();
error FragmentPurchase__WithdrawERC20Failed();
error FragmentPurchase__WithdrawFailed();
error FragmentPurchase__InsufficientWithdrawBalance();
error FragmentPurchase__AddressNotListedInWhiteList();

contract FragmentPurchase is ReentrancyGuard, Ownable {
    IERC20 private immutable usdcToken;

    bool public salesEnabled = false;
    uint256 public price = 1000e18;
    uint256 public totalSupply = 300;
    uint256 public supplySold;
    uint256 public totalRevenue;

    mapping(address => uint256) public userTotalPurchases;
    mapping(address => bool) public isFragmentUser;
    mapping(address => bool) public whiteListedUsers;

    event PurchaseNFT(address indexed fragmentUser, uint256 price);

    constructor(
        address _usdcTokenAddress
    ) Ownable(msg.sender) ReentrancyGuard() {
        usdcToken = IERC20(_usdcTokenAddress);
    }

    modifier salesAreEnabled() {
        if (!salesEnabled) revert FragmentPurchase__SalesAreCurrentlyDisabled();
        _;
    }

    modifier onlyWhiteListed() {
        if (!whiteListedUsers[msg.sender])
            revert FragmentPurchase__AddressNotListedInWhiteList();
        _;
    }

    function addMultipleToWhiteList(address[] memory _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            whiteListedUsers[_users[i]] = true;
        }
    }

    function addToWhiteList(address _user) public onlyOwner {
        whiteListedUsers[_user] = true;
    }

    function removeFromWhiteList(address _user) public onlyOwner {
        whiteListedUsers[_user] = false;
    }

    function toggleSales() public onlyOwner {
        salesEnabled = !salesEnabled;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function setTotalSupply(uint256 _totalSupply) public onlyOwner {
        totalSupply = _totalSupply;
    }

    function purchaseNFT() public nonReentrant salesAreEnabled onlyWhiteListed {
        if (price <= 0)
            revert FragmentPurchase__NftPriceMustBeGreaterThanZero();
        if (supplySold > totalSupply)
            revert FragmentPurchase__PurchaseQuantityExceedsSupplyLimit();
        uint256 userBalance = usdcToken.balanceOf(msg.sender);
        if (userBalance < price)
            revert FragmentPurchase__InsufficientUSDTBalance();
        uint256 allowance = usdcToken.allowance(msg.sender, address(this));
        if (allowance < price) revert FragmentPurchase__InsufficientAllowance();
        bool transferSuccess = usdcToken.transferFrom(
            msg.sender,
            address(this),
            price
        );
        if (!transferSuccess)
            revert FragmentPurchase__TransferFailedInPurchaseNFT();
        userTotalPurchases[msg.sender] += 1;
        totalRevenue += price;
        supplySold++;
        isFragmentUser[msg.sender] = true;
        emit PurchaseNFT(msg.sender, price);
    }

    function withdrawERC20() public onlyOwner nonReentrant {
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        if (contractBalance <= 0)
            revert FragmentPurchase__InsufficientWithdrawUSDTBalance();
        bool success = usdcToken.transfer(msg.sender, contractBalance);
        if (!success) revert FragmentPurchase__WithdrawERC20Failed();
    }

    function withdraw() public onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        if (contractBalance <= 0)
            revert FragmentPurchase__InsufficientWithdrawBalance();
        (bool success, ) = payable(owner()).call{value: contractBalance}("");
        if (!success) revert FragmentPurchase__WithdrawFailed();
    }

    receive() external payable {}
}
