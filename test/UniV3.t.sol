// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import {Test, console} from "forge-std/Test.sol";
import {TestToken} from "lib/testToken/src/TestToken.sol";
import {WETH9} from "lib/testToken/src/WETH9.sol";
import {NonfungiblePositionManager} from "lib/v3-periphery/contracts/NonfungiblePositionManager.sol";
import {UniswapV3Factory} from "lib/v3-core/contracts/UniswapV3Factory.sol";
import {SwapRouter} from "lib/v3-periphery/contracts/SwapRouter.sol";
import {NonfungibleTokenPositionDescriptor} from "lib/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager, INonfungiblePositionManager} from "lib/v3-periphery/contracts/NonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FullMath} from "lib/v3-core/contracts/libraries/FullMath.sol";
import {TickMath} from "lib/v3-core/contracts/libraries/TickMath.sol";
import "lib/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

contract UniV3Test is Test {
    TestToken public token1;
    TestToken public token2;
    WETH9 public weth;
    UniswapV3Factory public factory;
    SwapRouter public router;
    NonfungibleTokenPositionDescriptor public tokenDescriptor;
    NonfungiblePositionManager public positionManager;
    IUniswapV3Pool public pool_weth_token1;
    IUniswapV3Pool public pool_weth_token2;
    uint256 swapPrice;

    function setupCreate() public {
        token1 = new TestToken(1000000 ether);
        token2 = new TestToken(1000000 ether);
        weth = new WETH9();
        factory = new UniswapV3Factory();
        router = new SwapRouter(address(factory), address(weth));
        tokenDescriptor = new NonfungibleTokenPositionDescriptor(
            address(weth),
            0x0000000000000000000000000000000000000000000000000000000057455448
        );
        positionManager = new NonfungiblePositionManager(
            address(factory),
            address(weth),
            address(tokenDescriptor)
        );
    }

    function setUp() public {
        // deploy contracts
        setupCreate();

        weth.deposit{value: 2000 ether}();

        // approvals (may not be necessary)
        weth.approve(
            address(positionManager),
            0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        token1.approve(
            address(positionManager),
            0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );
        token2.approve(
            address(positionManager),
            0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );

        address pool1 = factory.createPool(
            address(weth),
            address(token1),
            3000
        );
        pool_weth_token1 = IUniswapV3Pool(pool1);

        address pool2 = factory.createPool(
            address(weth),
            address(token2),
            3000
        );
        pool_weth_token2 = IUniswapV3Pool(pool2);

        // initialize pools
        swapPrice = 1;
        console.log("price\t\t\t", swapPrice);
        uint160 sqrtPriceX96 = calculateSqrtPriceX96(swapPrice);
        IUniswapV3Pool(pool_weth_token1).initialize(sqrtPriceX96);
        IUniswapV3Pool(pool_weth_token2).initialize(sqrtPriceX96);
    }

    function test_setup() public {
        assertEq(token1.balanceOf(address(this)), 1000000 ether);
        assertEq(token2.balanceOf(address(this)), 1000000 ether);
        assertEq(weth.balanceOf(address(this)), 2000 ether);
        console.log("weth", address(weth));

        positionManager.baseURI();
    }

    function test_mint() public {
        // mint positions
        uint256 wethAmount = 10 ether;
        uint256 tokenAmount = 10 ether;

        int24 tickSpacing = pool_weth_token1.tickSpacing();
        (, int24 tick, , , , , ) = pool_weth_token1.slot0();

        (address payable _token0, address payable _token1) = address(weth) <
            address(token1)
            ? (payable(address(weth)), payable(address(token1)))
            : (payable(address(token1)), payable(address(weth)));
        (uint256 amount0, uint256 amount1) = address(weth) < address(token1)
            ? (wethAmount, tokenAmount)
            : (tokenAmount, wethAmount);

        int24 tickScalar = 4;
        int24 tickLower = tick - (tickSpacing * tickScalar);
        int24 tickUpper = tick + (tickSpacing * tickScalar);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: _token0,
                token1: _token1,
                fee: 3000,
                tickLower: -887220,
                tickUpper: 887220,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 50000
            });
        positionManager.mint(params);
    }

    // utils ########################################

    /// @dev Calculate sqrtPriceX96 for a given price
    /// @param price The initial price as a fixed-point number (token1/token0) scaled to 18 decimals
    /// @return sqrtPriceX96 The square root price scaled by 2^96
    function calculateSqrtPriceX96(
        uint256 price
    ) internal pure returns (uint160 sqrtPriceX96) {
        // Fixed-point scale factor for sqrtPriceX96
        uint256 Q96 = 2 ** 96;

        // Calculate sqrt(price) using an approximation
        uint256 sqrtPrice = sqrt(price);

        // Multiply by Q96 and divide precisely using FullMath
        sqrtPriceX96 = uint160(FullMath.mulDiv(sqrtPrice, Q96, 1));
    }

    /// @dev Approximate square root function for uint256
    /// @param x The input value to compute the square root
    /// @return result The approximate square root of x
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        result = x;
        uint256 k = (x + 1) / 2;
        while (k < result) {
            result = k;
            k = (x / k + k) / 2;
        }
    }

    function test_sqrt() public {
        assertEq(sqrt(100), 10);
        assertEq(sqrt(10000), 100);
        assertEq(sqrt(1000000), 1000);
        assertEq(sqrt(9), 3);
    }

    /// @dev Calculates tickLower and tickUpper for a given price range
    /// @param priceLower The lower price of the range (token1/token0)
    /// @param priceUpper The upper price of the range (token1/token0)
    /// @param tickSpacing The tick spacing of the Uniswap V3 pool
    /// @return tickLower The aligned lower tick
    /// @return tickUpper The aligned upper tick
    function calculateTicks(
        uint256 priceLower,
        uint256 priceUpper,
        uint24 tickSpacing
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        // Ensure price bounds are valid
        require(
            priceLower > 0 && priceUpper > priceLower,
            "Invalid price range"
        );

        // Calculate the ticks for the given prices
        int24 tickLowerRaw = getTickFromPrice(priceLower);
        console.log("tickLowerRaw", tickLowerRaw);
        int24 tickUpperRaw = getTickFromPrice(priceUpper);
        console.log("tickUpperRaw", tickUpperRaw);

        // Align ticks to the tick spacing
        tickLower = alignToTickSpacing(tickLowerRaw, tickSpacing);
        tickUpper = alignToTickSpacing(tickUpperRaw, tickSpacing);

        console.log("tickLower", tickLower);
        console.log("tickUpper", tickUpper);

        // Ensure tickLower is strictly less than tickUpper
        require(tickLower < tickUpper, "tickLower must be less than tickUpper");
    }

    /// @dev Converts a price (token1/token0) to a tick
    /// @param price The price to convert
    /// @return tick The corresponding tick
    function getTickFromPrice(
        uint256 price
    ) internal pure returns (int24 tick) {
        // Use TickMath to calculate the square root price
        uint160 sqrtPriceX96 = calculateSqrtPriceX96(price);
        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    /// @dev Aligns a tick to the nearest multiple of the tick spacing
    /// @param tick The raw tick value
    /// @param tickSpacing The tick spacing of the pool
    /// @return alignedTick The tick aligned to the tick spacing
    function alignToTickSpacing(
        int24 tick,
        uint24 tickSpacing
    ) internal pure returns (int24 alignedTick) {
        alignedTick = int24((tick / int24(tickSpacing)) * int24(tickSpacing));
    }

    /// @dev Example function to calculate ticks and liquidity for 1:1 price range
    /// @param amount0Desired Amount of token0 (e.g., 1000 * 10^18)
    /// @param amount1Desired Amount of token1 (e.g., 1000 * 10^18)
    /// @return tickLower The lower tick
    /// @return tickUpper The upper tick
    /// @return liquidity The required liquidity
    function calculateLiquidityForOneToOneRate(
        uint256 amount0Desired,
        uint256 amount1Desired
    )
        internal
        pure
        returns (int24 tickLower, int24 tickUpper, uint128 liquidity)
    {
        // Current price is 1:1, sqrt(1) = 1 in Q96 format
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0); // Tick 0 corresponds to 1:1 price

        // Define the range: sqrtPriceLower and sqrtPriceUpper
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(-120); // 0.8
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(120); // 1.2

        // Convert ticks to ensure alignment with tick spacing
        tickLower = alignToTickSpacing(-120, 60);
        tickUpper = alignToTickSpacing(120, 60);

        // Calculate liquidity using the LiquidityAmounts library
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            amount0Desired,
            amount1Desired
        );
    }
}
