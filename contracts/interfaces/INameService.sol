// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;


interface INameService {

    event NameRegistered(
        string name,
        bytes32 indexed label,
        address indexed owner
    );

    /**
     * To register a name
     * @param owner : The owner of a name
     * @param name : The name to be registered.
     * @param reverseRecord : Whether to set a record for resolving the name.
     * @return tokenId : The tokenId.
     */
    function register(address owner, string calldata name, bool reverseRecord) external returns (uint tokenId);

    function multiRegister(address[] memory to, string[] calldata name) external;

    /**
     * To set a record for resolving the name, linking the name to an address.
     * @param owner : The owner of the name. If the address is zero address, then the link is canceled.
     * @param name : The name.
     */
    function setNameForAddr(address owner, string calldata name) external;

    /**
     * To resolve a name.
     * @param name : The name.
     * @return owner : The address.
     */
    function addr(string calldata name) external view returns (address owner);

    /**
     * Reverse mapping
     * @param owner : The address.
     * @return name : The name.
     */
    function nameOf(address owner) external view returns (string memory name);
}