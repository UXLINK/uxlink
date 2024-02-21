// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IProfileService {

		struct UserInfo {
        string nickName;
        string profileURI;
        string metaData;
    }

    /**
     * A profileURI set for the caller
     * @param owner : The owner of the profileURI.
     * @param profileURI : The transaction hash from arweave.
     */
    function setProfileURI(address owner, string memory profileURI) external;

    /**
     * To query the profileURI of an address.
     * @param owner : The address.
     * @return profileURI : The transaction hash from ipfs.
     */
    function profileURI(address owner) external view returns (string memory profileURI);

    /**
     * A userinfo set for the caller
     * @param owner : The owner of the profileURI.
     * @param nickName : nickName.
     * @param profileURI : profileURI.
     * @param metaData : metaData.
     */
    function setUserInfo(address owner, string memory nickName, string memory profileURI, string memory metaData) external;

    /**
     * A metadata set for the caller. If exist replace it, otherwise add new mapping.
     * @param owner : The owner of the profileURI.
     * @param metaData : user meta data.
     */
    function setUserMetadata(address owner, string memory metaData) external;

    /**
     * To query the UserInfo of an address.
     * @param owner : The address.
     * @return retUserInfo : user info and meta data.
     */
    function userInfo(address owner) external view returns (UserInfo memory retUserInfo);

}