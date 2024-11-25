// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Manager} from "../libs/Manager.sol";

abstract contract UXSign is Manager {
    using ECDSA for bytes32;
    address private signer;
    string internal saltCode = "UXLINK.io";

    /// _exists transId
    mapping(uint256 => bool) private transIds;

    function setTransId(string memory transId) internal {
        bytes32 label = keccak256(bytes(transId));
        uint256 id = uint256(label);
        transIds[id] = true;
    }

    function existsTransId(string memory transId) public view returns (bool) {
        bytes32 label = keccak256(bytes(transId));
        uint256 id = uint256(label);
        if (transIds[id]) {
            return true;
        } else {
            return false;
        }
    }

    // sign data
    function toMessageHash(
        string memory transId,
        uint256 amount,
        address to,
        string memory code
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(transId, amount, to, code));
    }

    function verifySignature(
        string memory transId,
        string memory code,
        uint256 amount,
        address to,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 hash = toMessageHash(transId, amount, to, code);
        return (signer == hash.toEthSignedMessageHash().recover(signature));
    }

    function getSigner() public view onlyManager returns (address) {
        return signer;
    }

    function setSigner(address _addr) external onlyManager {
        signer = _addr;
    }

    function setSaltCode(string memory _code) external onlyManager {
        saltCode = _code;
    }

    function getSaltCode() public view onlyManager returns (string memory) {
        return saltCode;
    }
}
