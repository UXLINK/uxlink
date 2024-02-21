// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UXGroup.sol";

contract UXGroupRegistry {

    UXGroup public _UXGroup;

    /// @notice Addresses of super operators
    mapping(address => bool) public superOperators;

    /// @notice Requires sender to be contract super operator
    modifier isSuperOperator() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    /// constructor 
    constructor() {
        superOperators[msg.sender] = true;
    }

    function batchMint(address[] memory to, int[] calldata groupId, string[] memory tokenURI) external payable {
        require(to.length == groupId.length, "address.len must equal groupId.len ");
        require(to.length == tokenURI.length, "address.len must equal tokenURI.len ");
        for (uint256 i = 0; i < to.length; i++) {
            _UXGroup.mint(to[i], groupId[i], tokenURI[i]);
        }
    }

    function setUXGroup(address payable tokenAddr)  external isSuperOperator{
       _UXGroup = UXGroup(tokenAddr);
    }

    receive() external payable {}

    /**
     * Allow withdraw of ETH tokens from the contract
     */
    function withdrawETH(address recipient, uint256 amount) public isSuperOperator {
        require(amount > 0, "amount is zero");
        uint256 balance = address(this).balance;
        require(balance >= amount, "balance must be greater than amount");
        payable(recipient).transfer(amount);
    }

}