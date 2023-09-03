// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "./TWCustomerCollection.sol";

contract Trustworthy is ERC1155Receiver, Ownable {
    address public serviceAddress;

    struct TokenContract {
        address contractAddress;
    }

    mapping(address => TokenContract) public tokenContracts;
    mapping(address => address) public tokenOwners;
    mapping(address => mapping(uint256 => uint256)) public tokenPrices;

    event TokenPurchased(
        address indexed buyer,
        address indexed tokenContract,
        uint256 tokenId,
        uint256 amount
    );
    event CollectionCreated(address indexed service, address indexed collection);

    constructor(address _serviceAddress) {
        serviceAddress = _serviceAddress;
    }

    /**
    * @dev Allows a user to purchase ERC1155 tokens from a registered token contract.
    * @param _tokenContract The address of the token contract from which to purchase tokens.
    * @param _tokenId The ID of the token to purchase.
    * @param _amount The amount of tokens to purchase.
    * @notice This function requires the sender to send Ether to purchase tokens.
    */
    function buyTokens(
        address _tokenContract,
        uint256 _tokenId,
        uint256 _amount
    ) external payable {
        require(msg.value > 0, "You must send ether to purchase tokens");

        TokenContract storage contractInfo = tokenContracts[_tokenContract];
        require(
            contractInfo.contractAddress != address(0),
            "Token contract not registered"
        );

        address tokenOwner = tokenOwners[_tokenContract];
        require(tokenOwner != address(0), "Token does not exist");

        uint256 tokenPrice = tokenPrices[_tokenContract][_tokenId];
        require(tokenPrice > 0, "Token price not set");

        // Calculate the total cost
        uint256 totalCost = tokenPrice * _amount;

        require(msg.value >= totalCost, "Insufficient funds to purchase tokens");

        // Split the payment
        uint256 sellerPayment = (totalCost * 90) / 100;
        uint256 contractPayment = totalCost - sellerPayment;

        // Transfer funds to the seller
        payable(tokenOwner).transfer(sellerPayment);

        // Transfer funds to the contract owner
        payable(owner()).transfer(contractPayment);

        // Transfer ERC1155 tokens to the buyer
        IERC1155(_tokenContract).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _amount,
            ""
        );

        emit TokenPurchased(msg.sender, _tokenContract, _tokenId, _amount);
    }

    /**
    * @dev Creates a new ERC1155 collection with the specified parameters and adds it to the authorized contracts.
    * @param _name The name of the ERC1155 collection.
    * @param _uri The URI for metadata associated with the collection.
    * @param _tokenIds An array of token IDs.
    * @param _initialAmounts An array of initial token amounts corresponding to each token ID.
    * @param _prices An array of prices to be assigned to each provided token ID.
    * @notice This function can only be called by the authorized service address.
    */
    function createERC1155Collection(
        string memory _name,
        string memory _uri,
        uint256[] memory _tokenIds,
        uint256[] memory _initialAmounts,
        uint256[] memory _prices,
        address _owner
    ) public onlyService {
        TWCustomerCollection newCollection = new TWCustomerCollection(
            _name,
            _uri,
            _tokenIds,
            _initialAmounts
        );
        addTokenContract()(address(newCollection));
        newCollection.mintInitTokens();
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            setTokenPrice(address(newCollection), _tokenIds[i], _prices[i]);
        }
        setCollectionOwner(_owner, address(newCollection));
        emit CollectionCreated(serviceAddress, address(newCollection));
    }

    /**
    * @dev Sets the service address, allowing it to perform specific actions restricted to the service.
    * @param _serviceAddress The new address designated as the service address.
    * @notice Only the contract owner can call this function to update the service address.
    */
    function setServiceAddress(address _serviceAddress) public onlyOwner {
        serviceAddress = _serviceAddress;
    }

    /**
    * @dev Adds a new token contract to the list of authorized contracts.
    * @param _contractAddress The address of the token contract to be added.
    * @notice Only the contract owner can perform this action.
    */
    function addTokenContract(address _contractAddress) private {
        tokenContracts[_contractAddress] = TokenContract({
            contractAddress: _contractAddress
        });
    }

    /**
    * @dev Set the price for a specific token ID.
    * @param _tokenId The token ID for which to set the price.
    * @param _price The price to set for the token.
    */
    function setTokenPrice(address _collectionAddress, uint256 _tokenId, uint256 _price) private {
        tokenPrices[_collectionAddress][_tokenId] = _price;
    }

    /**
    * @dev Get the price for a specific token ID.
    * @param _tokenId The token ID for which to get the price.
    * @return The price of the token.
    */
    function getTokenPrice(address _collectionAddress, uint256 _tokenId) public view returns (uint256) {
        return tokenPrices[_collectionAddress][_tokenId];
    }

    /**
    * @dev Internal function to set the owner of a specific collection.
    * @param _owner The address of the owner to be set.
    * @param _collection The address of the ERC1155 collection to be associated with the owner.
    * @notice This function is used to record the owner of a specific ERC1155 collection within the contract.
    *         It defines the address to which the reward will be sent.
    */
    function setCollectionOwner(address _owner, address _collection) private {
        tokenOwners[_collection] = _owner;
    }

    /**
    * @dev Modifier that restricts access to functions to only the designated service address.
    * @notice Only transactions initiated by the service address are allowed to proceed.
    */
    modifier onlyService() {
        require(msg.sender == serviceAddress, "Only the service can call this function");
        _;
    }

    // ERC1155Receiver functions
    function onERC1155Received(
        address operator,
        address from,
        uint256 tokenId,
        uint256 value,
        bytes memory data
    ) external override returns (bytes4) {
        require(
            tokenContracts[msg.sender].contractAddress == msg.sender,
            "Invalid token contract"
        );

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) external override returns (bytes4) {
        require(
            tokenContracts[msg.sender].contractAddress == msg.sender,
            "Invalid token contract"
        );

        return this.onERC1155BatchReceived.selector;
    }
}
