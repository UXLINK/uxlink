// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../libs/Manager.sol";

interface IFiat24NFT is IERC721 {
    function mintByWallet(address _recipient, uint256 _tokenId) external;
    function exists(uint256 _tokenId) external view returns (bool);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

interface IFiat24CryptoDeposit {
    function depositByWallet(address _client, address _outputToken, uint256 _usdcAmount) external;
}

contract UXLINKDebitCard is Manager, ReentrancyGuard, Pausable {
    using Address for address payable;

    // Fiat24 contract addresses
    IFiat24NFT public constant FIAT24_NFT = IFiat24NFT(0x133CAEecA096cA54889db71956c7f75862Ead7A0);
    IFiat24CryptoDeposit public constant FIAT24_CRYPTO_DEPOSIT = IFiat24CryptoDeposit(0x4582f67698843Dfb6A9F195C0dDee05B0A8C973F);
    IERC20 public constant F24 = IERC20(0x22043fDdF353308B4F2e7dA2e5284E4D087449e1);
    
    // Fiat24 token addresses
    address public constant USD24 = 0xbE00f3db78688d9704BCb4e0a827aea3a9Cc0D62;
    address public constant CHF24 = 0xd41F1f0cf89fD239ca4c1F8E8ADA46345c86b0a4;
    address public constant EUR24 = 0x2c5d06f591D0d8cd43Ac232c2B654475a142c7DA;
    address public constant CNH24 = 0x7288Ac74d211735374A23707D1518DCbbc0144fd;

    // Wallet provider configuration
    struct ProviderConfig {
        uint256 f24Required; // Required F24 amount for minting
        address feeToken; // ERC20 token for fees
        uint256 mintFee; // Fixed amount of tokens for minting fee
    }

    ProviderConfig public providerConfig;

    // Events
    event NFTMinted(uint256 indexed tokenId, address indexed recipient, uint256 fee);
    event DepositForClient(address indexed client, address indexed outputToken, uint256 amount);
    event NFTTransferred(address indexed nftContract, uint256 indexed tokenId, address from, address to);
    event TokenWithdrawn(address indexed token, address indexed recipient, uint256 amount);
    event ProviderConfigUpdated(
        uint256 f24Required,
        address indexed feeToken,
        uint256 mintFee
    );

    constructor(
        uint256 _f24Required,
        address _feeToken,
        uint256 _mintFee
    ) {
        
        providerConfig = ProviderConfig({
            f24Required: _f24Required,
            feeToken: _feeToken,
            mintFee: _mintFee
        });
    }

    /**
     * @dev Mint a Fiat24 NFT for user with fee
     * @param _tokenId The token ID to mint (must be 6 digits starting with 1-7)
     */
    function mintNFT(uint256 _tokenId) external nonReentrant whenNotPaused {
        require(!FIAT24_NFT.exists(_tokenId), "Token ID already exists"); 
        
        // Collect fee if configured
        if (providerConfig.mintFee > 0 && providerConfig.feeToken != address(0)) {
            require(IERC20(providerConfig.feeToken).balanceOf(msg.sender) >= providerConfig.mintFee, "Insufficient fee token balance");
            require(IERC20(providerConfig.feeToken).allowance(msg.sender, address(this)) >= providerConfig.mintFee, "Insufficient fee token allowance");
            TransferHelper.safeTransferFrom(providerConfig.feeToken, msg.sender, address(this), providerConfig.mintFee);
        }

        // Approve the required F24 amount just before minting
        if (providerConfig.f24Required > 0) {
            // Make sure we have enough F24 tokens
            require(F24.balanceOf(address(this)) >= providerConfig.f24Required, "Insufficient F24 balance");
            
            // Approve only the exact needed amount
            F24.approve(address(FIAT24_NFT), providerConfig.f24Required);
        }

        // Mint NFT through Fiat24 contract
        FIAT24_NFT.mintByWallet(msg.sender, _tokenId);

        emit NFTMinted(_tokenId, msg.sender, providerConfig.mintFee);
    }

    /**
     * @dev Deposit USDC on behalf of client (Wallet Provider method)
     * @param _client The client address
     * @param _outputToken The Fiat24 token to receive
     * @param _usdcAmount The USDC amount
     */
    function depositForClient(
        address _client,
        address _outputToken,
        uint256 _usdcAmount
    ) external onlyManager nonReentrant {
        require(_isValidOutputToken(_outputToken), "Invalid output token");
        require(_usdcAmount > 0, "Zero amount not allowed");

        FIAT24_CRYPTO_DEPOSIT.depositByWallet(_client, _outputToken, _usdcAmount);

        emit DepositForClient(_client, _outputToken, _usdcAmount);
    }

    /**
     * @dev Update provider configuration (only manager)
     */
    function updateProviderConfig(
        uint256 _f24Required,
        address _feeToken,
        uint256 _mintFee
    ) external onlyManager {

        providerConfig.f24Required = _f24Required;
        providerConfig.feeToken = _feeToken;
        providerConfig.mintFee = _mintFee;

        emit ProviderConfigUpdated(
            _f24Required,
            _feeToken,
            _mintFee
        );
    }

    /**
     * @dev Withdraw ERC20 tokens (only manager)
     * @param _token The token address
     * @param _amount The amount to withdraw
     * @param _recipient The recipient address
     */
    function withdrawToken(
        address _token,
        uint256 _amount,
        address _recipient
    ) external onlyManager nonReentrant {
        require(_amount > 0, "Zero amount not allowed");
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Insufficient balance");
        
        TransferHelper.safeTransfer(_token, _recipient, _amount);

        emit TokenWithdrawn(_token, _recipient, _amount);
    }

    /**
     * @dev Transfer contract's own NFT to another address
     * @param _tokenId The NFT token ID to transfer
     * @param _to The new owner address
     */
    function transferContractNFT(
        address _nftContract,
        uint256 _tokenId,
        address _to
    ) external onlyManager nonReentrant {
        require(_to != address(0), "Invalid recipient address");
        require(address(this) != _to, "Cannot transfer to self");
        require(_nftContract != address(0), "Invalid NFT contract address");
        
        IERC721 nftContract = IERC721(_nftContract);
        require(nftContract.ownerOf(_tokenId) == address(this), "Not the owner");

        nftContract.safeTransferFrom(address(this), _to, _tokenId);

        emit NFTTransferred(_nftContract, _tokenId, address(this), _to);
    }

    function getProviderConfig() external view returns (
        uint256 f24Required,
        address feeToken,
        uint256 mintFee
    ) {
        return (
            providerConfig.f24Required,
            providerConfig.feeToken,
            providerConfig.mintFee
        );
    }

    function _isValidOutputToken(address _token) internal pure returns (bool) {
        return _token == USD24 || _token == CHF24 || _token == EUR24 || _token == CNH24;
    }

    function pause() public onlyManager whenNotPaused {
        _pause();
    }

    function unpause() public onlyManager whenPaused {
        _unpause();
    }
}
