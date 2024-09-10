// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract GamePoolContract is Ownable, ReentrancyGuard{

    IERC20 private immutable usdcToken;
    IERC20 private immutable RDXXToken;
    IUniswapV2Router02 public router;

    uint256 private txFee = 8;
    uint256 private totalFee = txFee * 10 ** 17;
    address private withdrawWallet;

    modifier authorizedWallet {
        require(msg.sender == withdrawWallet, "Not authorized");
        _;
    }

    event Withdrawn(
        address indexed player,
        address indexed token,
        uint256 amount
    );
    
    constructor(address _usdcTokenAddress, address _RDXXTokenAddress, address _router, address _owner) Ownable(_owner) ReentrancyGuard() {
        usdcToken = IERC20(_usdcTokenAddress);
        RDXXToken = IERC20(_RDXXTokenAddress);
        router = IUniswapV2Router02(_router);
    }

    function withdrawUsdc(address _player, uint256 _amount) public authorizedWallet nonReentrant {
        uint256 fee = (totalFee * 3);
        uint256 totalAmount = _amount - fee;
        require(_amount > fee, "Amount must be greater than fees.");
        usdcToken.approve(address(router), totalAmount);
        swapUSDCForTokens(totalAmount);
        uint balanceRDXX = RDXXToken.balanceOf(address(this));
        RDXXToken.approve(address(this), balanceRDXX);
        RDXXToken.approve(address(router), balanceRDXX);
        swapTokensForUSDC(balanceRDXX, _player);
        usdcToken.approve(address(router), fee);
        swapUSDCToETH(fee);
        emit Withdrawn(_player, address(usdcToken), _amount);
    }

    function withdrawToken(address _player, uint256 _amount) public authorizedWallet nonReentrant {
        uint256 fee = (totalFee * 2);
        uint256 totalAmount = _amount - fee;
        require(_amount > fee, "Amount must be greater than fees.");
        usdcToken.approve(address(router), totalAmount);
        swapUSDCForTokens(totalAmount);
        uint amoutToTransfer = RDXXToken.balanceOf(address(this));
        RDXXToken.approve(address(this), amoutToTransfer);
        RDXXToken.transferFrom(address(this), _player, amoutToTransfer);
        usdcToken.approve(address(router), fee);
        swapUSDCToETH(fee);
        emit Withdrawn(_player, address(RDXXToken), _amount);
    }

    function swapTokensForUSDC(uint256 _tokenAmount, address _player) private {
        address[] memory path = new address[](2);
        path[0] = address(RDXXToken);
        path[1] = address(usdcToken);
        RDXXToken.approve(address(router), _tokenAmount);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0,
            path,
            _player,
            block.timestamp
        );
    }

    function swapUSDCToETH(uint256 _tokenAmount) private {
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

    function swapUSDCForTokens(uint256 _tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(usdcToken);
        path[1] = address(RDXXToken);
        usdcToken.approve(address(router), _tokenAmount);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
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

    function setAuthorized(address _authorized) public onlyOwner {
        withdrawWallet = _authorized;
    }

    function setFee(uint256 _txFee) external onlyOwner {
        txFee = _txFee;
    }

    receive() external payable {}
}
