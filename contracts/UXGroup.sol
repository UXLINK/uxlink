// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./ERC6551Registry.sol";
import "./UXGroupAccount.sol";
import "./interfaces/IERC6551Account.sol";


contract UXGroup is ERC721URIStorage {

    uint256 private _tokenId;
    ERC6551Registry private _registry;
    UXGroupAccount private _accountContract;
    address public accountAddress;

    // Flag to control whether transfers are allowed or not
    bool public transfersEnabled;

    /// @notice tokenId => groupId
    mapping(uint256 => int) public groupIds;

    /// @notice tokenId => accountAddress
    mapping(uint256 => address) public groupWallets;

    /// @notice ownerAddress => tokenIds
    mapping(address => uint256[]) public tokenIds;

    /// @notice Addresses of super operators
    mapping(address => bool) private  superOperators;

     /// @notice Requires sender to be contract super operator
    modifier onlyAdmin() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    event minted(uint256 tokenId, int groupId, address groupAccount);

    constructor() ERC721("UXGroup", "UXG") {
        _registry = new ERC6551Registry();
        superOperators[msg.sender] = true;
        transfersEnabled = true;
    }

    /// mint UXGroup
    function mint(address to, int groupId, string memory tokenURI) external payable {
        _tokenId += 1;
        _accountContract = new UXGroupAccount();
        uint256 salt = generateRandomSalt();
        bytes memory emptyBytes = "";
        accountAddress = _registry.createAccount(address(_accountContract), block.chainid, address(this), _tokenId, salt, emptyBytes);
        address expectedAddress = _registry.account(address(_accountContract), block.chainid, address(this), _tokenId, salt);
        require(accountAddress == expectedAddress, "wrong addresses");
        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, tokenURI);
        groupIds[_tokenId] = groupId;
        groupWallets[_tokenId] = accountAddress;
        
        if(msg.value > 0){
            loadBalance(payable(accountAddress), msg.value);
        }
        emit minted(_tokenId,groupId,accountAddress);
    }

    function getGroupIdByTokenId(uint256 tokenId) public view  returns(int) {
        return groupIds[tokenId];
    }

    function getAccountByTokenId(uint256 tokenId) public view  returns(address) {
        return groupWallets[tokenId];
    }

    function totalSupply() external view returns (uint256){
        return _tokenId;
    }

    function tokenIdsOfOwner(address owner) public view returns (uint256[] memory) {
        require(owner != address(0), "owner is zero");
        uint256 j = 0;
        uint256 k = balanceOf(owner);
        uint256[] memory res = new uint256[](k);
        for (uint256 i = 1; i < _tokenId+1 && j < k; i++) {
            if (_exists(i) && ownerOf(i) == owner) {
                res[j] = i;
                j++;
            }
        }
        return res;
    }

    // Function to enable or disable transfers
    function setTransfersEnabled(bool _transfersEnabled) external onlyAdmin {
        transfersEnabled = _transfersEnabled;
    }

    // Override the transfer function to check transfersEnabled
    function transfer(address to, uint256 tokenId) external {
        require(transfersEnabled, "Transfers are currently disabled");
        super.transferFrom(msg.sender, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721,IERC721) {
        require(transfersEnabled, "Transfers are currently disabled");
        super.transferFrom(from, to, tokenId);
    }

    // Override the safeTransferFrom function to check transfersEnabled
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override(ERC721,IERC721) {
        require(transfersEnabled, "Transfers are currently disabled");
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * Allow withdraw of ETH tokens from the contract
     */
    function withdrawETH(address recipient, uint256 amount) public onlyAdmin {
        require(amount > 0, "amount is zero");
        uint256 balance = address(this).balance;
        require(balance >= amount, "balance must be greater than amount");
        payable(recipient).transfer(amount);
    }

     /// @notice Allows super operator to update super operator
    function authorizeOperator(address _operator) external onlyAdmin {
        superOperators[_operator] = true;
    }

    /// @notice Allows super operator to update super operator
    function revokeOperator(address _operator) external onlyAdmin {
        superOperators[_operator] = false;
    }
    
    /// Internal Functions

    receive() external payable {}

    function nextId() internal view returns(uint256) {
        return _tokenId;
    }

    function generateRandomSalt() internal view returns (uint256) {
        bytes32 hash = keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce()));
        return uint256(hash);
    }

    function nonce() internal pure returns (uint256) {
        return 1;
    }

    function loadBalance(address payable to, uint amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Failed to send Ether");
    }
}