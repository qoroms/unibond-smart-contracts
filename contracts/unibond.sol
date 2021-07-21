pragma solidity ^0.6.3;

import "./Ownable.sol";
import "./interface/IERC20.sol";
import "./interface/IERC721.sol";
import "./interface/IERC1155.sol";
import "./interface/IERC1155Metadata.sol";
import "./library/SafeMath.sol";
import "./library/Address.sol";

contract Unibond is Ownable {
    using SafeMath for uint256;
    using Address for address;

    struct SwapCollection {
        uint256 swapId, // swap id
        uint256 tokenId, // UniV3 NFT id
        address lister, // address of swap creator
        address payToken, // address of pay token
        address amount, // token/ETH amount,
        uint8 assetType, // 0 : erc20 token, 1 : ETH
    }

    uint256 public listIndex;
    mapping(uint256 => SwapCollection) public swapList; // SwapList Stae

    constructor() public {
        listIndex = 0;
    }


}
