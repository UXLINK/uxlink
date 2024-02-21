// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract UXGroupMiningSwap is ReentrancyGuard{
    using ECDSA for bytes32;

    /// change rate : 1 UXUY * 60 / 10000 = 60 / 10000 USDT
    uint256 public swapRate = 60;

    /// @notice UXUY ERC20 token
    IERC20 private UXUY;
    /// @notice USDT ERC20 token
    IERC20 private USDT;

    uint256 public USDT_Decimals = 1e6;
    uint256 public UXUY_Decimals = 1e18;

    address public UXUYTOKEN = 0xE2035f04040A135c4dA2f96AcA742143c57c79F9;
    address public USDTTOKEN = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    bool public swapStatus = true;
    address private signer;

    /// _exists transId
    mapping(uint256 => bool) private transIds;

    /// @notice Addresses of super operators
    mapping(address => bool) public superOperators;

    /// @notice Requires sender to be contract super operator
    modifier isSuperOperator() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    event ClaimedSuccess(
        address  wallet,
        uint256 amount,
        string  transId
    );
    event ClaimedFailed(
        address  wallet,
        uint256 amount,
        string  transId
    );

    /// constructor 
    constructor() {
        superOperators[msg.sender] = true;
        UXUY = IERC20(UXUYTOKEN);
        USDT = IERC20(USDTTOKEN);
    }

    /// @dev The calling address must approve this contract to spend at least `uxuyAmount` worth of its UXUYToken for this function to succeed.
    function swap(
        uint256 uxuyAmount,
        bytes memory signature,
        address toAddr,
        string memory transId
    ) external nonReentrant {
        require(swapStatus, "swap status is false");
        require(uxuyAmount > 0, " UxuyToken is zero");
        require(existsTransId(transId) == false, "Exists transId");
        require(verifySignature(transId, uxuyAmount, msg.sender, signature), "Signature is invalid");
        // record
        setTransId(transId);

        // 
        uint256 transUSDTAmount = (uxuyAmount * swapRate) / UXUY_Decimals * USDT_Decimals / 10000 ;
        require(UXUY.balanceOf(msg.sender) >= uxuyAmount,"Your UXUY Balance is insufficient!");
        require(USDT.balanceOf(address(this)) >= transUSDTAmount, "USDT Balance is insufficient!");

        // recieve UXUY from sender
        TransferHelper.safeTransferFrom(UXUYTOKEN, msg.sender, address(this), uxuyAmount);
        // send USDT to user
        TransferHelper.safeTransfer(USDTTOKEN, toAddr, transUSDTAmount);

        emit ClaimedSuccess(msg.sender, uxuyAmount, transId);
    }

    function setTransId(string memory transId) internal {
        bytes32 label = keccak256(bytes(transId));
        uint256 id = uint256(label);
        transIds[id] = true;
    }

    function existsTransId(string memory transId) internal view returns (bool){
        bytes32 label = keccak256(bytes(transId));
        uint256 id = uint256(label);
        if(transIds[id]){
            return true;
        }else{
            return false;
        }
    }

    function toMessageHash(string memory transId,uint256 amount, address to) public pure returns (bytes32) {
       return keccak256(abi.encodePacked(transId, amount, to));
    }

    function verifySignature(string memory transId, uint256 amount, address to, bytes memory signature) public view returns (bool){
        bytes32 hash = toMessageHash(transId, amount, to);
        return (signer == hash.toEthSignedMessageHash().recover(signature));
    }

    receive() external payable {}

    function getSigner() public view isSuperOperator returns (address)  {
        return signer;
    }

    function setSigner(address _addr) external isSuperOperator {
        signer = _addr;
    }

    function setSwapTokens(address _uxuytoken, address _usdttoken) external isSuperOperator {
        UXUYTOKEN = _uxuytoken;
        USDTTOKEN = _usdttoken;
        UXUY = IERC20(UXUYTOKEN);
        USDT = IERC20(USDTTOKEN);
    }

    function setSwapStatus(bool _flag) external isSuperOperator {
        swapStatus = _flag;
    }

    // = _rate / 10000
    function setSwapRate(uint256 _rate) external isSuperOperator {
        swapRate = _rate;
    }

    function withdrawStuckToken(address _token, address _to) external isSuperOperator {
        require(_token != address(0), "_token address cannot be 0");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        TransferHelper.safeTransfer(_token, _to, _contractBalance);
    }

    function withdrawStuckEth(address toAddr) external isSuperOperator {
        (bool success, ) = toAddr.call{
            value: address(this).balance
        } ("");
        require(success);
    }

    /// @notice Allows super operator to update super operator
    function authorizeOperator(address _operator) external isSuperOperator {
        superOperators[_operator] = true;
    }

    /// @notice Allows super operator to update super operator
    function revokeOperator(address _operator) external isSuperOperator {
        superOperators[_operator] = false;
    }

}