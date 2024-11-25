// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title IDeltaRewardPoolMultiple
 * @dev IDeltaRewardPoolMultiple interface
 * stakePool
 */
interface IDeltaRewardPoolMultiple {
    function getUserStakeInfo(
        address user,
        uint256 positionID
    )
        external
        view
        returns (
            uint256 power,
            uint256 amount,
            uint256 stakeTime,
            uint256 stakeDuration
        );
}
