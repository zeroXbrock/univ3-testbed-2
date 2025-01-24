// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7;
pragma abicoder v2;

import {Test, console} from "forge-std/Test.sol";
import {TestToken} from "lib/testToken/src/TestToken.sol";
import {WETH9} from "lib/testToken/src/WETH9.sol";
import {NonfungiblePositionManager} from "lib/v3-periphery/contracts/NonfungiblePositionManager.sol";
import {UniswapV3Factory} from "lib/v3-core/contracts/UniswapV3Factory.sol";
import {SwapRouter} from "lib/v3-periphery/contracts/SwapRouter.sol";
import {NonfungibleTokenPositionDescriptor} from "lib/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "lib/v3-periphery/contracts/NonfungiblePositionManager.sol";

contract CounterTest is Test {
    TestToken public token1;
    TestToken public token2;
    WETH9 public weth;
    UniswapV3Factory public factory;
    SwapRouter public router;
    NonfungibleTokenPositionDescriptor public tokenDescriptor;
    NonfungiblePositionManager public positionManager;

    function setUp() public {
        // CREATE
        token1 = new TestToken(1000000 ether);
        token2 = new TestToken(1000000 ether);
        weth = new WETH9();
        factory = new UniswapV3Factory();
        router = new SwapRouter(address(factory), address(weth));
        tokenDescriptor = new TokenDescriptor();
        positionManager = new NonfungiblePositionManager(
            address(factory),
            address(weth),
            address(tokenDescriptor)
        );

        // SETUP
        weth.deposit{value: 10 ether}();
    }

    function test_setup() public {
        assert(token1.balanceOf(address(this)) == 1000000 ether);
        assert(token2.balanceOf(address(this)) == 1000000 ether);
        assert(weth.balanceOf(address(this)) == 10 ether);
    }
}
