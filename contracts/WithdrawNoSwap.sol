// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";


contract WithdrawNoSwap is Ownable, ReentrancyGuard {

    IERC20 private immutable usdcToken;
    IUniswapV2Router02 public router;

    uint256 private txFee = 8;
    uint256 private fee = txFee * 10 ** 17;
    uint256 public feeUsdtTotal;
    address private withdrawWallet;
    bool public withdrawEnabled = false;

    event Withdrawn(
        address indexed player,
        address indexed token,
        uint256 amount
    );
    
    constructor(address _usdcTokenAddress, address _router, address _owner) Ownable(_owner) ReentrancyGuard() {
        usdcToken = IERC20(_usdcTokenAddress);
        router = IUniswapV2Router02(_router);
    }

    modifier authorizedWallet {
        require(msg.sender == withdrawWallet, "Not authorized");
        _;
    }

    modifier withdrawAreEnabled {
        require(withdrawEnabled, "Whithdraw are currently disabled");
        _;
    }

    function withdrawNoSwap(address _player, uint256 _amount) public authorizedWallet nonReentrant withdrawAreEnabled {
        uint256 totalAmount = _amount - fee;
        uint256 contractBalance = usdcToken.balanceOf(address(this));

        require(contractBalance > 0, "Balance must be greater than zero");
        require(_amount > fee, "Amount must be greater than fees.");

        bool success = usdcToken.transfer(_player, totalAmount);

        require(success, "Withdraw ERC20 failed");

        feeUsdtTotal += fee;
        
        emit Withdrawn(_player, address(usdcToken), _amount);
    }

    function swapTotalFee() external authorizedWallet nonReentrant {
        usdcToken.approve(address(router), feeUsdtTotal);
        swapUSDCToETH(feeUsdtTotal);
    }

    function swapUSDCToETH(uint256 _tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(usdcToken);
        path[1] = router.WETH();
        usdcToken.approve(address(router), _tokenAmount);
        router.swapExactTokensForETH(
            _tokenAmount,
            0,
            path,
            msg.sender,
            block.timestamp
        );
    }

    function withdrawERC20() public onlyOwner nonReentrant {
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        require(contractBalance > 0, "Amount must be greater than zero");
        bool success = usdcToken.transfer(msg.sender, contractBalance);
        require(success, "Withdraw ERC20 failed");
    }

    function withdraFee() public onlyOwner nonReentrant {
        require(feeUsdtTotal > 0, "Amount must be greater than zero");
        bool success = usdcToken.transfer(msg.sender, feeUsdtTotal);
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

    function setAuthorized(address _authorized) public onlyOwner {
        withdrawWallet = _authorized;
    }

    function setFee(uint256 _txFee) external onlyOwner {
        txFee = _txFee;
    }

    function toggleWithdraw() public onlyOwner {
        withdrawEnabled = !withdrawEnabled;
    }

    receive() external payable {}
}