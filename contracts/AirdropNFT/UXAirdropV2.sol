// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UXSign} from "../libs/UXSign.sol";

// @dev https://uxlink.io
contract UXAirdropV2 is UXSign {
    // set the withdrawal fee to 10000/1000000 = 1%.
    uint256 public withdrawalFee = 0;
    // set vault address
    address public revFeeWallet;

    event ClaimedERC20Success(
        address tokenOwner,
        address toWallet,
        address uxerc20token,
        uint256 amount,
        string transId
    );

    constructor() {
        setManager(msg.sender, true);
        revFeeWallet = msg.sender;
    }

    function claimERC20(
        uint256 tokenAmount,
        address uxerc20token,
        bytes memory signature,
        string memory transId
    ) external {
        require(tokenAmount > 0, " tokenAmount is zero");
        require(existsTransId(transId) == false, "Exists transId");

        bytes32 claimERC20SaltCode = keccak256(
            abi.encodePacked(saltCode, uxerc20token)
        );

        require(
            verifySignature(
                transId,
                bytes32ToHexString(claimERC20SaltCode),
                tokenAmount,
                msg.sender,
                signature
            ),
            "Signature is invalid"
        );
        require(
            IERC20(uxerc20token).balanceOf(address(this)) >= tokenAmount,
            "TOKEN Balance is insufficient!"
        );
        setTransId(transId);
        // send token to user
        uint256 fee = calculateWithdrawalFee(tokenAmount);
        uint256 amountAfterFee = tokenAmount - fee;
        if (fee > 0) {
            TransferHelper.safeTransfer(uxerc20token, revFeeWallet, fee);
        }
        TransferHelper.safeTransfer(uxerc20token, msg.sender, amountAfterFee);
        emit ClaimedERC20Success(
            msg.sender,
            msg.sender,
            uxerc20token,
            tokenAmount,
            transId
        );
    }

    function claimERC20ToAddress(
        address toAddress,
        uint256 tokenAmount,
        address uxerc20token,
        bytes memory signature,
        string memory transId
    ) external {
        require(tokenAmount > 0, " tokenAmount is zero");
        require(existsTransId(transId) == false, "Exists transId");

        bytes32 claimERC20SaltCode = keccak256(
            abi.encodePacked(saltCode, uxerc20token)
        );
        require(
            verifySignature(
                transId,
                bytes32ToHexString(claimERC20SaltCode),
                tokenAmount,
                msg.sender,
                signature
            ),
            "Signature is invalid"
        );
        require(
            IERC20(uxerc20token).balanceOf(address(this)) >= tokenAmount,
            "TOKEN Balance is insufficient!"
        );
        setTransId(transId);
        // send token to user
        uint256 fee = calculateWithdrawalFee(tokenAmount);
        uint256 amountAfterFee = tokenAmount - fee;
        if (fee > 0) {
            TransferHelper.safeTransfer(uxerc20token, revFeeWallet, fee);
        }
        TransferHelper.safeTransfer(uxerc20token, toAddress, amountAfterFee);
        emit ClaimedERC20Success(
            msg.sender,
            toAddress,
            uxerc20token,
            tokenAmount,
            transId
        );
    }

    function setWithdrawalFee(uint256 _fee) external onlyManager {
        require(
            _fee <= 1000000,
            "withdrawalFee must be less than or equal to 1000000"
        );
        withdrawalFee = _fee;
    }

    function setRevFeeWallet(address _to) external onlyManager {
        revFeeWallet = _to;
    }

    function calculateWithdrawalFee(
        uint256 amount
    ) internal view returns (uint256) {
        return (amount * withdrawalFee) / 1000000;
    }

    receive() external payable {}

    function withdrawStuckToken(
        address _token,
        address _to
    ) external onlyManager {
        require(_token != address(0), "_token address cannot be 0");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        TransferHelper.safeTransfer(_token, _to, _contractBalance);
    }

    function withdrawStuckEth(address toAddr) external onlyManager {
        (bool success, ) = toAddr.call{value: address(this).balance}("");
        require(success);
    }

    function bytes32ToHexString(
        bytes32 data
    ) internal view returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(66);

        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 32; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }

        return string(str);
    }
}
