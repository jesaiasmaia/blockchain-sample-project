// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingRewards {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;
    address public dev;

    bool public stakeEnabled = false;
    uint256 public duration;
    uint256 public start;
    uint256 public finishAt;

    uint256 public rewardTotal;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;

    uint256 public maxStakeAmount = 2500000000000; // DEFAULT = 2.500.000 - RDXX - 6 decimals
    uint256 public rewardPerToken = 60000000000000000; // DEFAULT = 0,06 - USDT - 18 decimals
    uint256 public limitTimerToEnterStake = 86400; // DEFAULT 86400 = 1 day in segunds

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balanceOf;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _stakingToken, address _rewardToken, address _dev) {
        owner = msg.sender;
        dev = _dev;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken;
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    modifier stakeAreEnabled {
        require(stakeEnabled, "Stake are currently disabled");
        _;
    }

    receive() external payable {}

    function setDevWallet(address _address) external onlyOwner{
        dev = _address;
    }

    function setStakeAreEnabled() external onlyOwner{
        stakeEnabled = !stakeEnabled;
    }

    function setRewardPerToken(uint256 _rewardPerToken) external onlyOwner{
        rewardPerToken = _rewardPerToken;
    }

    function setlimitTimerToEnterStake(uint256 _limitTimerToEnterStake) external onlyOwner{
        limitTimerToEnterStake = _limitTimerToEnterStake;
    }

    function setLimitMaxStake(uint256 _maxStakeAmount) external onlyOwner{
        maxStakeAmount = _maxStakeAmount;
    }

    function stake(uint256 _amount) external updateReward(msg.sender) stakeAreEnabled {
        uint256 timerSpace = start + limitTimerToEnterStake;
        require(timerSpace > block.timestamp, "Stake in process, wait the next");
        require(_amount > 0, "amount = 0");
        require(totalSupply <= maxStakeAmount, "Exceeded maximum stake amount");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
        rewards[msg.sender] = earned(msg.sender);
        emit Staked(msg.sender, _amount);
    }

    function withdraw() internal updateReward(msg.sender) {
        require(finishAt < block.timestamp, "reward duration not finished");
        require(balanceOf[msg.sender] > 0, "insufficient balance");
        uint256 amount = balanceOf[msg.sender];
        uint256 devAmount = amount / 10;
        uint256 userAmount = amount - devAmount;
        stakingToken.transfer(msg.sender, userAmount);
        stakingToken.transfer(dev, devAmount);
        balanceOf[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
    }

    function earned(address _account) public view returns (uint256) {
        uint256 reward = (balanceOf[_account] * rewardPerToken) / 1e6;
        return reward;
    }

    function finishStake() external view returns (bool) {
        if(block.timestamp > finishAt) {
            return true;
        } else {
            return false;
        }
    }

    function getReward() external updateReward(msg.sender) {
        require(finishAt < block.timestamp, "reward duration not finished");
        require(rewards[msg.sender] > 0, "insufficient reward");
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewardsToken.transfer(msg.sender, reward);
            rewardTotal -= reward;
            rewards[msg.sender] = 0;
            emit RewardPaid(msg.sender, reward);
            withdraw();
        }
    }

    //seconds
    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        start = block.timestamp;
        duration = _duration;
        finishAt = block.timestamp + duration;
        totalSupply = 0;
    }

    //150000000000000000000000
    function notifyRewardAmount(uint256 _amount)
        external
        onlyOwner
        updateReward(address(0))
    {
        rewardTotal = _amount;
        require(rewardTotal > 0, "reward rate = 0");
    }

    function rescueETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No enough ETH to transfer");
        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Withdraw failed");
    }

    function getBep20Tokens(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        require(_token != address(this), "Can not withdraw native tokens");
        IERC20(_token).transfer(msg.sender, _amount);
    }
}
