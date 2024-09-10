//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract RDXX is IERC20, Ownable(msg.sender) {
    string constant _name = "RDXX";
    string constant _symbol = "RDXX";
    uint8 constant _decimals = 6;

    uint256 _totalSupply = 10 * 10 ** 6 * (10 ** _decimals);

    struct VestingSchedule {
        uint256 totalAmountVested;
        uint256 amountReleased;
        uint256 vestingStart;
        uint256 intervals;
        uint256 percentPerInterval;
    }

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => bool) public isFeeExempt;
    mapping(address => bool) public isAuthorized;
    mapping(address => bool) public isBlocked;

    address public developmentWallet;
    address public rewardPoolWallet;

    uint256 private totalDevBalanceRDXX;
    uint256 private totalStakeBalanceRDXX;

    uint256 public sellDevFee = 75;
    uint256 public sellBurnFee = 75;
    uint256 public sellTotalFee = 150;

    uint256 public buyDevFee = 150;
    uint256 public buyBurnFee = 0;
    uint256 public buyStakeFee = 375;
    uint256 public buyTotalFee = 150;

    uint256 public totalBurn;

    uint256 public launchedAt;

    IERC20 public usdt;
    IUniswapV2Router02 public router;
    address public pair;

    bool public contractSwapEnabled = true;
    bool public isTradeEnabled = false;

    event SetIsFeeExempt(address holder, bool status);
    event AddAuthorizedWallet(address holder, bool status);
    event SetDoContractSwap(bool status);
    event DoContractSwap(uint256 amount, uint256 time);
    event ETHTransferFailed(address wallet, uint256 amount);

    constructor(address _usdt, address _development, address _reward, address _router) {
        usdt = IERC20(_usdt);
        router = IUniswapV2Router02(_router);
        pair = IUniswapV2Factory(router.factory()).createPair(
            _usdt,
            address(this)
        );
        _allowances[address(this)][address(router)] = type(uint256).max;

        developmentWallet = _development;
        rewardPoolWallet = _reward;

        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;
        isFeeExempt[developmentWallet] = true;

        isAuthorized[msg.sender] = true;
        isAuthorized[address(this)] = true;
        isAuthorized[developmentWallet] = true;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address holder,
        address spender
    ) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        update(msg.sender, recipient, amount);
        
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(
                _allowances[sender][msg.sender] >= amount,
                "Insufficient Allowance"
            );
            _allowances[sender][msg.sender] =
                _allowances[sender][msg.sender] -
                amount;
        }
        
        update(sender, recipient, amount);

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (!isTradeEnabled) require(isAuthorized[sender], "Trading disabled");

        if(!isTradeEnabled && sender == pair) require(isAuthorized[recipient], "Trading disabled");

        require(!isBlocked[sender] && !isBlocked[recipient], "Error not bought");
        
        require(_balances[sender] >= amount, "Insufficient Balance");

        _balances[sender] = _balances[sender] - amount;

        uint256 amountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, amount)
            : amount;

        _balances[recipient] = _balances[recipient] + amountReceived;

        emit Transfer(sender, recipient, amountReceived);

        return true;
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {
        uint256 feeToken;
        uint256 burnTokens;

        if (recipient == pair) {
            feeToken = (amount * sellTotalFee) / 10000;

            if (sellBurnFee > 0)
                burnTokens = (amount * sellBurnFee) / 10000;

            totalDevBalanceRDXX += feeToken - burnTokens;

        } else if (sender == pair) {
            feeToken = (amount * buyTotalFee) / 10000;

            uint256 addPercentDevBalanceSellRDXX = (feeToken * buyStakeFee) / 100000;

            uint256 subPercentStakeBalanceSellRDXX = feeToken - addPercentDevBalanceSellRDXX;

            totalDevBalanceRDXX += addPercentDevBalanceSellRDXX;
            totalStakeBalanceRDXX += subPercentStakeBalanceSellRDXX;
        }
        if (feeToken > 0) {
            if (burnTokens > 0) {
                totalBurn += burnTokens;
                _balances[address(0xdead)] = _balances[address(0xdead)] + burnTokens;
                emit Transfer(sender, address(0xdead), burnTokens);
            }
            
            _balances[address(this)] = _balances[address(this)] + (feeToken - burnTokens);

            emit Transfer(sender, address(this), (feeToken - burnTokens));
        }
        if (totalDevBalanceRDXX > 0) {
            _transferFrom(address(this), developmentWallet, totalDevBalanceRDXX);
        }
        if (totalStakeBalanceRDXX > 0) {
            _transferFrom(address(this), rewardPoolWallet, totalStakeBalanceRDXX);
        }
        totalDevBalanceRDXX = 0;
        totalStakeBalanceRDXX = 0;
        
        return (amount - feeToken);
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(_balances[sender] >= amount, "Insufficient Balance");
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function setupVesting(address beneficiary, uint256 totalAmount, uint256 percentPerInterval, uint256 intervals) external onlyOwner {
        require(beneficiary != address(0), "Invalid address");
        require(intervals > 0 && percentPerInterval > 0 && percentPerInterval <= 100, "Invalid vesting parameters");
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        schedule.totalAmountVested += totalAmount;
        schedule.vestingStart = block.timestamp;
        schedule.intervals = intervals;
        schedule.percentPerInterval = percentPerInterval;
        _transferFrom(msg.sender, beneficiary, totalAmount);
    }

    function update(address from, address to, uint256 amount) internal {
        if (from != address(0) && to != address(0) && from != owner()) {
            VestingSchedule storage schedule = vestingSchedules[from];
            if(schedule.totalAmountVested != 0 && schedule.vestingStart != 0 && schedule.intervals != 0 && schedule.percentPerInterval != 0) {
                require(block.timestamp >= schedule.vestingStart, "Vesting has not started yet");
                uint256 elapsedTime = block.timestamp - schedule.vestingStart;
                uint256 totalIntervalsPassed = elapsedTime / (30 days);
                if (totalIntervalsPassed > schedule.intervals) {
                    totalIntervalsPassed = schedule.intervals;
                }
                uint256 totalAmountVested = (schedule.totalAmountVested * schedule.percentPerInterval / 100) * totalIntervalsPassed;
                uint256 availableForTransfer = totalAmountVested - schedule.amountReleased;

                uint256 totalBalance = _balances[from];
                uint256 nonVestedBalance = totalBalance > schedule.totalAmountVested ? totalBalance - schedule.totalAmountVested + schedule.amountReleased : schedule.amountReleased;

                require(amount <= availableForTransfer + nonVestedBalance, "Transfer amount exceeds available balance");

                if (amount <= availableForTransfer + nonVestedBalance) {
                    if (amount <= availableForTransfer) {
                        schedule.amountReleased += amount;
                    }

                    if(schedule.amountReleased == schedule.totalAmountVested){
                        schedule.totalAmountVested = 0;
                        schedule.vestingStart = 0;
                        schedule.intervals = 0;
                        schedule.percentPerInterval = 0;
                    }
                } else {
                    revert("Transfer amount exceeds available balance");
                }
            }
        }
    }

    function shouldTakeFee(
        address sender,
        address to
    ) internal view returns (bool) {
        if (
            isFeeExempt[sender] ||
            isFeeExempt[to] ||
            (sender != pair && to != pair)
        ) {
            return false;
        } else {
            return true;
        }
    }

    function isFeeExcluded(address _wallet) public view returns (bool) {
        return isFeeExempt[_wallet];
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
        emit SetIsFeeExempt(holder, exempt);
    }

    function setDoContractSwap(bool _enabled) external onlyOwner {
        contractSwapEnabled = _enabled;
        emit SetDoContractSwap(_enabled);
    }

    function changeDevWallet(address _wallet) external onlyOwner {
        developmentWallet = _wallet;
    }

    function changeRewardPoolWallet(address _wallet) external onlyOwner {
        rewardPoolWallet = _wallet;
    }
    
    function changeSellFees(
        uint256 _sellDevFee,
        uint256 _sellBurnFee
    ) external onlyOwner {
        sellTotalFee = _sellDevFee + _sellBurnFee;
        require(sellTotalFee <= 150, "can not greater than 1.5%");
        sellBurnFee = _sellBurnFee;
        sellDevFee = _sellDevFee;
    }

    function changeBuyFees(
        uint256 _buyDevFee,
        uint256 _buyBurnFee
    ) external onlyOwner {
        buyTotalFee = _buyDevFee + _buyBurnFee;
        require(buyTotalFee <= 150, "can not greater than 1.5%");
        buyDevFee = _buyDevFee;
        buyBurnFee = _buyBurnFee;
    }

    function enableTrading() external onlyOwner {
        require(!isTradeEnabled, "Trading already enabled");
        launchedAt = block.timestamp;
        isTradeEnabled = true;
    }

    function setAuthorizedWallets(
        address _wallet,
        bool _status
    ) external onlyOwner {
        isAuthorized[_wallet] = _status;
    }

    function setBlockedWallets(
        address _wallet,
        bool _status
    ) external onlyOwner {
        isBlocked[_wallet] = _status;
    }

    function rescueETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No enough ETH to transfer");
        (bool success, ) = (msg.sender).call{value: balance}("");
        if (!success) emit ETHTransferFailed(msg.sender, balance);
    }

    function getBep20Tokens(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        require(_token != address(this), "Can not withdraw native tokens");
        IERC20(_token).transfer(msg.sender, _amount);
    }
}