// SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import {Manager} from "./libs/Manager.sol";

interface IUXMANAGER {
    function authorizeOperator(address _operator) external;
    function setManager(address one, bool val) external;
}

contract UXContractDeployer is Manager{

    event ContractDeployed(address creatorAddress, address contractAddress);
    uint256 public fee;

    constructor() {
        setManager(msg.sender,true);
        fee = 0.00 ether;
    }

    /**
     * setManager for contract
     */
    function setContractManager(address _contractAddress, address _managerAddress) public onlyManager {
        require(_contractAddress != address(0), "Zero address");
        require(_managerAddress != address(0), "Zero address");
        IUXMANAGER(_contractAddress).setManager(_managerAddress, true);
    }

    /**
     * authorizeOperator for contract
     */
    function setContractOperator(address _contractAddress, address _managerAddress) public onlyManager {
        require(_contractAddress != address(0), "Zero address");
        require(_managerAddress != address(0), "Zero address");
        IUXMANAGER(_contractAddress).authorizeOperator(_managerAddress);
    }

    function setFee(uint256 _fee) public onlyManager {
        fee = _fee;
    }

    function withdrawFee(address payable _to) public onlyManager{
        require(_to != address(0), "Zero address");
        _to.transfer(address(this).balance);
    }
 
    /**
     * deploy contract by salt, contract bytecode.
     */
    function deployContract(bytes32 salt, bytes memory contractBytecode) public payable {
        require(msg.value == fee, "Invalid fee");
        address addr;
        assembly {
            addr := create2(0, add(contractBytecode, 0x20), mload(contractBytecode), salt)
        }
        require(addr != address(0), "Create2: Failed on deploy");
        emit ContractDeployed(msg.sender, addr);
    }

    /**
     * deploy contract by salt, contract bytecode and constructor args.
     */
    function deployContractWithConstructor(bytes32 salt, bytes memory contractBytecode, bytes memory constructorArgsEncoded) public payable {
        require(msg.value == fee, "Invalid fee");
        // deploy contracts with constructor (address):
        bytes memory payload = abi.encodePacked(contractBytecode, constructorArgsEncoded);
        address addr;
        assembly {
            addr := create2(0, add(payload, 0x20), mload(payload), salt)
        }
        require(addr != address(0), "Create2: Failed on deploy");
        emit ContractDeployed(msg.sender, addr);
    }
}