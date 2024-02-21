// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";

import "./interfaces/INameService.sol";
import "./core/Erc721Upgradeable.sol";
import {StringUtils} from "../libraries/StringUtils.sol";


contract NameService is INameService, Erc721Upgradeable {
    using StringUtils for *;

    uint256 _minNameLength;
    uint256 _maxNameLength;
    mapping(uint256 => uint256) _nameLengthControl;
    string public suffix;

    mapping(uint256 => string) _nameIndex;
    mapping(address => uint256) _ownedResolvedName;
    mapping(uint256 => address) _tokenIdOfResolvedName;

    function setSuffix(string calldata suffix_) external onlyMinter {
        suffix = suffix_;
    }

    function setNameLengthControl(uint256 minNameLength_, uint256 maxNameLength_, uint256 _nameLength, uint256 _maxCount) external onlyMinter {
        _minNameLength = minNameLength_;
        _maxNameLength = maxNameLength_;
        _nameLengthControl[_nameLength] = _maxCount;
    }

    function _register(address owner, string calldata name, bool resolve) internal returns (uint256 tokenId) {
        string memory fullName = string.concat(name, suffix);
        bytes32 label = keccak256(bytes(fullName));
        tokenId = uint256(label);

        require(!_exists(tokenId), "NameService: already added");

        if (resolve){
            _ownedResolvedName[owner] = tokenId;
            _tokenIdOfResolvedName[tokenId] = owner;
        }

        _nameIndex[tokenId] = fullName;

        _mint(owner, tokenId);

        emit NameRegistered(
            fullName,
            keccak256(bytes(fullName)),
            owner
        );
    }

    function register(address owner, string calldata name, bool resolve) external override returns (uint256 tokenId) {
        uint256 len = name.strlen();
        require((len > _minNameLength && len < _maxNameLength), "NameService: invalid length of name");
        require(msg.sender == owner || _minters[msg.sender], "NameService: permission denied");
        return _register(owner, name, resolve);
    }

    function multiRegister(address[] memory to, string[] calldata name) external override onlyMinter {
        require(to.length == name.length, "address.len must equal name.len ");
        for (uint256 i = 0; i < to.length; i++) {
            _register(to[i], name[i],false);
        }
    }

    /**
     * To set a record for resolving the name, linking the name to an address.
     * @param addr_ : The owner of the name. If the address is zero address, then the link is canceled.
     * @param name : The name.
     */
    function setNameForAddr(address addr_, string calldata name) external override {
        require(addr_ == msg.sender || addr_ == address(0) || _minters[msg.sender], "NameService:can not set for others");
        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);
        require(ownerOf(tokenId) == msg.sender || _minters[msg.sender], "NameService:not the owner");

        address existAddr = _tokenIdOfResolvedName[tokenId];
        if (existAddr != address(0)) {
            _ownedResolvedName[existAddr] = 0;
            _tokenIdOfResolvedName[tokenId] = address(0);
        }

        _ownedResolvedName[addr_] = tokenId;
        _tokenIdOfResolvedName[tokenId] = addr_;
    }

    function addr(string calldata name) virtual override external view returns (address){
        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);

        return _tokenIdOfResolvedName[tokenId];
    }

    function nameOf(address addr_) external view returns (string memory){
        if (addr_ == address(0)) {
            return "";
        }
        uint256 tokenId = _ownedResolvedName[addr_];
        return _nameIndex[tokenId];
    }

    function nameOfTokenId(uint256 tokenId) external view returns (string memory){
        return _nameIndex[tokenId];
    }

    function ownerOfName(string calldata name) external view returns (address){
        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);
        return ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(Erc721Upgradeable) returns (bool) {
        return interfaceId == type(INameService).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721EnumerableUpgradeable) virtual {
        require(from == address(0) || _tokenIdOfResolvedName[firstTokenId] == address(0), "NameService:can not transfer when resolved");
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
