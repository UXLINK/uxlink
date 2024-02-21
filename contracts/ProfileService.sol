// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";

import "./interfaces/IProfileService.sol";
import "./core/RelationUpgradeable.sol";


contract ProfileService is IProfileService, RelationUpgradeable {

    mapping(address => UserInfo) _userInfoMap;

   /**
     * A profileURI set for the caller
     * @param owner_ : The owner of the profileURI.
     * @param profileURI_ : The transaction hash from arweave.
     */
    function setProfileURI(address owner_, string memory profileURI_) external override{
        require(msg.sender == owner_ || _minters[msg.sender], "ProfileService: permission denied");
        _userInfoMap[owner_].profileURI = profileURI_;
    }

    /**
     * To query the profileURI of an address.
     * @param owner_ : The address.
     * @return profileURI_ : The transaction hash from ipfs.
     */
    function profileURI(address owner_) external view override returns (string memory profileURI_){
        return _userInfoMap[owner_].profileURI;
    }

    /**
     * A userinfo set for the caller
     * @param owner_ : The owner of the profileURI.
     * @param nickName_ : nickName.
     * @param profileURI_ : profileURI.
     * @param metaData_ : metaData.
     */
    function setUserInfo(address owner_, string memory nickName_, string memory profileURI_, string memory metaData_) external override{
        require(msg.sender == owner_ || _minters[msg.sender], "ProfileService: permission denied");
        _userInfoMap[owner_].nickName = nickName_;
        _userInfoMap[owner_].profileURI = profileURI_;
        _userInfoMap[owner_].metaData = metaData_;
    }

    /**
     * A metadata set for the caller. If exist replace it, otherwise add new mapping.
     * @param owner_ : The owner of the profileURI.
     * @param metaData_ : user meta data.
     */
    function setUserMetadata(address owner_, string memory metaData_) external override{
        require(msg.sender == owner_ || _minters[msg.sender], "ProfileService: permission denied");
        _userInfoMap[owner_].metaData = metaData_;
    }

    /**
     * To query the UserInfo of an address.
     * @param owner_ : The address.
     * @return retUserInfo : user info and meta data.
     */
    function userInfo(address owner_) external view override returns (UserInfo memory retUserInfo){
        return _userInfoMap[owner_];
    }
}
