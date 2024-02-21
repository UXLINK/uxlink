// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./libs/IterableMapping.sol";

interface IUXGroupAccount {
    function owner() external view returns (address);
}


// TODO: SharesSubject == UXGroupAccount => UXGroupOwner
contract UXGroupShares {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    // 
    struct SubjectData {
        address SubjectAddress;
        uint256 Val;
    }
    
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;

    /// @notice  ERC20 token
    IERC20 public settlementToken;
    address public settlementTokenAddress;

    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => uint256) public sharesSupply;

    // SharesSubject => Hoders
    mapping(address => IterableMapping.Map) private sharesHoders;

    // SharesSubject => Capital : shares value 
    mapping(address => uint256) public sharesCapitals;

    // SharesSubject => GroupOwner 
    mapping(address => address) public groupOwners;

    /// @notice Addresses of super operators
    mapping(address => bool) public superOperators;

    /// Events
    /// @notice Emitted after super operator is updated
    event AuthorizedOperator(address indexed operator, address indexed holder);

    /// @notice Emitted after super operator is updated
    event RevokedOperator(address indexed operator, address indexed holder);

    /// @notice Emitted after set groupOwners is updated
    event SetGroupOwners(address groupAccount, address groupOwner);

    /// @notice Emitted top up capital
    event TopUpCapital(address operator, address groupAccount, uint256 price);

    /// @notice trade info
    event Trade(address trader, address subject, bool isBuy, uint256 shareAmount, uint256 tokenAmount, uint256 protocolTokenAmount, uint256 subjectTokenAmount, uint256 supply, uint256 capital);

     /// @notice Requires sender to be contract super operator
    modifier onlyAdmin() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    constructor(address _settlementTokenAddress) {
        superOperators[msg.sender] = true;
        settlementTokenAddress = _settlementTokenAddress;
        settlementToken = IERC20(_settlementTokenAddress);
        protocolFeeDestination = msg.sender;
    }

    function setSettlementToken(address _settlementTokenAddress) public onlyAdmin {
        settlementTokenAddress = _settlementTokenAddress;
        settlementToken = IERC20(_settlementTokenAddress);
    }

    function setFeeDestination(address _feeDestination) public onlyAdmin {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyAdmin {
        protocolFeePercent = _feePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyAdmin {
        subjectFeePercent = _feePercent;
    }

    function setSharesSubjectGroupOwner(address _uxgroupAccount) public {
        require(_uxgroupAccount != address(0), "UXGroupAccount address not set");
        IUXGroupAccount groupAccount = IUXGroupAccount(_uxgroupAccount);
        address groupOwner = groupAccount.owner();

        require(groupOwner != address(0), "UXGroupAccount owner nonexistent");
        groupOwners[_uxgroupAccount] = groupOwner;
        emit SetGroupOwners(_uxgroupAccount, groupOwner);
    }

    function getTokenBalance(address tokenAddress, address _uxgroupAccount) public view returns (uint256) {
        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 balance = tokenContract.balanceOf(_uxgroupAccount);
        return balance;
    }

    function getEthBalance(address _uxgroupAccount) external view returns (uint256) {
        uint256 balance = _uxgroupAccount.balance;
        return balance;
    }

    function getHolders(address _uxgroupAccount) public view returns (uint256) {
        return sharesHoders[_uxgroupAccount].size();
    }

    function multiGetHolders(address[] memory sharesSubjects) public view returns (SubjectData[] memory res) {
        require(sharesSubjects.length > 0, "sharesSubjects.len is invalid ");
        res = new SubjectData[](sharesSubjects.length);
        for (uint256 i = 0; i < sharesSubjects.length; i++) {
            SubjectData memory one;
            one.SubjectAddress = sharesSubjects[i];
            one.Val = getHolders(sharesSubjects[i]);
            res[i] = one;
        }
    }

    function getCapital(address _uxgroupAccount) public view returns (uint256) {
        return sharesCapitals[_uxgroupAccount];
    }

    function multiGetCapital(address[] memory sharesSubjects) public view returns (SubjectData[] memory res) {
        require(sharesSubjects.length > 0, "sharesSubjects.len is invalid ");
        res = new SubjectData[](sharesSubjects.length);
        for (uint256 i = 0; i < sharesSubjects.length; i++) {
            SubjectData memory one;
            one.SubjectAddress = sharesSubjects[i];
            one.Val = getCapital(sharesSubjects[i]);
            res[i] = one;
        }
    }

    function getBaseNumber(uint256 holders,uint256 supply,uint256 amount) public pure returns (uint256) {
        if(supply == 0){
            return 1 ether;
        }
        uint256 number = 2 * holders * supply;
        uint baseNumer = Math.log2(number,Math.Rounding.Up);
        return baseNumer * amount;
    }

    function getPrice(uint256 supply, uint256 amount, address sharesSubject) public view returns (uint256) {
        uint256 holders = getHolders(sharesSubject);
        if(supply == 0){
            return 1 ether;
        }
        uint256 baseNumer = getBaseNumber(holders, supply, amount);
        if(baseNumer < 1){
            baseNumer = 1;
        }
        uint256 summation = baseNumer * 100;
        return summation * 1 ether;
    }

    function getBuyPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject], amount, sharesSubject);
    }

    function multiGetBuyPrice(address[] memory sharesSubjects) public view returns (SubjectData[] memory res) {
        require(sharesSubjects.length > 0, "sharesSubjects.len is invalid ");
        res = new SubjectData[](sharesSubjects.length);
        for (uint256 i = 0; i < sharesSubjects.length; i++) {
            SubjectData memory one;
            one.SubjectAddress = sharesSubjects[i];
            one.Val = getBuyPrice(sharesSubjects[i], 1);
            res[i] = one;
        }
    }
    

    function getSellPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 capital = sharesCapitals[sharesSubject];
        if(capital == 0){
            return 0;
        }
        uint256 sellPrice = getPrice(sharesSupply[sharesSubject] - amount, amount, sharesSubject);
        if(sellPrice > capital){
            sellPrice = capital;
        }
        return sellPrice;
    }

    function multiGetSellPrice(address[] memory sharesSubjects) public view returns (SubjectData[] memory res) {
        require(sharesSubjects.length > 0, "sharesSubjects.len is invalid ");
        res = new SubjectData[](sharesSubjects.length);
        for (uint256 i = 0; i < sharesSubjects.length; i++) {
            SubjectData memory one;
            one.SubjectAddress = sharesSubjects[i];
            one.Val = getSellPrice(sharesSubjects[i], 1);
            res[i] = one;
        }
    }

    function multiGetSupply(address[] memory sharesSubjects) public view returns (SubjectData[] memory res) {
        require(sharesSubjects.length > 0, "sharesSubjects.len is invalid ");
        res = new SubjectData[](sharesSubjects.length);
        for (uint256 i = 0; i < sharesSubjects.length; i++) {
            SubjectData memory one;
            one.SubjectAddress = sharesSubjects[i];
            one.Val = sharesSupply[sharesSubjects[i]];
            res[i] = one;
        }
    }

    function getHoldersListBySubject(address sharesSubject) public view returns (SubjectData[] memory res) {
        uint256 len = sharesHoders[sharesSubject].size();
        if(len < 1){
            res = new SubjectData[](len);
            return res;
        }
        IterableMapping.Map storage mappingManager = sharesHoders[sharesSubject];
        res = new SubjectData[](len);
        for (uint256 i = 0; i < len; i++) {
            SubjectData memory one;
            one.SubjectAddress = mappingManager.getKeyAtIndex(i);
            one.Val = mappingManager.get(one.SubjectAddress);
            res[i] = one;
        }
    }

    // top up
    function topUpCapital(address sharesSubject, uint256 price) public {
        uint256 tokenBalance = getTokenBalance(settlementTokenAddress,msg.sender);
        require(tokenBalance >= price, "Insufficient payment");

        bool success0 = settlementToken.transferFrom(msg.sender,address(this), price);
        require(success0, "Unable to send funds");

        sharesCapitals[sharesSubject] = sharesCapitals[sharesSubject] + price;
        emit TopUpCapital(msg.sender, sharesSubject, price);
    }

    function getBuyPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 price = getBuyPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 100;
        uint256 subjectFee = price * subjectFeePercent / 100;
        return price + protocolFee + subjectFee;
    }

    function getSellPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 price = getSellPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 100;
        uint256 subjectFee = price * subjectFeePercent / 100;
        return price - protocolFee - subjectFee;
    }

    // sharesSubject = groupAccount
    function buyShares(address sharesSubject, uint256 amount) public payable {
        uint256 supply = sharesSupply[sharesSubject];
        if(supply == 0){
            setSharesSubjectGroupOwner(sharesSubject);
        }
        require(supply > 0 || groupOwners[sharesSubject] == msg.sender, "Only the shares' group owner can buy the first share");
        uint256 price = getBuyPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 100;
        uint256 subjectFee = price * subjectFeePercent / 100;

        uint256 tokenBalance = getTokenBalance(settlementTokenAddress,msg.sender);
        require(tokenBalance >= price + protocolFee + subjectFee, "Insufficient payment");

        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] + amount;
        sharesSupply[sharesSubject] = supply + amount;

        IterableMapping.Map storage mappingManager = sharesHoders[sharesSubject];
        mappingManager.set(msg.sender, sharesBalance[sharesSubject][msg.sender]);
       
        sharesCapitals[sharesSubject] = sharesCapitals[sharesSubject] + price;
        uint256 capitail = sharesCapitals[sharesSubject];

        emit Trade(msg.sender, sharesSubject, true, amount, price, protocolFee, subjectFee, supply + amount, capitail);

        // allowance mechanism. `amount` is then deducted from the caller's allowance.
        (bool success0 ) = settlementToken.transferFrom(msg.sender,address(this), price+protocolFee+subjectFee);
        // transfer fee
        SafeERC20.safeTransfer(settlementToken, protocolFeeDestination, protocolFee);
        SafeERC20.safeTransfer(settlementToken, sharesSubject, subjectFee);
        require(success0,  "Unable to send funds");

        
    }

    function sellShares(address sharesSubject, uint256 amount) public payable {
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getSellPrice(sharesSubject, amount);
        require(price > 0, "Cannot sell share, no funds");
        require(sharesCapitals[sharesSubject] - price >= 0, "Cannot sell share, no funds");

        uint256 protocolFee = price * protocolFeePercent / 100;
        uint256 subjectFee = price * subjectFeePercent / 100;
        require(sharesBalance[sharesSubject][msg.sender] >= amount, "Insufficient shares");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] - amount;
        sharesSupply[sharesSubject] = supply - amount;

        IterableMapping.Map storage mappingManager = sharesHoders[sharesSubject];
        if(sharesBalance[sharesSubject][msg.sender] > 0){
            mappingManager.set(msg.sender, sharesBalance[sharesSubject][msg.sender]);
        }else{
            mappingManager.remove(msg.sender);
        }
        
        sharesCapitals[sharesSubject] = sharesCapitals[sharesSubject] - price;
        uint256 capitail = sharesCapitals[sharesSubject];
        emit Trade(msg.sender, sharesSubject, false, amount, price, protocolFee, subjectFee, supply - amount, capitail);

        // transfer fee
        SafeERC20.safeTransfer(settlementToken, msg.sender, price - protocolFee - subjectFee);
        SafeERC20.safeTransfer(settlementToken, protocolFeeDestination, protocolFee);
        SafeERC20.safeTransfer(settlementToken, sharesSubject, subjectFee);

    }

    /// @notice Allows super operator to update super operator
    function authorizeOperator(address _operator) external onlyAdmin {
        superOperators[_operator] = true;
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /// @notice Allows super operator to update super operator
    function revokeOperator(address _operator) external onlyAdmin {
        superOperators[_operator] = false;
        emit RevokedOperator(_operator, msg.sender);
    }

    receive() external payable {}

    /**
     * Allow withdraw of ETH tokens from the contract
     */
    function withdrawETH(address recipient, uint256 amount) public onlyAdmin {
        require(amount > 0, "amount is zero");
        uint256 balance = address(this).balance;
        require(balance >= amount, "balance must be greater than amount");
        payable(recipient).transfer(amount);
    }

}