// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "./libs/IUXSBT.sol";

contract UXOdysseySBT {

    IUXSBT public UXSBT;
    address public UXUYNameServiceV2 = 0x6Ef77Af3bEe7A189318317861C0a23B425824a48;
    address public UXUYTOKEN = 0xebd792134a53A4B304A8f6A0A9319B99fDC3fd35;
    uint256 public price = 80 * 1 ether;

    /// @notice Addresses of super operators
    mapping(address => bool) public superOperators;

    /// @notice Requires sender to be contract super operator
    modifier isSuperOperator() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    // 
    event MintSuccess(
        address sender,
        string  name,
        uint256 price,
        uint tokenId
    );

    /// constructor 
    constructor() {
        superOperators[msg.sender] = true;
        UXSBT =  IUXSBT(UXUYNameServiceV2);
    }

    /// @dev pay UXUYTOKEN to mint UXSBT
    function mint(string calldata name) external returns (uint tokenId) {
        // msg.sender must approve this contract
        uint256 balance = IERC20(UXUYTOKEN).balanceOf(msg.sender);
        require(balance >= price, "Token balance is not enough!");

         // Transfer the specified amount of UXUY to this contract.
        TransferHelper.safeTransferFrom(UXUYTOKEN, msg.sender, address(this), price);

        tokenId = UXSBT.register(msg.sender, name, false);
        emit MintSuccess(msg.sender,name,price,tokenId);
    }

    function setPrice(uint256 _price) external isSuperOperator {
        price = _price;
    }

    function setUXUYTokenAndUXSBT(address _uxuytoken, address _sbt) external isSuperOperator {
        UXUYTOKEN = _uxuytoken;
        UXUYNameServiceV2 = _sbt;
        UXSBT =  IUXSBT(UXUYNameServiceV2);
    }

    receive() external payable {}

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