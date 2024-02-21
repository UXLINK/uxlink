// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


interface UxuyToken {
    function reward(uint256 amount, address toUser) external returns (bool);
}

contract UXSelfClaim {
    using ECDSA for bytes32;

    UxuyToken private _uxuyToken;
    address public UXUYTOKEN = 0xebd792134a53A4B304A8f6A0A9319B99fDC3fd35;
    bool public claimStatus = true;
    address private signer;

    /// _exists transId
    mapping(uint256 => bool) private transIds;

    /// @notice Addresses of super operators
    mapping(address => bool) public superOperators;

    /// @notice Requires sender to be contract super operator
    modifier isSuperOperator() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    event ClaimedSuccess(
        address  wallet,
        uint256 amount,
        string  transId
    );
    event ClaimedFailed(
        address  wallet,
        uint256 amount,
        string  transId
    );

    /// constructor 
    constructor() {
        superOperators[msg.sender] = true;
        _uxuyToken = UxuyToken(UXUYTOKEN);
    }

    
    function claim(
        uint256 amount,
        bytes memory signature,
        string memory transId
    ) public payable  {
        require(claimStatus, "claimStatus is false");
        require(amount > 0, " UxuyToken is zero");
        require(existsTransId(transId) == false, "Exists transId");
        require(verifySignature(transId,amount, msg.sender, signature), "Signature is invalid");

        // record
        setTransId(transId);

        try _uxuyToken.reward(amount, msg.sender) {
            emit ClaimedSuccess(msg.sender, amount, transId);
        } catch {
            emit ClaimedFailed(msg.sender, amount, transId);
        }
    }

    function setTransId(string memory transId) internal {
        bytes32 label = keccak256(bytes(transId));
        uint256 id = uint256(label);
        transIds[id] = true;
    }

    function existsTransId(string memory transId) internal view returns (bool){
        bytes32 label = keccak256(bytes(transId));
        uint256 id = uint256(label);
        if(transIds[id]){
            return true;
        }else{
            return false;
        }
    }

    function toMessageHash(string memory transId,uint256 amount, address to) public pure returns (bytes32) {
       return keccak256(abi.encodePacked(transId, amount, to));
    }

    function verifySignature(string memory transId, uint256 amount, address to, bytes memory signature) public view returns (bool){
        bytes32 hash = toMessageHash(transId, amount, to);
        return (signer == hash.toEthSignedMessageHash().recover(signature));
    }

    receive() external payable {}

    function getSigner() public view isSuperOperator returns (address)  {
        return signer;
    }

    function setSigner(address _addr) external isSuperOperator {
        signer = _addr;
    }

    function setUXUYToken(address _uxuytoken) external isSuperOperator {
        UXUYTOKEN = _uxuytoken;
        _uxuyToken = UxuyToken(UXUYTOKEN);
    }

    function setClaimStatus(bool _flag) external isSuperOperator {
        claimStatus = _flag;
    }

    function withdrawStuckToken(address _token, address _to) external isSuperOperator {
        require(_token != address(0), "_token address cannot be 0");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        TransferHelper.safeTransfer(_token, _to, _contractBalance);
    }

    function withdrawStuckEth(address toAddr) external isSuperOperator {
        (bool success, ) = toAddr.call{
            value: address(this).balance
        } ("");
        require(success);
    }


    /// @notice Allows super operator to update super operator
    function authorizeOperator(address _operator) external isSuperOperator {
        superOperators[_operator] = true;
    }

    /// @notice Allows super operator to update super operator
    function revokeOperator(address _operator) external isSuperOperator {
        superOperators[_operator] = false;
    }

}