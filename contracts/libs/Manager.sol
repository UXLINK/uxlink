// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Context.sol";

abstract contract Manager is Context {
    mapping(address => bool) private _accounts;

    modifier onlyManager() {
        require(isManager(), "only manager");
        _;
    }

    constructor() {
        _accounts[_msgSender()] = true;
    }

    function isManager(address one) public view returns (bool) {
        return _accounts[one];
    }

    function isManager() public view returns (bool) {
        return isManager(_msgSender());
    }

    function setManager(address one, bool val) public onlyManager {
        require(one != address(0), "address is zero");
        _accounts[one] = val;
    }

    function setManagerBatch(
        address[] calldata list,
        bool val
    ) public onlyManager {
        for (uint256 i = 0; i < list.length; i++) {
            setManager(list[i], val);
        }
    }
}
