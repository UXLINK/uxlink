// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract RelationUpgradeable is Initializable, OwnableUpgradeable, ERC165Upgradeable{

    mapping(address => bool) internal _minters;

    event SetMinter(address indexed addr, bool isMinter);

    modifier onlyMinter() {
        require(_minters[msg.sender], "SemanticSBT: must be minter");
        _;
    }

    function before_init() internal {
        __Ownable_init();
    }

    /* ============ External Functions ============ */


    function initialize(address minter) public initializer {
        before_init();
        _minters[minter] = true;
        emit SetMinter(minter, true);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function minters(address account) public view returns (bool) {
        return _minters[account];
    }

    function setMinter(address addr, bool _isMinter) external onlyOwner {
        _minters[addr] = _isMinter;
        emit SetMinter(addr, _isMinter);
    }

}