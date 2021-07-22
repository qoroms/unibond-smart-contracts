pragma solidity ^0.6.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Unibond is Ownable, IERC721Receiver {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    struct SwapCollection {
        uint256 swapId; // swap id
        uint256 tokenId; // UniV3 NFT id
        address creator; // address of swap creator
        address payToken; // address of pay token
        uint256 amount; // token/ETH amount,
        uint8 assetType; // 0 : erc20 token, 1 : ETH
        bool isOpen; // true: open to swap, false: closed
    }

    address public constant UNIV3_NFT_POISTION_MANAGER =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    uint256 public listIndex;
    mapping(uint256 => SwapCollection) public swapList; // SwapList Stae

    bool public emergencyStop;

    event SwapCreated(
        uint256 swapId,
        uint256 tokenId,
        address payable creator,
        address payToken,
        uint256 amount,
        uint8 assetType
    );
    event SwapCompleted(uint256 swapId);
    event SwapClosed(uint256 swapId);

    modifier onlyNotEmergency() {
        require(emergencyStop == false, "Unibond: emergency stop");
        _;
    }

    modifier onlyListOwner(uint256 _swapId) {
        require(
            swapList[_swapId].creator == msg.sender,
            "Unibond: not your list"
        );
        _;
    }

    constructor() public {
        listIndex = 0;
        emergencyStop = false;
    }

    // @dev enable swap
    function clearEmergency() external onlyOwner {
        emergencyStop = false;
    }

    // @dev disable swap
    function stopEmergency() external onlyOwner {
        emergencyStop = true;
    }

    function createSwap(
        uint256 _tokenId,
        address _payToken,
        uint256 _amount,
        uint8 _assetType
    ) external onlyNotEmergency {
        IERC721 _posManager = IERC721(UNIV3_NFT_POISTION_MANAGER);
        require(
            _posManager.ownerOf(_tokenId) == msg.sender,
            "Unibond: seller have no asset"
        );
        require(
            _posManager.isApprovedForAll(msg.sender, address(this)) == true,
            "Unibond: Asset is not approved for create"
        );

        _posManager.safeTransferFrom(msg.sender, address(this), _tokenId, "");

        uint256 _id = listIndex;
        swapList[_id].swapId = _id;
        swapList[_id].tokenId = _tokenId;
        swapList[_id].creator = msg.sender;
        swapList[_id].payToken = _payToken;
        swapList[_id].amount = _amount;
        swapList[_id].assetType = _assetType;
        swapList[_id].isOpen = true;

        _incrementListId();

        emit SwapCreated(
            _id,
            _tokenId,
            msg.sender,
            _payToken,
            _amount,
            _assetType
        );
    }

    function swapWithToken(uint256 _swapId) external onlyNotEmergency {
        IERC721 _posManager = IERC721(UNIV3_NFT_POISTION_MANAGER);
        SwapCollection storage _list = swapList[_swapId];
        require(_list.assetType == 0, "Unibond: You should swap with ETH");
        require(
            IERC20(_list.payToken).balanceOf(msg.sender) >= _list.amount,
            "Unibond: Not enough balance"
        );
        IERC20(_list.payToken).safeTransferFrom(
            msg.sender,
            _list.creator,
            _list.amount
        );
        _posManager.safeTransferFrom(
            address(this),
            msg.sender,
            _list.tokenId,
            ""
        );
        _list.isOpen = false;

        emit SwapCompleted(_swapId);
    }

    function swapWithETH(uint256 _swapId) external payable onlyNotEmergency {
        IERC721 _posManager = IERC721(UNIV3_NFT_POISTION_MANAGER);
        SwapCollection storage _list = swapList[_swapId];
        require(_list.assetType == 1, "Unibond: You should swap with token");
        require(msg.value >= _list.amount, "Unibond: Not enough balance");
        _list.creator.transfer(msg.value);
        _posManager.safeTransferFrom(
            address(this),
            msg.sender,
            _list.tokenId,
            ""
        );
        _list.isOpen = false;

        emit SwapCompleted(_swapId);
    }

    function closeSwap(uint256 _swapId) external onlyListOwner(_swapId) {
        IERC721 _posManager = IERC721(UNIV3_NFT_POISTION_MANAGER);
        SwapCollection storage _list = swapList[_swapId];
        require(_list.isOpen == true, "Unibond: swap is already closed");
        _posManager.safeTransferFrom(
            address(this),
            _list.creator,
            _list.tokenId,
            ""
        );
        _list.isOpen = false;
        emit SwapClosed(_swapId);
    }

    function _incrementListId() internal {
        listIndex = listIndex.add(1);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
