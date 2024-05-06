// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {Manager} from "../libs/Manager.sol";

// @dev https://uxlink.io
abstract contract UXNFTBASE is ERC721A, Manager,Pausable {
    /// @notice Addresses of black users
    mapping(address => bool) private _blacklist;
    mapping(address => bool) public _whitelist;
    bool public isUsingWhitelist;
    address public constant BLACK_HOLE = address(0);

    string private _uriBase = "";

    constructor(string memory name, string memory symbol) ERC721A(name, symbol) {
        setManager(msg.sender,true);
    }

    function mint(address to, uint256 quantity) public onlyManager {
        _safeMint(to, quantity);
    }

    function setBaseUriAndExtension(string memory base) public onlyManager {
        _uriBase = base; // https://base.url?id=
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert URIQueryForNonexistentToken();
        }
        return string(abi.encodePacked(_uriBase, _toString(tokenId)));
    }

    function burn(uint256 tokenId) public whenNotPaused {
        _burn(tokenId, true);
    }

    function pause() public onlyManager whenNotPaused {
        _pause();
    }

    function unpause() public onlyManager whenPaused {
        _unpause();
    }

    function getBlackListStatus(address _maker) external view returns (bool) {
        return _blacklist[_maker];
    }

    function _beforeTokenTransfers(
        address from, 
        address to, 
        uint256 firstTokenId, 
        uint256 batchSize 
    ) internal virtual override(ERC721A) {
        super._beforeTokenTransfers(from, to, firstTokenId, batchSize);
        require(!_blacklist[from], "Sending address is blacklisted.");
        require(!_blacklist[to], "Receiving address is blacklisted");
        if(isUsingWhitelist){
            require(_whitelist[from] || _whitelist[to], "Sending Or Receiving address is not on the whitelist");
        }
    }

    function addToBlacklist(address _user) public onlyManager {
        require(!_blacklist[_user], "User is already on the blacklist.");
        _blacklist[_user] = true;
    }

    function removeFromBlacklist(address _user) public onlyManager {
        require(_blacklist[_user], "User is not on the blacklist.");
        delete _blacklist[_user];
    }

    function addToWhitelist(address _address) public onlyManager {
        require(!_whitelist[_address], "User is already on the whitelist.");
        _whitelist[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyManager {
         require(_whitelist[_address], "User is not on the whitelist.");
        _whitelist[_address] = false;
    }

    function getWhiteListStatus(address _maker) external view returns (bool) {
        return _whitelist[_maker];
    }

    function setUsingWhitelistStatus(bool _status) external onlyManager {
         isUsingWhitelist = _status;
    }

    receive() external payable {}

    function withdrawStuckToken(address _token, address _to) external onlyManager {
        require(_token != address(0), "_token address cannot be 0");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        TransferHelper.safeTransfer(_token, _to, _contractBalance);
    }

    function withdrawStuckEth(address toAddr) external onlyManager {
        (bool success, ) = toAddr.call{
            value: address(this).balance
        } ("");
        require(success);
    }

}