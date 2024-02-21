// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IRelationService {

    function claim(address owner_, uint price, bytes32 merkleTreeRoot_, string[] memory blockHashes) external;

    function setRelationCount(address owner, uint count) external;

    // Get user relationship chain count
    function getRelationCount(address owner) external view returns(uint count);

    // User manually sets access permissions for the relationship chain
    function setDappAuth(address dappAddress, address owner, bool valid) external;

    // Dapp obtains the user relationship chain blockhash value
    function userRelationBlocks(address owner) external returns(string[] memory blockHashes);

    // ========User relationship judgment========
    // Set the user's social relationship Merkle tree
    function setUserMerkleTreeRoot(address owner, bytes32 merkleTreeRoot) external;

    // Determine whether two users are related before, using user as the root node
    function hasRelation(address user, address pal, bytes32[] memory proof) external returns(bool hasRelation);
}