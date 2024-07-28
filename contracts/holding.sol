// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract HoldingNFT is IERC721Receiver {
    address public owner;
    mapping(address => address) private managers;
    address[] managersList;
    uint internal lotteryId;
    struct Winner {
        uint256 id;
        address winnerAddress;
        uint256 tokenId;
        address contractAddress;
        uint256 winningPosition;
    }
    Winner[] private winners;

    constructor() {
        owner = msg.sender;
    }

    // events
    event ClaimedNFT(
        address nftContractAddress,
        uint256 tokenId,
        uint256 lotteryId
    );
    event TransferOwnership(address _owner);
    event AddManager(address _manager);

    // modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier ownerOrManager() {
        require(
            msg.sender == managers[msg.sender] || msg.sender == owner,
            "You are not authorized!"
        );
        _;
    }

    modifier hasWinner(uint id, address _winner) {
        require(_winner != address(0), "The 0 address not allowed.");
        require(isIncludes(id, _winner), "This address is not winner");
        _;
    }

    // transfer ownership

    function transferOwnership(address recipient) public onlyOwner {
        owner = recipient;
        emit TransferOwnership(recipient);
    }

    function isManager(address _manager) public view returns (bool) {
        for (uint256 i = 0; i < managersList.length; i++) {
            if (managersList[i] == _manager) {
                return true;
            }
        }

        return false;
    }

    // add a manager
    function addManager(address _manager) public onlyOwner {
        require(isManager(_manager), "This address is already in manager");
        managers[_manager] = _manager;
        managersList.push(_manager);
        emit TransferOwnership(_manager);
    }

    // get manager
    function getManagers() public view returns (address[] memory) {
        return managersList;
    }

    // check if winner is includes on winners array
    function isIncludes(uint _id, address _winner) public view returns (bool) {
        for (uint256 i = 0; i < winners.length; i++) {
            if (winners[i].winnerAddress == _winner && winners[i].id == _id) {
                return true;
            }
        }
        return false;
    }

    // check if winner is includes on winners array  by token Id
    function indexOfWinnerArray(
        uint256 tokenId,
        address _contractAddress
    ) public view returns (uint256 index, bool found) {
        for (uint256 i = 0; i < winners.length; i++) {
            Winner memory _nft = winners[i];
            if (
                _nft.tokenId == tokenId &&
                _nft.contractAddress == _contractAddress
            ) {
                index = i;
                found = true;
            }
        }

        index = 0;
        found = false;
    }

    // find out a index of an element
    function indexOfWinnerByAddressId(
        uint _id,
        address _winner
    ) public view returns (uint256, bool) {
        for (uint256 i = 0; i < winners.length; i++) {
            if (winners[i].winnerAddress == _winner && winners[i].id == _id) {
                return (i, true);
            }
        }

        return (0, false);
    }

    // get winner by address
    function getWinnersByAddress(
        address _winner
    ) public view returns (Winner[] memory) {
        //  count the number of matching winners
        uint256 count = 0;
        for (uint256 i = 0; i < winners.length; i++) {
            if (winners[i].winnerAddress == _winner) {
                count++;
            }
        }

        Winner[] memory filteredWinner = new Winner[](count);
        // Populate the memory array with matching winners
        uint256 index = 0;
        for (uint256 i = 0; i < winners.length; i++) {
            if (winners[i].winnerAddress == _winner) {
                filteredWinner[index] = winners[i];
                index++;
            }
        }
        return filteredWinner;
    }

    function setWinnerAddress(
        uint id,
        address _winner,
        uint256 tokenId,
        address _nftContract,
        uint256 _position
    ) internal ownerOrManager {
        require(_winner != address(0), "The 0 address not allowed.");
        if (!isIncludes(id, _winner)) {
            winners.push(Winner(id, _winner, tokenId, _nftContract, _position));
        } else {
            (uint256 index, bool found) = indexOfWinnerByAddressId(id, _winner);
            if (found) {
                winners[index] = Winner(
                    id,
                    _winner,
                    tokenId,
                    _nftContract,
                    _position
                );
            }
        }
    }

    function deleteWinnerAddress(
        uint256 id,
        address _winner
    ) private hasWinner(id, _winner) {
        (uint256 index, bool find) = indexOfWinnerByAddressId(id, _winner);
        if (find) {
            winners[index] = winners[winners.length - 1];
            winners.pop();
        }
    }

    function getWinnerNftByIndex(
        uint256 _index
    ) public view returns (Winner memory) {
        return winners[_index];
    }

    function claimNFT(
        address _to,
        address _contractAddress,
        uint id
    ) external hasWinner(id, _to) {
        require(_to == msg.sender, "Spam Detected");
        (uint256 index, bool found) = indexOfWinnerByAddressId(id, _to);
        require(found, "Not found a winner");
        Winner memory token = winners[index];
        IERC721 _nftContract = IERC721(_contractAddress);
        uint256 tokenId = token.tokenId;
        _nftContract.safeTransferFrom(address(this), _to, tokenId);
        deleteWinnerAddress(id, _to);
        emit ClaimedNFT(_to, tokenId, id);
    }

    // function claimAllNFTs(address _to) external {
    //     require(_to == msg.sender, "Spam Detected");
    //     Winner[] memory winnerNft = getWinnersByAddress(_to);
    //     require(winnerNft.length > 0, "No winner found");

    //     for (uint256 i = 0; i < winnerNft.length; i++) {
    //         Winner memory token = winnerNft[i];
    //         IERC721 _nftContract = IERC721(token.contractAddress);
    //         _nftContract.safeTransferFrom(address(this), _to, token.tokenId);

    //         deleteWinnerAddress(token.id, _to);
    //         emit ClaimedNFT(_to, token.tokenId, token.id);
    //     }
    // }

    function tranferAnNftToOwner(
        uint256 _tokenId,
        address _contractAddress
    ) external onlyOwner {
        require(
            ownerOf(_tokenId, _contractAddress) == address(this),
            "The nft is not owned by Holding contract"
        );
        (uint256 index, bool found) = indexOfWinnerArray(
            _tokenId,
            _contractAddress
        );
        require(!found, "The nft is distributed for a winner.");
        Winner memory token = winners[index];

        IERC721 _nftContract = IERC721(token.contractAddress);
        _nftContract.safeTransferFrom(address(this), msg.sender, token.tokenId);
    }

    // transfer a nft from this contract to owner walllet

    function claimToOwner(
        uint _id,
        uint256 tokenId,
        address _contractAddress
    ) external onlyOwner {
        require(
            ownerOf(tokenId, _contractAddress) == address(this),
            "The nft is not owned by Holding contract"
        );

        IERC721 _nftContract = IERC721(_contractAddress);
        _nftContract.safeTransferFrom(address(this), owner, tokenId);

        (uint256 index, bool found) = indexOfWinnerArray(
            tokenId,
            _contractAddress
        );

        if (found) {
            deleteWinnerAddress(_id, winners[index].winnerAddress);
        }
    }

    // is an nft contains by this contract
    function isContainNFT(
        uint256 _tokenId,
        address _contractAddress
    ) internal view returns (bool) {
        IERC721 _nftContract = IERC721(_contractAddress);
        address ownerNft = _nftContract.ownerOf(_tokenId);
        if (ownerNft == address(this)) {
            return true;
        }
        return false;
    }

    function ownerOf(
        uint256 _tokenId,
        address _contractAddress
    ) public view returns (address) {
        require(_contractAddress != address(0), "0 address not allowed");
        IERC721 _nftContract = IERC721(_contractAddress);
        return _nftContract.ownerOf(_tokenId);
    }

    function getWinnersInfo() public view returns (Winner[] memory) {
        return winners;
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send nfts to Vault directly");
        return IERC721Receiver.onERC721Received.selector;
    }
}
