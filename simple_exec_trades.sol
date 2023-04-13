pragma solidity ^0.8.13;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

address constant token_weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant token_wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant token_usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

address constant uniswap_v2_router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant sushi_v2_router = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
address constant pancake_v2_router = 0xEfF92A263d31888d860bD50809A8D171709b7b1c;

uint256 constant WEI_PER_ETH = 1000000000000000000;

interface IUniswapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWETH is IERC20 {
    receive() external payable;

    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

/* struct TradeInstruction { //problematic to pass as arg
        address dex_router_addr;
        address out_token_addr;
} */
function dex_addr(address[][2] memory trade_instructions)
    pure
    returns (address[] memory)
{
    return trade_instructions[0];
}

function out_addr(address[][2] memory trade_instructions)
    pure
    returns (address[] memory)
{
    return trade_instructions[1];
}

contract ExecTrades {
    function simple_trade(
        address router_addr,
        uint256 in_amount,
        address in_token_addr,
        address out_token_addr
    ) private {
        IERC20(in_token_addr).approve(router_addr, in_amount);
        address[] memory path;
        path = new address[](2);
        path[0] = in_token_addr;
        path[1] = out_token_addr;
        uint256 deadline = block.timestamp + 300;
        IUniswapRouter(router_addr).swapExactTokensForTokens(
            in_amount,
            1, //slippage isn't enforced.
            path,
            address(this),
            deadline
        );
    }

    function execute_trades(
        address[][2] calldata trade_instructions,
        uint256 amount
    ) public {
        uint last_idx = dex_addr(trade_instructions).length - 1;
        address in_token = out_addr(trade_instructions)[last_idx]; //The first in_token is implicitly the last out_token.
        uint start_balance = IERC20(in_token).balanceOf(address(this));

        for (uint j = 0; j <= last_idx; j++) {
            address dex_router_addr = dex_addr(trade_instructions)[j];
            address out_token = out_addr(trade_instructions)[j];
            uint256 pre_out_balance = IERC20(out_token).balanceOf(
                address(this)
            );
            simple_trade(dex_router_addr, amount, in_token, out_token);
            uint256 new_out_balance = IERC20(out_token).balanceOf(
                address(this)
            );
            amount = new_out_balance - pre_out_balance;
            in_token = out_token;
        }

        uint256 final_balance = IERC20(in_token).balanceOf(address(this));
        require(final_balance > start_balance, "Unprofitable trade route.");
    }

    address payable private constant WETH = payable(token_weth);

    //To obtain initial tokens.
    function wrapEther() external payable {
        uint256 balanceBefore = IWETH(WETH).balanceOf(address(this));
        uint256 ETHAmount = msg.value;

        //create WETH from ETH
        if (ETHAmount != 0) {
            IWETH(WETH).deposit{value: ETHAmount}();
            IWETH(WETH).transfer(address(this), ETHAmount);
        }
        require(
            IWETH(WETH).balanceOf(address(this)) - balanceBefore == ETHAmount,
            "Ethereum not deposited"
        );
    }
}

