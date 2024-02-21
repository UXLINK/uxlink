// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract Erc721Upgradeable is Initializable, OwnableUpgradeable, ERC165Upgradeable, ERC721EnumerableUpgradeable{

    mapping(address => bool) internal _minters;
    bool private _transferable;
    string private _baseTokenURI;
    string private _symbol;
    string internal _name;
    uint256 _supplyAmount;
    mapping(address => uint256[]) internal _ownerToIds;


    event SetMinter(address indexed addr, bool isMinter);

    modifier onlyMinter() {
        require(_minters[msg.sender], "UXUY: must be minter");
        _;
    }

    modifier onlyTransferable() {
        require(_transferable, "UXUY: must transferable");
        _;
    }

    function before_init() internal {
        __Ownable_init();
    }

    /* ============ External Functions ============ */


    function initialize(
        address minter,
        string memory name_,
        string memory symbol_,
        string memory baseURI_) public initializer {
        before_init();
        _minters[minter] = true;
        _name = name_;
        _symbol = symbol_;
        _baseTokenURI = baseURI_;
        _supplyAmount = 0;
        emit SetMinter(minter, true);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return interfaceId == type(IERC721Upgradeable).interfaceId ||
        interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
        interfaceId == type(IERC721EnumerableUpgradeable).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function minters(address account) public view returns (bool) {
        return _minters[account];
    }

    function setMinter(address addr, bool _isMinter) external onlyOwner {
        _minters[addr] = _isMinter;
        emit SetMinter(addr, _isMinter);
    }


    function transferable() public view returns (bool) {
        return _transferable;
    }


    function baseURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * PRIVILEGED MODULE FUNCTION. Sets a new baseURI for all token types.
     */
    function setURI(string memory newURI) external onlyOwner {
        _baseTokenURI = newURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return bytes(_baseTokenURI).length > 0 ? string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId))) : "";
    }

    function setTransferable(bool transferable_) external onlyOwner {
        _transferable = transferable_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function setName(string calldata newName) external virtual onlyOwner {
        _name = newName;
    }


    function setSymbol(string calldata newSymbol) external onlyOwner {
        _symbol = newSymbol;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public onlyTransferable override(IERC721Upgradeable, ERC721Upgradeable) {
        super.transferFrom(from, to, tokenId);
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public onlyTransferable override(IERC721Upgradeable, ERC721Upgradeable) {
        super.safeTransferFrom(from, to, tokenId, "");
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public onlyTransferable override(IERC721Upgradeable, ERC721Upgradeable) {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _supplyAmount;
    }
    
    function _mint(address _to, uint256 _tokenId) internal virtual override {
        super._mint(_to, _tokenId);
        _supplyAmount = _supplyAmount + 1;
        _ownerToIds[_to].push(_tokenId);
    }

    function _burn(uint256 _tokenId) internal virtual override {
        super._burn(_tokenId);
        _supplyAmount = _supplyAmount - 1;
    }

    function tokenIdsOfOwner(address owner) public view returns (uint256[] memory) {
        return _ownerToIds[owner];
    }
}
