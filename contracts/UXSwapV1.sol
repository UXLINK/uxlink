// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;


import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import './libs/ISwapRouter02.sol';

contract UXSwapV1 {

    // Anti-bot and anti-whale mappings and variables
    mapping(address => bool) _blacklist;

    // Uniswap V3: Router 2
    ISwapRouter02 public swapRouterV3;
    address public constant UNISWAP_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address public constant UNISWAP_V3_QUOTER2 = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    // set the pool fee to 0.3%.
    uint24 public constant defaultPoolFee = 3000;

    IUniswapV2Router02 public uniswapRouter;
    address public WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    //address of the uniswap v2 router
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    

    // Commission in percentage (e.g., 10 for 1%)
    uint256 public commissionPercentage; 
    address public revCommissionWallet;
    uint256 public deadlineDelayTime; 

    /// @notice Addresses of super operators
    mapping(address => bool) public superOperators;

    /// @notice Requires sender to be contract super operator
    modifier isSuperOperator() {
        // Ensure sender is super operator
        require(superOperators[msg.sender], "Not super operator");
        _;
    }

    /// events
    event RevCommissionWalletUpated(
        address newWallet,
        address oldWallet
    );

    event TradeSuccess(
        address trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address to,
        uint256 commission,
        int256  code
    );

    /// constructor 
    constructor() {
        superOperators[msg.sender] = true;
        swapRouterV3 =  ISwapRouter02(UNISWAP_V3_ROUTER);
        uniswapRouter = IUniswapV2Router02(
            UNISWAP_V2_ROUTER
        );
        revCommissionWallet = msg.sender;
        deadlineDelayTime = 300;
        commissionPercentage = 10;
    }

    receive() external payable {}

    /// 
    function quoted(address tokenIn, address tokenOut, uint256 amountIn, uint24 poolFee) public returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate) {
        IQuoterV2 quoter = IQuoterV2(UNISWAP_V3_QUOTER2);
        IQuoterV2.QuoteExactInputSingleParams memory quoterParams;
        quoterParams.tokenIn = tokenIn;
        quoterParams.tokenOut = tokenOut;
        quoterParams.amountIn = amountIn;
        quoterParams.fee = poolFee;
        quoterParams.sqrtPriceLimitX96 = 0;
        (amountOut,sqrtPriceX96After,initializedTicksCrossed,gasEstimate) = quoter.quoteExactInputSingle(quoterParams);
    }
    
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its tokenIn for this function to succeed.
    /// @return amountOut The amount of tokenOut received.
    function swapExactInputSingle(address tokenIn, address tokenOut, uint256 amountIn, uint24 poolFee,  uint256 amountOutMinimum, address recipient, int256 code) external returns (uint256 amountOut) {
        require(!_blacklist[msg.sender], "User is on the blacklist.");
        // msg.sender must approve this contract
        // Transfer the specified amount of tokenIn to this contract.
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
    
        // Calculating the fee
        uint256 commission = calculateCommission(amountIn);
        uint256 amountInAfterCommission = amountIn - commission;
        // Approve the router to spend tokenIn.
        TransferHelper.safeApprove(tokenIn, address(swapRouterV3), amountInAfterCommission);

        ISwapRouter02.ExactInputSingleParams memory params =
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient:recipient,
                amountIn: amountInAfterCommission,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });
        // swap.
        amountOut = swapRouterV3.exactInputSingle(params);
        if (commission > 0) {
            // Transfer the fee to the revCommissionWallet
            TransferHelper.safeTransfer(tokenIn, revCommissionWallet, commission);
        }
        // 
        TransferHelper.safeApprove(tokenIn, address(swapRouterV3), 0);

        emit TradeSuccess(msg.sender,tokenIn,tokenOut,amountIn,amountOut,recipient,commission,code);
    }

    /// @notice swapInputMultiplePools swaps a fixed amount of tokenIn for a maximum possible amount of tokenOut through an intermediary pool.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its tokenIn for this function to succeed.
    /// @return amountOut The amount of tokenOut received after the swap.
    function swapExactInputMultihop(address[] memory _path, uint24[] memory _fee, uint256 amountIn, uint256 amountOutMinimum, address recipient, int256 code) external returns (uint256 amountOut) {
        require(!_blacklist[msg.sender], "User is on the blacklist.");
        require(_path.length > 1, "_path invalid!");
        require(_path.length == _fee.length+1, "_path or _fee invalid!");

        address tokenIn = _path[0];
        address tokenOut = _path[_path.length-1];
        // Transfer `amountIn` of tokenIn to this contract.
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

        // Calculating the fee
        uint256 commission = calculateCommission(amountIn);
        uint256 amountInAfterCommission = amountIn - commission;
        // Approve the router to spend tokenIn.
        TransferHelper.safeApprove(tokenIn, address(swapRouterV3), amountInAfterCommission);


        ISwapRouter02.ExactInputParams memory params =
            ISwapRouter02.ExactInputParams({
                path: _encodePathV3(_path,_fee),
                recipient: recipient,
                amountIn: amountInAfterCommission,
                amountOutMinimum: amountOutMinimum
            });
        // Executes the swap.
        amountOut = swapRouterV3.exactInput(params);
        
        if (commission > 0) {
            TransferHelper.safeTransfer(tokenIn, revCommissionWallet, commission);
        }
        TransferHelper.safeApprove(tokenIn, address(swapRouterV3), 0);
        emit TradeSuccess(msg.sender,tokenIn,tokenOut,amountIn,amountOut,recipient,commission,code);
    }

    function _encodePathV3(address[] memory _path, uint24[] memory _fees) internal pure returns (bytes memory path) {
        path = abi.encodePacked(_path[0]);
        for(uint i = 0; i < _fees.length; i++){
            path = abi.encodePacked(path, _fees[i], _path[i+1]);
        }
    }

    function tradeForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        int256 code
    ) external {
        require(!_blacklist[msg.sender], "User is on the blacklist.");
        // Transfer the specified amount of tokenIn to this contract.
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = WETH;

        // Calculating the fee
        uint256 commission = calculateCommission(amountIn);
        uint256 amountInAfterCommission = amountIn - commission;

        // Approve the router to spend tokenIn.
        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), amountInAfterCommission);

        uint256 deadline = block.timestamp + deadlineDelayTime;
        uint[] memory amounts = uniswapRouter.swapExactTokensForETH(
            amountInAfterCommission,
            amountOutMin,
            path,
            to,
            deadline
        );

        if (commission > 0) {
            // Transfer the fee to the revCommissionWallet
            TransferHelper.safeTransfer(tokenIn, revCommissionWallet, commission);
        }
        
        // 
        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), 0);

        emit TradeSuccess(msg.sender,tokenIn,path[1],amountIn,amounts[1],to,commission,code);
    }

    function trade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        int256 code
    ) external {
        require(!_blacklist[msg.sender], "User is on the blacklist.");
        // Assuming you've already approved this contract to spend `amountIn` of `tokenIn`

        // Transfer the specified amount of tokenIn to this contract.
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

         // Calculating the fee
        uint256 commission = calculateCommission(amountIn);
        uint256 amountInAfterCommission = amountIn - commission;

        // Approve the router to spend tokenIn.
        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), amountInAfterCommission);

        uint256 deadline = block.timestamp + deadlineDelayTime;
        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            amountInAfterCommission,
            amountOutMin,
            path,
            to,
            deadline
        );

        if (commission > 0) {
            // Transfer the fee to the revCommissionWallet
            TransferHelper.safeTransfer(tokenIn, revCommissionWallet, commission);
        }

        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), 0);

        emit TradeSuccess(msg.sender,tokenIn,tokenOut,amountIn,amounts[1],to,commission,code);
    }

    function tradeSupportingFee(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        int256 code
    ) external {
        require(!_blacklist[msg.sender], "User is on the blacklist.");
        // Assuming you've already approved this contract to spend `amountIn` of `tokenIn`

        // Transfer the specified amount of tokenIn to this contract.
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

         // Calculating the fee
        uint256 commission = calculateCommission(amountIn);
        uint256 amountInAfterCommission = amountIn - commission;

        // Approve the router to spend tokenIn.
        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), amountInAfterCommission);

        uint256 deadline = block.timestamp + deadlineDelayTime;
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountInAfterCommission,
            amountOutMin,
            path,
            to,
            deadline
        );

        if (commission > 0) {
            // Transfer the fee to the revCommissionWallet
            TransferHelper.safeTransfer(tokenIn, revCommissionWallet, commission);
        }

        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), 0);

        emit TradeSuccess(msg.sender,tokenIn,tokenOut,amountIn,0,to,commission,code);
    }

    function tradeETH(
        address tokenOut,
        uint256 amountOutMin,
        address to,
        int256 code
    ) external payable {
        require(!_blacklist[msg.sender], "User is on the blacklist.");

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenOut;

        uint256 amountIn = msg.value;
        require(amountIn > 0, "No ETH sent");

        uint256 commission = calculateCommission(amountIn);
        uint256 amountInAfterCommission = amountIn - commission;
        
        // Perform the swap
        uint256 deadline = block.timestamp + deadlineDelayTime;
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: amountInAfterCommission}(
            amountOutMin,
            path,
            to,
            deadline
        );
        if (commission > 0) {
            (bool success, ) = revCommissionWallet.call{value: commission}("");
            require(success, "ETH transfer failed");
        }
        emit TradeSuccess(msg.sender,WETH,tokenOut,amountIn,amounts[1],to,commission,code);
    }

    function tradeETHSupportingFee(
        address tokenOut,
        uint256 amountOutMin,
        address to,
        int256 code
    ) external payable {
        require(!_blacklist[msg.sender], "User is on the blacklist.");

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenOut;

        uint256 amountIn = msg.value;
        require(amountIn > 0, "No ETH sent");

        uint256 commission = calculateCommission(amountIn);
        uint256 amountInAfterCommission = amountIn - commission;
        
        // Perform the swap
        uint256 deadline = block.timestamp + deadlineDelayTime;
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountInAfterCommission}(
            amountOutMin,
            path,
            to,
            deadline
        );
        if (commission > 0) {
            (bool success, ) = revCommissionWallet.call{value: commission}("");
            require(success, "ETH transfer failed");
        }
        emit TradeSuccess(msg.sender,WETH,tokenOut,amountIn,0,to,commission,code);
    }

    function setCommissionPercentage(uint256 _commissionPercentage)
        external
        isSuperOperator
    {
        require(
            _commissionPercentage <= 1000,
            "Commission percentage must be less than or equal to 100"
        );
        commissionPercentage = _commissionPercentage;
    }

    function calculateCommission(uint256 amount) internal view returns (uint256) {
        return (amount * commissionPercentage) / 1000;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external {
       
        uint256 deadline = block.timestamp + deadlineDelayTime;
        uniswapRouter.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    /// Getters to allow the same blacklist to be used also by other contracts ///////
    function getBlackListStatus(address _maker) external view returns (bool) {
        return _blacklist[_maker];
    }

    function addToBlacklist(address _user) public isSuperOperator {
        require(!_blacklist[_user], "User is already on the blacklist.");
        require(
            _user != address(UNISWAP_V2_ROUTER), 
            "Cannot blacklist token's v2 router."
        );
        _blacklist[_user] = true;
    }

    function removeFromBlacklist(address _user) public isSuperOperator {
        require(_blacklist[_user], "User is not on the blacklist.");
        delete _blacklist[_user];
    }

    /// @notice Allows super operator to update super operator
    function authorizeOperator(address _operator) external isSuperOperator {
        superOperators[_operator] = true;
    }

    /// @notice Allows super operator to update super operator
    function revokeOperator(address _operator) external isSuperOperator {
        superOperators[_operator] = false;
    }

    function setDeadlineDelayTime(uint256 _time) external isSuperOperator {
        deadlineDelayTime = _time;
    }

    function setRevCommissionWallet(address _to) external isSuperOperator {
        emit RevCommissionWalletUpated(_to, revCommissionWallet);
        revCommissionWallet = _to;
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

    function setUniswapRouterV2(address _addr)  external isSuperOperator{
       uniswapRouter = IUniswapV2Router02(_addr);
    }

    function setUniswapRouterV3(address _addr)  external isSuperOperator{
       swapRouterV3 =  ISwapRouter02(_addr);
    }

    function setWETH(address tokenAddr)  external isSuperOperator{
       WETH = tokenAddr;
    }

    function factory() external view returns (address) {
        return uniswapRouter.factory();
    }

    function quote(uint amountA, uint reserveA, uint reserveB) external view returns (uint amountB) {
        return uniswapRouter.quote(amountA,reserveA,reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external view returns (uint amountOut){
        return uniswapRouter.getAmountOut(amountIn,reserveIn,reserveOut); 
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external view returns (uint amountIn) {
        return uniswapRouter.getAmountIn(amountOut,reserveIn,reserveOut); 
    }

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts) {
        return uniswapRouter.getAmountsOut(amountIn,path); 
    }

    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts) {
        return uniswapRouter.getAmountsIn(amountOut,path); 
    }

}