// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract BaseTest is Test {
    NFTMarketplace public place;

    function setUp() public {
        place = new NFTMarketplace();
    }
}
