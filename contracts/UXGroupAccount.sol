// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IERC6551Account.sol";
import "./libs/ERC6551AccountLib.sol";
import "./libs/Bytecode.sol";

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
}

contract UXGroupAccount is IERC165, IERC1271, IERC6551Account {
    
    uint256 public nonce;

    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == owner(), "Not token owner");
        _;
    }

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner payable returns (bytes memory result)  {

        ++nonce;

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function token()
        external
        view
        returns (
            uint256,
            address,
            uint256
        )
    {
        uint256 length = address(this).code.length;
        return
        abi.decode(
                Bytecode.codeAt(address(this), length - 0x60, length),
                (uint256, address, uint256)
            );
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
        require(chainId == block.chainid, "Wrong chainID");
        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function transferERC20(address tokenAddress, address to, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(IERC20(tokenAddress), to, amount);
    }
    
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId);
    }

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue)
    {
        bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }
}