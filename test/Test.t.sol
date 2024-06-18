// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract BaseTest is Test {
    NFTMarketplace public place;
    address public alice = makeAddr('Alice');
    address public bob = makeAddr('Bob');

    function setUp() public {
        place = new NFTMarketplace();
    }

    function test_updateListingPriceRevertNotOwner() public {
        vm.expectRevert("Only marketplace owner can update listing price.");
        vm.prank(alice);
        place.updateListingPrice(0.1 ether);
    }

    function test_updateListingPrice() public {
        assertEq(place.getListingPrice(), 0.025 ether);
        place.updateListingPrice(0.1 ether);
        assertEq(place.getListingPrice(), 0.1 ether);
    }

    function test_createTokenRevertZeroPrice() public {
        vm.expectRevert("Price must be at least 1 wei");
        vm.prank(alice);
        place.createToken("tokenURI", 0);
    }

    function test_createTokenRevertInvalidPayment(uint256 paying) public {
        vm.assume(place.getListingPrice() != paying);
        deal(alice, paying);
        vm.expectRevert("To create NFT, must pay as equal to listing price");
        vm.prank(alice);
        place.createToken{value: paying}("tokenURI", 1 ether);
    }

    function test_createToken() public {
        uint256 listingPrice = place.getListingPrice();
        deal(alice, listingPrice);
        vm.prank(alice);
        uint256 tokenId = place.createToken{value: listingPrice}("tokenURI", 1 ether);
        assertEq(tokenId, 1);
        assertEq(place.ownerOf(tokenId), address(place));
        NFTMarketplace.MarketItem memory item = place.getMarketItem(tokenId);
        assertEq(item.seller, alice);
        assertEq(item.owner, address(place));
        assertEq(item.price, 1 ether);
        assertEq(item.sold, false);

        NFTMarketplace.MarketItem[] memory items = place.fetchMarketItems();
        assertEq(items[0].seller, alice);
        assertEq(items[0].owner, address(place));
        assertEq(items[0].price, 1 ether);
        assertEq(items[0].sold, false);
    }

    function test_createMarketSaleRevertInvalidPrice(uint256 paying) public {
        vm.assume(paying < 1 ether);
        deal(bob, paying);
        uint256 tokenId = _createToken(1 ether);

        vm.expectRevert("Please submit the asking price in order to complete the purchase");
        vm.prank(bob);
        place.createMarketSale{value: paying}(tokenId);
    }

    function test_createMarketSale() public {
        deal(bob, 1 ether);
        uint256 tokenId = _createToken(1 ether);

        uint256 previousBal = address(this).balance;
        vm.prank(bob);
        place.createMarketSale{value: 1 ether}(tokenId);
        
        NFTMarketplace.MarketItem memory item = place.getMarketItem(tokenId);
        assertEq(place.ownerOf(tokenId), bob);
        assertEq(item.owner, bob);
        assertEq(item.seller, address(0));
        assertEq(item.sold, true);
        assertEq(address(this).balance, previousBal + place.getListingPrice());
        assertEq(alice.balance, 1 ether);

        vm.prank(bob);
        NFTMarketplace.MarketItem[] memory items = place.fetchMyNFTs();
        assertEq(items[0].owner, bob);
        assertEq(items[0].seller, address(0));
        assertEq(items[0].sold, true);
    }

    function test_resellTokenRevertInvalidOwner() public {
        uint256 tokenId = _createMarketSale(1 ether);

        vm.expectRevert("Only item owner can perform this operation");
        place.resellToken(tokenId, 0.5 ether);
    }

    function test_resellTokenRevertInvalidListingPrice(uint256 paying) public {
        vm.assume(paying < place.getListingPrice());
        uint256 tokenId = _createMarketSale(1 ether);

        deal(bob, place.getListingPrice());
        vm.expectRevert("Price must be equal to listing price");
        vm.prank(bob);
        place.resellToken{value: paying}(tokenId, 0.5 ether);
    }

    function test_resellToken() public {
        uint256 listingPrice = place.getListingPrice();
        uint256 tokenId = _createMarketSale(1 ether);

        deal(bob, listingPrice);
        vm.prank(bob);
        place.resellToken{value: listingPrice}(tokenId, 0.5 ether);
        NFTMarketplace.MarketItem memory item = place.getMarketItem(tokenId);
        assertEq(place.ownerOf(tokenId), address(place));
        assertEq(item.seller, bob);
        assertEq(item.price, 0.5 ether);
        assertEq(item.sold, false);

        vm.prank(bob);
        NFTMarketplace.MarketItem[] memory items = place.fetchItemsListed();
        assertEq(items[0].seller, bob);
        assertEq(items[0].price, 0.5 ether);
        assertEq(items[0].sold, false);
    }

    function _createToken(uint256 price) private returns(uint256 tokenId) {
        uint256 listingPrice = place.getListingPrice();
        deal(alice, listingPrice);
        vm.prank(alice);
        tokenId = place.createToken{value: listingPrice}("tokenURI", price);
    }

    function _createMarketSale(uint256 price) private returns(uint256 tokenId) {
        deal(bob, 1 ether);
        tokenId = _createToken(price);
        vm.prank(bob);
        place.createMarketSale{value: 1 ether}(tokenId);
    }

    fallback() external payable {}

    receive() external payable {}
}
