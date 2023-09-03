// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TWCustomerCollection is ERC1155, Ownable {
    string public name;
    string public uri;
    uint256[] public tokenIds;
    uint256[] public initialAmounts;

    constructor(
        string memory _name,
        string memory _uri,
        uint256[] memory _tokenIds,
        uint256[] memory _initialAmounts
    ) ERC1155(_uri) {
        name = _name;
        uri = _uri;
        tokenIds = _tokenIds;
        initialAmounts = _initialAmounts;
    }

    function mintInitTokens() external onlyOwner {
        // Mint initial tokens and set max amounts
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _mint(msg.sender, tokenIds[i], initialAmounts[i], "");
        }
    }
}
