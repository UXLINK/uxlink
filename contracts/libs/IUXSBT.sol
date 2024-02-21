// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;


interface IUXSBT {
  function register(address owner, string calldata name, bool reverseRecord) external returns (uint tokenId);
  function multiRegister(address[] memory to, string[] calldata name) external;
}
