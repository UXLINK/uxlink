// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UXSign} from "../libs/UXSign.sol";

interface IUXNFT {
    function mint(address to, uint256 quantity) external;
    function balanceOf(address owner) external view returns (uint256 balance);
    function totalSupply() external view returns (uint256 balance);
}

// @dev https://uxlink.io
contract UXAirdropHubs is UXSign {

    /// @notice UXUY ERC20 token
    IERC20 private UXUY;
    address public UXUYTOKEN = 0xE2035f04040A135c4dA2f96AcA742143c57c79F9;

    /// NFT PRICE BASED ON UXUY 
    mapping(address => uint256) public nftPriceOnUXUY;
    mapping(address => uint256) public nftPriceOnETH;
    // 所有的地址
    address[] private nftAddresses;

    // 
    event MintSuccess(
        address sender,
        address nft,
        string  withToken,
        uint256 price,
        uint256 amount
    );

     event ClaimedUXUYSuccess(
        address wallet,
        uint256 amount,
        string  transId
    );

    constructor() {
       setManager(msg.sender,true);
       UXUY = IERC20(UXUYTOKEN);
    }

    function balanceOf(address nft, address owner)  external view returns(uint256) {
        return IUXNFT(nft).balanceOf(owner);
    }

    function totalSupply(address nft)  external view returns(uint256) {
        return IUXNFT(nft).totalSupply();
    }

    function sumTotalSupply()  external view returns(uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < nftAddresses.length; i++) {
            sum = sum + IUXNFT(nftAddresses[i]).totalSupply();
        }
        return sum;
    }

    function setUXUYToken(address _uxuytoken) external onlyManager {
        UXUYTOKEN = _uxuytoken;
        UXUY = IERC20(UXUYTOKEN);
    }

    function setPriceOnUXUY(address nft, uint256 price) external onlyManager {
        nftPriceOnUXUY[nft] = price;
        nftAddresses.push(nft);
    }

    function getPriceOnUXUY(address nft) external view returns(uint256) {
        return nftPriceOnUXUY[nft];
    }

    function setPriceOnETH(address nft, uint256 price) external onlyManager {
        nftPriceOnETH[nft] = price;
        nftAddresses.push(nft);
    }

    function getPriceOnETH(address nft)  external view returns(uint256) {
        return nftPriceOnETH[nft];
    }

    /// @dev mint NFT with UXUYTOKEN 
    function mintWithUXUY(address nft, uint256 amount, bytes memory signature, string memory transId) external {
        require(nftPriceOnUXUY[nft] > 0, "The price of the NFT you want to mint has not been set.");
        require(existsTransId(transId) == false, "Exists transId");
        require(verifySignature(transId, "MINTNFT", amount, msg.sender, signature), "Signature is invalid");

        uint256 price = amount * nftPriceOnUXUY[nft];
        if(price > 0) {
            // msg.sender must approve this contract
            uint256 balance = IERC20(UXUYTOKEN).balanceOf(msg.sender);
            require(balance >= price, "UXUYToken balance is not enough!");
            // Transfer the specified amount of UXUY to this contract.
            TransferHelper.safeTransferFrom(UXUYTOKEN, msg.sender, address(this), price);
        }
        setTransId(transId);
        IUXNFT UXNFT = IUXNFT(nft);
        UXNFT.mint(msg.sender, amount);
        emit MintSuccess(msg.sender,nft,"UXUY",price,amount);
    }

    /// @dev mint NFT with ETH 
    function mintWithETH(address nft, uint256 amount) public payable {
        require(nftPriceOnETH[nft] > 0, "The price of the NFT you want to mint has not been set.");
        uint256 price = amount * nftPriceOnETH[nft];

        require(msg.value >= price, "Not enough ETH!");

        IUXNFT UXNFT = IUXNFT(nft);
        UXNFT.mint(msg.sender, amount);
        emit MintSuccess(msg.sender,nft,"ETH",msg.value,amount);
    }

    /// @dev mint NFT with whitelist 
    function mintWithWL(address nft, uint256 amount, bytes memory signature, string memory transId) external {
        require(existsTransId(transId) == false, "Exists transId");
        require(verifySignature(transId, "MINTNFTWITHWL", amount, msg.sender, signature), "Signature is invalid");

        setTransId(transId);
        IUXNFT UXNFT = IUXNFT(nft);
        UXNFT.mint(msg.sender, amount);
        emit MintSuccess(msg.sender,nft,"WL",0,amount);
    }

    function claimUXUY(
        uint256 uxuyAmount,
        bytes memory signature,
        string memory transId
    ) external {
        require(uxuyAmount > 0, " UxuyToken is zero");
        require(existsTransId(transId) == false, "Exists transId");
        require(verifySignature(transId, "AIRDROPCLAIMUXUY", uxuyAmount, msg.sender, signature), "Signature is invalid");
        require(UXUY.balanceOf(address(this)) >= uxuyAmount,"UXUY Balance is insufficient!");
        // record
        setTransId(transId);
        // send UXUY to user
        TransferHelper.safeTransfer(UXUYTOKEN, msg.sender, uxuyAmount);
        emit ClaimedUXUYSuccess(msg.sender, uxuyAmount, transId);
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