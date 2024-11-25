// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDeltaRewardPoolMultiple} from "./libs/IDeltaRewardPoolMultiple.sol";
import {Manager} from "./libs/Manager.sol";

contract UXLINKTokenRewardPoolMultiple is
    IDeltaRewardPoolMultiple,
    ReentrancyGuard,
    Manager
{
    using Address for address;
    using SafeERC20 for IERC20;

    bool private initialized;
    bool public withdrawOpened;

    uint256 public constant monthTime = 30 days;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 stakeTime; // month; limit = 36;
        uint256 stakeDuration;
        uint256 power; // How much weight the user has provided.
        uint256 reward; // Reward
        uint256 allReward; // Reward
        uint256 rewardPerTokenPaid;
    }
    address public devAddress;

    uint256 public constant MIN_DEPOSIT_AMOUNT = 0.00001 ether;
    uint256 public constant MIN_WITHDRAW_AMOUNT = 0.00001 ether;

    uint256 public constant basRate = 100000;
    uint256 public punishRate = 10000; // basRate = 100000; limit = 36;
    uint256[] public stakeTimeRatio; // basRate = 100000; limit = 36;

    // tokens of the pool!
    address public rewardToken;
    address public stakedToken;

    // all reward for pool
    uint256 public totalReward;

    uint256 public curCycleStartTime;
    uint256 public startStakeTime;

    uint256 public poolSurplusReward;
    uint256 public curCycleReward;
    uint256 public nextCycleReward;
    uint256 public nextDuration;

    uint256 public cycleTimes;
    uint256 public periodFinish;

    uint256 public totalPower;
    uint256 public totalAmount;

    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;

    // Info of each user that stakes tokens.
    mapping(address => UserInfo[]) public userInfo;

    event Stake(
        address indexed user,
        uint256 positionID,
        uint256 amount,
        uint256 power,
        uint256 duration
    );

    event Withdraw(
        address indexed user,
        uint256 positionID,
        uint256 punish,
        uint256 amount,
        uint256 power
    );
    event Harvest(address indexed user, uint256 amount, uint256 positionID);
    event SetStakeTimeRatio(uint256[] _stakeTimeRatio);
    event SetPunishRate(uint256 punishRate);
    event AddStakeTimeRatio(uint256[] _stakeTimeRatio);
    event AddNextCycleReward(uint256 rewardAmount);
    event SetRewardConfig(uint256 nextCycleReward, uint256 nextDuration);
    event StartNewEpoch(uint256 reward, uint256 duration);

    constructor() {
        setManager(msg.sender, true);
    }

    function initialize(
        address _devAddress,
        address _rewardToken,
        address _stakedToken,
        uint256 _curCycleStartTime,
        uint256 _duration,
        uint256 _nextCycleReward,
        uint256[] memory _stakeTimeRatio
    ) external onlyManager {
        require(!initialized, "initialize: Already initialized!");
        require(
            _stakeTimeRatio.length <= 36,
            "stakeTimeRatio length is invalid!"
        );

        withdrawOpened = true;
        devAddress = _devAddress;

        rewardToken = _rewardToken;
        stakedToken = _stakedToken;
        curCycleStartTime = _curCycleStartTime - _duration; // start time - duration
        periodFinish = _curCycleStartTime;
        nextDuration = _duration;
        startStakeTime = periodFinish;
        nextCycleReward = _nextCycleReward;
        stakeTimeRatio = _stakeTimeRatio;
        punishRate = 10000;

        initialized = true;
    }

    //for reward
    function notifyMintAmount(uint256 addNextReward) external onlyManager {
        uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
        IERC20(rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            addNextReward
        );
        uint256 balanceEnd = IERC20(rewardToken).balanceOf(address(this));

        poolSurplusReward = poolSurplusReward + (balanceEnd - balanceBefore);
        emit AddNextCycleReward(poolSurplusReward);
    }

    function setNextCycleReward(
        uint256 _nextCycleReward,
        uint256 _nextDuration
    ) external onlyManager {
        nextCycleReward = _nextCycleReward;
        nextDuration = _nextDuration;
        emit SetRewardConfig(nextCycleReward, nextDuration);
    }

    function setStakeTimeRatio(
        uint256[] memory _stakeTimeRatio
    ) external onlyManager {
        require(
            _stakeTimeRatio.length <= 36,
            "stakeTimeRatio length is invalid!"
        );
        stakeTimeRatio = _stakeTimeRatio;
        emit SetStakeTimeRatio(_stakeTimeRatio);
    }

    function setPunishRate(uint256 _punishRate) external onlyManager {
        punishRate = _punishRate;
        emit SetPunishRate(_punishRate);
    }

    function setWithdrawOpened(bool _opened) external onlyManager {
        withdrawOpened = _opened;
    }

    function addStakeTimeRatio(
        uint256[] memory _stakeTimeRatio
    ) external onlyManager {
        require(
            _stakeTimeRatio.length <= 36,
            "stake time Ratio length is too long"
        );
        for (uint256 i = 0; i < _stakeTimeRatio.length; i++) {
            stakeTimeRatio.push(_stakeTimeRatio[i]);
        }
        emit AddStakeTimeRatio(_stakeTimeRatio);
    }

    modifier checkNextEpoch() {
        if (block.timestamp >= periodFinish) {
            curCycleReward = nextCycleReward;
            require(
                poolSurplusReward >= nextCycleReward,
                "poolSurplusReward is not enough"
            );
            poolSurplusReward = poolSurplusReward - nextCycleReward;
            curCycleStartTime = block.timestamp;
            periodFinish = block.timestamp + (nextDuration);
            cycleTimes++;
            lastUpdateTime = curCycleStartTime;
            rewardRate = curCycleReward / (nextDuration);
            totalReward = totalReward + (curCycleReward);
            emit StartNewEpoch(curCycleReward, nextDuration);
        }
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            UserInfo[] storage users = userInfo[account];
            for (uint256 i = 0; i < users.length; i++) {
                if (users[i].power > 0) {
                    users[i].reward = earned(account, i);
                    users[i].rewardPerTokenPaid = rewardPerTokenStored;
                }
            }
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) / totalSupply());
    }

    function stakeForAddress(
        uint256 _amount,
        uint256 _durationType,
        address _stakerAddress
    ) external updateReward(_stakerAddress) checkNextEpoch onlyManager {
        // check stake amount
        require(_stakerAddress != address(0), "_stakerAddress is empty");
        require(block.timestamp >= startStakeTime, "not start");
        require(_amount > 0, "Cannot stake 0");
        require(_durationType > 0, "stake time is too short");
        require(_durationType <= 36, "stake time is too long");
        require(
            _amount > MIN_DEPOSIT_AMOUNT,
            "Deposit amount must be greater than MIN_DEPOSIT_AMOUNT"
        );

        // transfer token to this contract
        uint256 balanceBefore = IERC20(stakedToken).balanceOf(address(this));
        IERC20(stakedToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        uint256 balanceEnd = IERC20(stakedToken).balanceOf(address(this));
        uint256 currentAmount = balanceEnd - balanceBefore;
        uint256 stakePower = (currentAmount * (stakeTimeRatio[_durationType])) /
            (basRate);

        userInfo[_stakerAddress].push(
            UserInfo(
                currentAmount,
                block.timestamp,
                _durationType,
                stakePower,
                0,
                0,
                rewardPerTokenStored
            )
        );
        uint256 positionID = userInfo[_stakerAddress].length - 1;

        // update total info
        totalAmount = totalAmount + (currentAmount);
        totalPower = totalPower + (stakePower);

        emit Stake(
            _stakerAddress,
            positionID,
            currentAmount,
            stakePower,
            _durationType
        );
    }

    function stake(
        uint256 _amount,
        uint256 _durationType
    ) external updateReward(msg.sender) checkNextEpoch nonReentrant {
        // check stake amount
        require(block.timestamp >= startStakeTime, "not start");
        require(_amount > 0, "Cannot stake 0");
        require(_durationType > 0, "stake time is too short");
        require(_durationType <= 36, "stake time is too long");
        require(
            _amount > MIN_DEPOSIT_AMOUNT,
            "Deposit amount must be greater than MIN_DEPOSIT_AMOUNT"
        );

        // transfer token to this contract
        uint256 balanceBefore = IERC20(stakedToken).balanceOf(address(this));
        IERC20(stakedToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        uint256 balanceEnd = IERC20(stakedToken).balanceOf(address(this));
        uint256 currentAmount = balanceEnd - balanceBefore;
        uint256 stakePower = (currentAmount * (stakeTimeRatio[_durationType])) /
            (basRate);

        userInfo[msg.sender].push(
            UserInfo(
                currentAmount,
                block.timestamp,
                _durationType,
                stakePower,
                0,
                0,
                rewardPerTokenStored
            )
        );
        uint256 positionID = userInfo[msg.sender].length - 1;

        // update total info
        totalAmount = totalAmount + (currentAmount);
        totalPower = totalPower + (stakePower);

        emit Stake(
            msg.sender,
            positionID,
            currentAmount,
            stakePower,
            _durationType
        );
    }

    function fixUpdateUserPower(
        address user,
        uint256 positionID
    ) external updateReward(user) nonReentrant {
        UserInfo storage updateUser = userInfo[user][positionID];
        uint256 beforePower = updateUser.power;
        uint256 userPower = (updateUser.amount *
            (stakeTimeRatio[updateUser.stakeDuration])) / (basRate);
        require(userPower != beforePower, "userPower does not change");
        updateUser.power = userPower;
        totalPower = totalPower - beforePower + (userPower);
    }

    // Withdraw without caring about punish
    function withdraw(
        uint256 amount,
        uint256 positionID
    ) external updateReward(msg.sender) nonReentrant {
        require(withdrawOpened, "Have not opened");
        require(
            amount > MIN_WITHDRAW_AMOUNT,
            "Withdraw amount must be greater than MIN_WITHDRAW_AMOUNT"
        );
        UserInfo storage user = userInfo[msg.sender][positionID];
        require(user.amount > 0, "no stake amount");
        require(user.amount >= amount, "Overdrawing");

        uint256 reward = userInfo[msg.sender][positionID].reward;
        if (reward > 0) {
            user.allReward = user.allReward + (reward);
            user.reward = 0;
            safeTokenTransfer(msg.sender, reward);
            emit Harvest(msg.sender, reward, positionID);
        }

        // calculate withdraw power
        uint256 withdrawPower = (amount *
            (stakeTimeRatio[user.stakeDuration])) / (basRate);

        // update user info
        user.amount = user.amount - amount;
        user.power = user.power - withdrawPower;

        // update total info
        totalAmount = totalAmount - amount;
        totalPower = totalPower - withdrawPower;

        uint256 punish = punishStake(msg.sender, amount, positionID);
        // transfer token to user
        if (punish > 0) {
            IERC20(stakedToken).safeTransfer(devAddress, punish);
        }

        IERC20(stakedToken).safeTransfer(msg.sender, amount - punish);

        emit Withdraw(msg.sender, positionID, punish, amount, withdrawPower);
    }

    // (1-(lockTime/stakeTime))*10%
    function punishStake(
        address user,
        uint256 withdrawAmount,
        uint256 positionID
    ) public view returns (uint256) {
        UserInfo memory _userInfo = userInfo[user][positionID];
        uint256 stakeTime = _userInfo.stakeTime;
        uint256 _stakeDuration = _userInfo.stakeDuration;
        uint256 shouldDuration = _stakeDuration * monthTime;
        uint256 stopStake = stakeTime + shouldDuration;
        if (stopStake > block.timestamp) {
            uint256 lockTime = block.timestamp - stakeTime;
            uint256 punishRatio = (((1e18 -
                ((lockTime * 1e18) / shouldDuration)) * punishRate) / basRate);
            return (punishRatio * withdrawAmount) / 1e18;
        } else {
            return 0;
        }
    }

    function harvest(
        uint256 positionID
    ) external updateReward(msg.sender) nonReentrant {
        require(withdrawOpened, "Have not opened");
        uint256 reward = userInfo[msg.sender][positionID].reward;
        require(reward > 0, "no reward");
        UserInfo storage user = userInfo[msg.sender][positionID];
        user.allReward = user.allReward + (reward);
        user.reward = 0;
        safeTokenTransfer(msg.sender, reward);
        emit Harvest(msg.sender, reward, positionID);
    }

    function lastTimeRewardApplicable() internal view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function earned(
        address account,
        uint256 positionID
    ) public view returns (uint256) {
        UserInfo memory user = userInfo[account][positionID];
        return
            (user.power * (rewardPerToken() - (user.rewardPerTokenPaid))) /
            (1e18) +
            (user.reward);
    }

    function totalSupply() public view returns (uint256) {
        return totalPower;
    }

    function getUserStakeInfo(
        address user,
        uint256 positionID
    )
        external
        view
        override
        returns (
            uint256 power,
            uint256 amount,
            uint256 stakeTime,
            uint256 stakeDuration
        )
    {
        UserInfo memory _userInfo = userInfo[user][positionID];

        power = _userInfo.power;
        amount = _userInfo.amount;
        stakeTime = _userInfo.stakeTime;
        stakeDuration = _userInfo.stakeDuration;
    }

    // Safe slt transfer function, just in case if rounding error causes pool to not have enough SLTs.
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        require(rewardToken != address(0x0), "No harvest began");
        uint256 tokenBalance = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > tokenBalance) {
            IERC20(rewardToken).safeTransfer(_to, tokenBalance);
        } else {
            IERC20(rewardToken).safeTransfer(_to, _amount);
        }
    }
}
