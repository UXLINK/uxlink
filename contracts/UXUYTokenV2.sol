// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title UXUYToken
 */
contract UXUYTokenV2 is ERC20, ERC20Burnable, ERC20Snapshot, Pausable {
    /// @notice Addresses of black users
    mapping(address => bool) private _blacklist;
    mapping(address => bool) public _whitelist;
    bool public isUsingWhitelist;

    bool public enableUpgrade;
    IERC20 public OldUXUYToken;
    address public constant BLACK_HOLE = address(0);
    address public constant deadAddress = address(0xdead);

    /// @notice Addresses of super operators
    mapping(address => bool) public superOperators;

    /// Events
    event UpgradeEvent(address userAddress, uint256 amount);
    event RewardEvent(address userAddress, uint256 amount);

    /// @notice Emitted after super operator is updated
    event AuthorizedOperator(address indexed operator, address indexed holder);

    /// @notice Emitted after super operator is updated
    event RevokedOperator(address indexed operator, address indexed holder);

    /// @notice Requires sender to be contract super operator
    modifier isSuperOperator() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    constructor() ERC20("UXUY Token", "UXUY") {
        superOperators[msg.sender] = true;
        isUsingWhitelist = true;
        enableUpgrade = true;
        addToWhitelist(BLACK_HOLE);
    }

    /// @notice Proof Of Link (POL)
    function reward(uint256 amount, address toUser) public isSuperOperator returns (bool){
        require(toUser != address(0), "toUser Cannot be the zero address");
        require(amount > 0, "amount Cannot be the zero ");
        super._mint(toUser, amount);
        emit RewardEvent(toUser,  amount);
        return true;
    }

    function multiReward(address[] memory to, uint256[] calldata amount) public isSuperOperator {
        require(to.length == amount.length, "address.len must equal amount.len ");
        for (uint256 i = 0; i < to.length; i++) {
            reward(amount[i],to[i]);
        }
    }

    /// 1:1 
    function upgrade(uint256 amount) public returns (bool){
        require(enableUpgrade, "upgrade closed!");
        require(amount > 0, "amount Cannot be the zero!");
        require(OldUXUYToken.balanceOf(msg.sender) >= amount,"Your old token balance is insufficient!");

        // send old token to black hole
        (bool sent) = OldUXUYToken.transferFrom(msg.sender, address(this), amount);
        require(sent, "Failed to transfer old token!");

        super._mint(msg.sender, amount);
        emit UpgradeEvent(msg.sender, amount);
        return true;
    }

    /// Getters to allow the same blacklist to be used also by other contracts ///////
    function getBlackListStatus(address _maker) external view returns (bool) {
        return _blacklist[_maker];
    }

    /// The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
        require(!_blacklist[from], "Sending address is blacklisted.");
        require(!_blacklist[to], "Receiving address is blacklisted");
        if(isUsingWhitelist){
            require(_whitelist[from] || _whitelist[to], "Sending Or Receiving address is not on the whitelist");
        }
    }

    /// @dev called by the owner to pause, triggers stopped state
    function pause() public isSuperOperator whenNotPaused {
        super._pause();
    }

    /// @dev called by the owner to unpause, returns to normal state
    function unpause() public isSuperOperator whenPaused {
        super._unpause();
    }

    /// @dev called by the owner
    function burn(uint256 amount) public override  {
        super.burn(amount);
    }

    /**
     * @notice Creates a new snapshot and returns its snapshot id (external)
     * Requirements: the caller must be the owner
     */
    function snapshot() external isSuperOperator returns (uint256) {
        return super._snapshot();
    }

    function addToBlacklist(address _user) public isSuperOperator {
        require(!_blacklist[_user], "User is already on the blacklist.");
        _blacklist[_user] = true;
    }

    function removeFromBlacklist(address _user) public isSuperOperator {
        require(_blacklist[_user], "User is not on the blacklist.");
        delete _blacklist[_user];
    }

    /// @notice Allows super operator to update super operator
    function authorizeOperator(address _operator) external isSuperOperator {
        superOperators[_operator] = true;
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /// @notice Allows super operator to update super operator
    function revokeOperator(address _operator) external isSuperOperator {
        superOperators[_operator] = false;
        emit RevokedOperator(_operator, msg.sender);
    }

    function addToWhitelist(address _address) public isSuperOperator {
        require(!_whitelist[_address], "User is already on the whitelist.");
        _whitelist[_address] = true;
    }

    function removeFromWhitelist(address _address) external isSuperOperator {
         require(_whitelist[_address], "User is not on the whitelist.");
        _whitelist[_address] = false;
    }

    function getWhiteListStatus(address _maker) external view returns (bool) {
        return _whitelist[_maker];
    }

    function setUsingWhitelistStatus(bool _status) external isSuperOperator {
         isUsingWhitelist = _status;
    }

    function setUpgradeToken(address oldTokenAddress) external isSuperOperator {
        OldUXUYToken = IERC20(oldTokenAddress);
    }

    function setEnableUpgrade(bool _status) external isSuperOperator {
        enableUpgrade = _status;
    }

}