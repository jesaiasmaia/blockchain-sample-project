// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract ArdoxusPurchaseContract is Ownable, ReentrancyGuard{

    address payable private poolRevenueContract;
    address payable private companyPoolContract;
    address payable private stakingContract;
    uint256 public totalRevenue;
    uint256 public availableToDistribute;
    bool public salesEnabled = false;
    IUniswapV2Router02 public router;

    IERC20 private immutable usdcToken;
    IERC20 private immutable RDXXToken;

    struct Box {
        uint256 price;
        uint256 supplySold;
    }

    mapping(uint256 => Box) public boxes;
    mapping(address => mapping(uint256 => uint256)) public userPurchases;
    mapping(address => uint256) public userTotalPurchases;
    mapping(uint256 => uint256) public totalPurchasesPerBox;
    address[] private purchasers;

    event PurchaseMade(
        address indexed buyer,
        uint256 boxId,
        uint256 quantity,
        uint256 totalPrice
    );
    event PaymentSent(
        address indexed recipient,
        uint256 amount,
        string description
    );
    
    constructor(address _usdcTokenAddress, address _RDXXTokenAddress, address _router, address _owner) Ownable(_owner) ReentrancyGuard() {
        router = IUniswapV2Router02(_router);
        usdcToken = IERC20(_usdcTokenAddress);
        RDXXToken = IERC20(_RDXXTokenAddress);
    }

    modifier salesAreEnabled {
        require(salesEnabled, "Sales are currently disabled");
        _;
    }

    function toggleSales() public onlyOwner {
        salesEnabled = !salesEnabled;
    }

    function registerBox(uint256 boxId, uint256 price) public onlyOwner {
        require(price > 0, "Price must be greater than zero");
        boxes[boxId] = Box(price, 0);
    }

    function purchaseBox(uint256 boxId, uint256 quantity) public nonReentrant salesAreEnabled {
        require(quantity > 0, "Quantity must be greater than zero");
        Box storage box = boxes[boxId];
        require(box.price > 0, "Box not available for purchase");
        
        uint256 totalPrice = box.price * quantity;
        
        uint256 userBalance = RDXXToken.balanceOf(msg.sender);
        require(userBalance >= totalPrice, "Insufficient RDXX balance");

        uint256 allowance = RDXXToken.allowance(msg.sender, address(this));
        require(allowance >= totalPrice, "Insufficient allowance");

        bool transferSuccess = RDXXToken.transferFrom(msg.sender, address(this), totalPrice);
        require(transferSuccess, "Transfer failed");

        userPurchases[msg.sender][boxId] += quantity;
        userTotalPurchases[msg.sender] += quantity;
        totalPurchasesPerBox[boxId] += quantity;
        totalRevenue += totalPrice;
        box.supplySold += quantity;
        
        if (!isPurchase(msg.sender)) {
            purchasers.push(msg.sender);
        }

        emit PurchaseMade(msg.sender, boxId, quantity, totalPrice);

        swapTokensForUSDC(totalPrice);

        availableToDistribute += usdcToken.balanceOf(address(this));
    }

    function manualPayment(uint256 _amount, address _to) public onlyOwner nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        require(contractBalance > 0, "Amount must be greater than zero");
        bool manualPaymentSuccess = usdcToken.transfer(_to, _amount);
        require(manualPaymentSuccess, "manualPayment failed");
        emit PaymentSent(_to, _amount, "Manual Payment");
    }

    function distributePayments() public onlyOwner nonReentrant {
        require(availableToDistribute > 0, "Amount must be greater than zero");
        require(poolRevenueContract != address(0), "Pool Revenue Contract address not set");
        require(companyPoolContract != address(0), "Company Pool Contract address not set");
        require(stakingContract != address(0), "Staking Contract address not set");
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        require(contractBalance > 0, "Amount must be greater than zero");

        uint256 poolRevenue = (availableToDistribute * 70) / 100;
        uint256 companyPool = (availableToDistribute * 20) / 100;
        uint256 stakingContractAmount = (availableToDistribute * 10) / 100;

        require(usdcToken.transfer(poolRevenueContract, poolRevenue), "Transfer to poolRevenueContract failed");
        require(usdcToken.transfer(companyPoolContract, companyPool), "Transfer to companyPoolContract failed");
        require(usdcToken.transfer(stakingContract, stakingContractAmount), "Transfer to stakingContract failed");

        emit PaymentSent(poolRevenueContract, poolRevenue, "Pool Revenue Contract");
        emit PaymentSent(companyPoolContract, companyPool, "Company Pool Contract");
        emit PaymentSent(stakingContract, stakingContractAmount, "Staking Contract");

        availableToDistribute -= poolRevenue;
        availableToDistribute -= companyPool;
        availableToDistribute -= stakingContractAmount;
    }

    function setPoolRevenueContract(address payable _poolRevenueContract) public onlyOwner {
        require(_poolRevenueContract != address(0), "Pool Revenue Contract address is not valid");
        poolRevenueContract = _poolRevenueContract;
    }

    function setCompanyPoolContract(address payable _companyPoolContract) public onlyOwner {
        require(_companyPoolContract != address(0), "Company Pool Contract address is not valid");
        companyPoolContract = _companyPoolContract;
    }

    function setStakingContract(address payable _stakingContract) public onlyOwner {
        require(_stakingContract != address(0), "Staking Contract address is not valid");
        stakingContract = _stakingContract;
    }

    function withdrawERC20() public onlyOwner nonReentrant {
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        require(contractBalance > 0, "Amount must be greater than zero");
        bool success = usdcToken.transfer(msg.sender, contractBalance);
        require(success, "Withdraw ERC20 failed");
    } 

    function withdraw() public onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "Amount must be greater than zero");
        (bool success, ) = payable(owner()).call{value: contractBalance}("");
        require(success, "Withdraw failed");
    }

    function getOwner() public view returns (address) {
        return owner();
    }

    function getCompany() public view returns (address) {
        return companyPoolContract;
    }

    function getStake() public view returns (address) {
        return stakingContract;
    }

    function getRevenue() public view returns (address) {
        return poolRevenueContract;
    }
    
    function isPurchase(address _address) public view returns (bool) {
        for (uint256 i = 0; i < purchasers.length; i++) {
            if(purchasers[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function getPurchases() public view returns (address[] memory) {
        return purchasers;
    }

    function swapTokensForUSDC(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> usdc
        address[] memory path = new address[](2);
        path[0] = address(RDXXToken);
        path[1] = address(usdcToken);

        RDXXToken.approve(address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of USDC
            path,
            address(this),
            block.timestamp
        );
    }

    receive() external payable {}
}
