// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Marketplace is Ownable, ReentrancyGuard {
    IERC20 public RDXXToken;
    uint256 public feePercent = 125;  
    address public fouders;

    struct Item {
        address seller;
        uint256 price;
    }

    mapping(string => Item) public items;

    event ItemListed(address indexed seller, string uuid, uint256 price);
    event ItemRemoved(address indexed seller, string uuid);
    event NftSold(address indexed buyer, string uuid, address indexed seller, uint256 price);
    event ItemPriceSet(address indexed seller, string uuid, uint256 price);

    constructor(address _RDXXTokenAddress, address _founders, address _initialOwner) Ownable (_initialOwner) ReentrancyGuard() {
        RDXXToken = IERC20(_RDXXTokenAddress);
        fouders = _founders;
    }

    function listItem(string memory _uuid, uint256 _price) public nonReentrant {
        require(items[_uuid].seller == address(0), "Item already listed");
        require(_price > 0, "Price must be greater than 1");
        items[_uuid] = Item(msg.sender, _price);
        emit ItemListed(msg.sender, _uuid, _price);
    }

    function setListItem(string memory _uuid, uint256 _price) public nonReentrant {
        require(items[_uuid].seller != address(0), "Item not listed");
        require(msg.sender == items[_uuid].seller, "Only the owner can set the item price");
        require(_price > 0, "Price must be greater than 1");

        items[_uuid].price = _price;

        emit ItemPriceSet(msg.sender, _uuid, _price);
    }

    function removeItem(string memory _uuid) public nonReentrant {
        require(items[_uuid].seller == msg.sender, "Not the seller");

        delete items[_uuid];
        emit ItemRemoved(msg.sender, _uuid);
    }

    function buyItem(string memory _uuid) public nonReentrant {
        Item memory item = items[_uuid];
        require(item.seller != address(0), "Item not listed");
        require(item.seller != msg.sender, "Seller cannot buy their own item");

        uint256 feeAmount = item.price * feePercent / 1000;
        uint256 sellerAmount = item.price - feeAmount;

        uint256 buyerBalance = RDXXToken.balanceOf(msg.sender);
        require(buyerBalance >= item.price, "Insufficient balance to buy item");

        require(RDXXToken.transferFrom(msg.sender, fouders, feeAmount), "Fee transfer failed");
        require(RDXXToken.transferFrom(msg.sender, item.seller, sellerAmount), "Payment to seller failed");

        delete items[_uuid];
        emit NftSold(msg.sender, _uuid, item.seller, item.price);
    }

    function setFeePercent(uint256 _newFee) public onlyOwner {
        feePercent = _newFee;
    }

    function setFounders(address _newFounders) public onlyOwner {
        fouders = _newFounders;
    }
}
