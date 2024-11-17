// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol';

contract UXPaymaster is BasePaymaster, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;
    IERC20 public weth;
    IQuoterV2 public quoterV2;
    uint24 public defaultPoolFee;
    uint256 private constant COST_OF_POST = 35000;
    uint256 private constant PRICE_DENOMINATOR = 1e6;
    uint256 public defaultTokenPricePerEth;

    event TokenUpdated(address newToken);
    event PoolFeeUpdated(uint24 newPoolFee);
    event WethUpdated(address newToken);
    event QuoterV2Updated(address newQuoterV2);
    event TokenPricePerEthUpdate(uint256 newTokenPricePerEth);

    constructor(IEntryPoint _entryPoint, IERC20 _token, IERC20 _weth, IQuoterV2 _quoterV2, uint256 _defaultTokenPricePerEth) BasePaymaster(_entryPoint) {
        token = _token;
        weth = _weth;
        quoterV2 = _quoterV2;
        defaultPoolFee = 500;
        defaultTokenPricePerEth = _defaultTokenPricePerEth;
    }

    function setToken(IERC20 _newToken) external onlyOwner {
        token = _newToken;
        emit TokenUpdated(address(_newToken));
    }

    function setWeth(IERC20 _newToken) external onlyOwner {
        weth = _newToken;
        emit WethUpdated(address(_newToken));
    }

    function setQuoterV2(IQuoterV2 _newQuoterV2) external onlyOwner {
        quoterV2 = _newQuoterV2;
        emit QuoterV2Updated(address(_newQuoterV2));
    }

    function setPoolFee(uint24 _newPoolFee) external onlyOwner {
        defaultPoolFee = _newPoolFee;
        emit PoolFeeUpdated(_newPoolFee);
    }

    function withdrawToken(address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    function parsePaymasterAndData(bytes calldata paymasterAndData) internal pure returns (uint256 sendData) {
        if (paymasterAndData.length == 20) {
            return 0;
        }
        require(paymasterAndData.length == 52, "UxPaymaster: invalid paymasterAndData");
        return abi.decode(paymasterAndData[20:], (uint256));
    }

    function isApproveCallData(bytes calldata paymasterAndData) internal pure returns (bool isApprove) {
        uint256 sendData = parsePaymasterAndData(paymasterAndData);
        isApprove = sendData == 123;
        return isApprove;
    }

    function getTokenValueOfEth(uint256 ethAmount, uint256 tokenPrice) public pure returns (uint256) {
        return ethAmount * tokenPrice / PRICE_DENOMINATOR;
    }

    function getWethToTokenPrice(uint256 wethAmount) internal returns (uint256) {
        address wethAddress = address(weth);
        address tokenAddress = address(token);
        IQuoterV2.QuoteExactInputSingleParams memory quoterParams;
        quoterParams.tokenIn = wethAddress;
        quoterParams.tokenOut = tokenAddress;
        quoterParams.amountIn = wethAmount;
        quoterParams.fee = defaultPoolFee;
        quoterParams.sqrtPriceLimitX96 = 0;
        (uint256 amountOut, , , ) = quoterV2.quoteExactInputSingle(quoterParams);
        return amountOut;
    }

    function setNewTokenPricePerEth() internal {
        uint256 amountOut = getWethToTokenPrice(10**12);
        require(amountOut > 0, "amountOut is zero");
        defaultTokenPricePerEth = (amountOut * PRICE_DENOMINATOR) / (10**12);
        emit TokenPricePerEthUpdate(defaultTokenPricePerEth);
    }

    function updateTokenPricePerEth() external onlyOwner {
        setNewTokenPricePerEth();
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost) internal view override returns (bytes memory context, uint256 validationData) {
        (userOpHash);
        require(userOp.verificationGasLimit >= COST_OF_POST, "UxPaymaster: gas too low for postOp");

        uint256 tokenPrice = defaultTokenPricePerEth;
        uint256 tokenAmount = getTokenValueOfEth(maxCost, tokenPrice);
        require(token.balanceOf(userOp.sender) >= tokenAmount, "UxPaymaster: insufficient token balance");

        bool isApprove = isApproveCallData(userOp.paymasterAndData);
        if (!isApprove) {
            require(token.allowance(userOp.sender, address(this)) >= tokenAmount, "UxPaymaster: insufficient token allowance");
        }
        return (abi.encode(userOp.sender, tokenAmount), 0);
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override nonReentrant {
        (address sender, uint256 preChargeTokenAmount) = abi.decode(context, (address, uint256));
        setNewTokenPricePerEth();
        uint256 actualTokenAmount = getTokenValueOfEth(actualGasCost, defaultTokenPricePerEth);
        if (mode != PostOpMode.postOpReverted) {
            uint256 totalCost = Math.min(preChargeTokenAmount, actualTokenAmount + getTokenValueOfEth(COST_OF_POST, defaultTokenPricePerEth));
            token.safeTransferFrom(sender, address(this), totalCost);
        } else {
            uint256 postOpCost = getTokenValueOfEth(COST_OF_POST, defaultTokenPricePerEth);
            token.safeTransferFrom(sender, address(this), postOpCost);
        }
    }
}
