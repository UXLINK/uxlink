// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UX7702ValidatorProxy is Initializable, UUPSUpgradeable, OwnableUpgradeable {
  using ECDSA for bytes32;
  uint256 public chainId;
  address private signer;
  mapping(address account => uint256 nonce) private nonces;
  mapping(bytes32 => uint256) private sigHashToRandom;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(uint256 _chainId) public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
    chainId = _chainId;
    signer = msg.sender;
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function setChainId(uint256 _chainId) external onlyOwner {
    chainId = _chainId;
  }

  function setSigner(address _addr) external onlyOwner {
    signer = _addr;
  }

  function verifySign(bytes calldata signature, address[] calldata targets, uint256[] calldata values, bytes[] calldata datas, uint256 random) external {
    require(sigHashToRandom[keccak256(abi.encodePacked(signature, msg.sender))] == 0, "Exists signature");
    sigHashToRandom[keccak256(abi.encodePacked(signature, msg.sender))] = random;
    uint256 nonce = _checkSignature(msg.sender, signature, targets, values, datas);
    require(nonce > nonces[msg.sender], "Invalid nonce");
    nonces[msg.sender] = nonce;
  }

  function checkSign(bytes calldata signature, uint256 random) external {
    bytes32 sigHash = keccak256(abi.encodePacked(signature, msg.sender));
    require(sigHashToRandom[sigHash] == random, "Signature check error");
    delete sigHashToRandom[sigHash];
  }

  function toMessageHash(uint256 sigChainId, uint256 validUntil, uint256 validAfter, uint256 nonce, address caller, address[] memory targets, uint256[] memory values, bytes[] memory datas) public pure returns (bytes32) {
    return _toMessageHash(sigChainId, validUntil, validAfter, nonce, caller, targets, values, datas);
  }

  function _checkSignature(address caller, bytes calldata signature, address[] memory targets, uint256[] memory values, bytes[] memory datas) internal view returns (uint256) {
    require(signature.length >= 193, "Signature too short");
    (uint256 sigChainId, uint256 validUntil, uint256 validAfter, uint256 nonce) = abi.decode(signature[0:128], (uint256, uint256, uint256, uint256));
    bytes memory signatureData = signature[signature.length - 65:];
    require(sigChainId == chainId, "Invalid chainId");
    require(block.timestamp >= validAfter, "Not valid yet");
    require(block.timestamp <= validUntil, "Expired");
    bytes32 hash = ECDSA.toEthSignedMessageHash(_toMessageHash(sigChainId, validUntil, validAfter, nonce, caller, targets, values, datas));
    address addr = ECDSA.recover(hash, signatureData);
    require(signer == addr, "Invalid signer");
    return nonce;
  }

  function _toMessageHash(uint256 sigChainId, uint256 validUntil, uint256 validAfter, uint256 nonce, address caller, address[] memory targets, uint256[] memory values, bytes[] memory datas) internal pure returns (bytes32) {
    bytes32 targetsHash = keccak256(abi.encodePacked(targets));
    bytes32 valuesHash = keccak256(abi.encodePacked(values));
    bytes memory datasPacked;
    for (uint i = 0; i < datas.length; i++) {
      datasPacked = abi.encodePacked(datasPacked, datas[i]);
    }
    bytes32 datasHash = keccak256(datasPacked);
    bytes32 hash = keccak256(abi.encodePacked(targetsHash, valuesHash, datasHash));
    return keccak256(abi.encodePacked(
      sigChainId,
      validUntil,
      validAfter,
      nonce,
      caller,
      hash
    ));
  }
}