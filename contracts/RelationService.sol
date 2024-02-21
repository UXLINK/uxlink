// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";

import "./interfaces/IRelationService.sol";
import "./core/RelationUpgradeable.sol";


contract RelationService is IRelationService, RelationUpgradeable {

    // The user sets whether the Dapp has access rights to its resources. Dapp can obtain permission by paying, or it can be set through the user calling interface.
    // The first address is the dapp's address, and the second is the user's address.
    mapping(address => mapping(address => bool)) _dappUserAuth;
    // The first address is the user's address, and the second is the dapp's address.
    mapping(address => mapping(address => bool)) _userDdappAuth;

    // The total number of user social relationships, the user can configure it himself
    mapping(address => uint) _relationCount;

    // The hash value of the user relationship block stored in ipfs. A block can contain up to 1,000 associated users.
    // Can only be published through the UXUY address
    mapping(address => string[]) _relationBlock;

    // The user relationship generates the hash value of the root of the Merkle tree, which is used to authenticate the user relationship and determine whether two users are related.
    mapping(address => bytes32) _userRelationMerkleTreeRoot;

    function claim(address owner_, uint relationCount_, bytes32 merkleTreeRoot_, string[] memory blockHashes_) external override{
        require(_minters[msg.sender], "RelationService: permission denied");
        _appendRelationCount(owner_, relationCount_);
        _setUserMerkleTreeRoot(owner_, merkleTreeRoot_);
        _appendRelationBlocks(owner_, blockHashes_);
    }

    function setRelationCount(address owner_, uint count) external override{
        require(_minters[msg.sender], "RelationService: permission denied");
        _setRelationCount(owner_, count);
    }

    function _setRelationCount(address owner_, uint count) internal{
        _relationCount[owner_] = count;
    }

    function _appendRelationCount(address owner_, uint count) internal{
        _relationCount[owner_] = _relationCount[owner_] + count;
    }

    // Get user relationship chain count
    function getRelationCount(address owner) external view override returns(uint count) {
        return _relationCount[owner];
    }

    // 用户手动设置关系链的访问权限
    function setDappAuth(address dappAddress_, address owner_, bool valid) external override{
        require(msg.sender == owner_ || _minters[msg.sender], "RelationService: permission denied");
        _setDappAuth(dappAddress_, owner_, valid);
    }

    function _setDappAuth(address dappAddress_, address owner_, bool valid) internal{
        _userDdappAuth[owner_][dappAddress_] = valid;
        _dappUserAuth[dappAddress_][owner_] = valid;
    }

    // Dapp obtains the user relationship chain blockhash value
    function userRelationBlocks(address owner_) external view override returns(string[] memory blockHashes){
        require(msg.sender == owner_ || _dappUserAuth[msg.sender][owner_] || _minters[msg.sender], "RelationService: permission denied");
        return _relationBlock[owner_];
    }

    function _appendRelationBlocks(address owner_, string[] memory blockHashes_) internal{
        for(uint i = 0;i < blockHashes_.length; i++){
            _relationBlock[owner_].push(blockHashes_[i]);
        }
    }

    // ========User relationship judgment========
    // Set the user's social relationship Merkle tree
    function setUserMerkleTreeRoot(address owner_, bytes32 merkleTreeRoot_) external override{
        require(_minters[msg.sender], "RelationService: permission denied");
        _setUserMerkleTreeRoot(owner_, merkleTreeRoot_);
    }

    function _setUserMerkleTreeRoot(address owner_, bytes32 merkleTreeRoot_) internal{
        _userRelationMerkleTreeRoot[owner_] = merkleTreeRoot_;
    }

    // Determine whether two users are related before, using user as the root node
    function hasRelation(address user_, address pal_, bytes32[] memory proofs_) external view override returns(bool isRelation){
        if (_userRelationMerkleTreeRoot[user_].length == 0) {
            return false;
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(pal_))));

        return MerkleProof.verify(proofs_, _userRelationMerkleTreeRoot[user_], leaf);
    }
}
