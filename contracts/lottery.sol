// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;
import "./holding.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Lottery is HoldingNFT {
    address[] public players; //Array of players who bought tickets
    address[] public playerSelector; //Array of players for random selection
    bool public status = false;
    uint256 public ticketPrice; // entry  ticket price in wie
    struct NFTs {
        address contractAddress;
        uint256 tokenId;
        uint256 winningPosition;
    }
    NFTs[] private stagedNfts;
    mapping(address => uint256) public playersEntryCount;
    uint256 public totalEntries; //Total number of entries
    uint256 public _MaxPerPlayerEntryCount = 1; // meximum times a player can buy a ticket;
    uint256 public maxWinner = 1;
    enum Transferred {
        Notset,
        Pending,
        Done
    }
    Transferred private isTransferred = Transferred.Notset;

    // constructor
    constructor(uint256 _ticketPrice) HoldingNFT() {
        ticketPrice = _ticketPrice;
    }

    // events
    event NewTicketBought(address player); //Event when someone buys a ticket
    event LotteryStarted();
    event LotteryEnded();
    //Event when someone wins the lottery
    event TokenDistributed(uint _id);
    event TicketCostChanged(uint256 newCost); //Event when the ticket cost is updated
    event StagedNFTs(NFTs[] prizes);
    event BalanceWithdrawn(uint256 amount);
    event MaxPerPlayerEntryCount(uint256);
    event TicketPrice(uint256 price);
    event TotalWinner(uint256 total);
    // modifiers

    modifier isLotteryStart() {
        require(status, "Lottery is not running");
        _;
    }

    // set ticket price
    function setTicketPrice(uint256 price) public onlyOwner {
        require(
            !status,
            "Cannot update ticket price While lottery is running."
        );
        ticketPrice = price;
        emit TicketPrice(price);
    }

    function setTotalWinner(uint256 total) public ownerOrManager {
        require(
            !status,
            "Cannot update Total winner While lottery is running."
        );
        maxWinner = total;
        emit TotalWinner(total);
    }

    function setStageNfts(NFTs[] memory nfts) public ownerOrManager {
        require(!status, "Cannot update Stage NFTs While lottery is running.");
        require(
            nfts.length == maxWinner,
            "Total winner and  Staged NFTs length should be same"
        );

        if (stagedNfts.length > 0) {
            delete stagedNfts;
        }

        for (uint256 i = 0; i < nfts.length; i++) {
            require(
                isContainNFT(nfts[i].tokenId, nfts[i].contractAddress),
                "Holding contract does not own a NFT or some NFTs."
            );
            stagedNfts.push(nfts[i]);
        }

        emit StagedNFTs(stagedNfts);
    }

    function getStagedNfts() public view returns (NFTs[] memory) {
        return stagedNfts;
    }

    // lottery start
    /*
     *If a lottery already started then new lottery cannot start before distributing winner prize for existed lottery
     */
    function startLottery() public ownerOrManager {
        require(!status, "Lottery already started");
        require(stagedNfts.length > 0, "Stage NFTs not added");
        require(
            Transferred.Pending != isTransferred,
            "Prize from previous lottery not transferred"
        );
        status = true;
        lotteryId = block.timestamp;
        emit LotteryStarted();
    }

    /*
     *End A lottery
     */
    function endLottery() public ownerOrManager {
        require(status, "Lottery already ended");
        status = false;
        isTransferred = Transferred.Pending;
        emit LotteryStarted();
    }

    /*
     * Set a maxium quantity of ticket can buy a wallet
     */

    function setMaxPerPlayerEntryCount(uint256 count) public ownerOrManager {
        require(
            !status,
            "Cannot update MaxPerPlayerCount While lottery is running."
        );
        require(count > 0, "Max Per Player Entry Count at least 1");
        _MaxPerPlayerEntryCount = count;
        emit MaxPerPlayerEntryCount(count);
    }

    function updateLotteryInfo(
        uint256 pricePerTicket,
        uint256 _maxWinner,
        uint256 maxTicketPerWallet
    ) public ownerOrManager {
        require(
            !status,
            "Cannot update Lottery Info While lottery is running."
        );
        ticketPrice = pricePerTicket;
        maxWinner = _maxWinner;
        _MaxPerPlayerEntryCount = maxTicketPerWallet;
    }

    // is players
    function isPlayer(address participant) private view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == participant) {
                return true;
            }
        }
        return false;
    }

    // ticket buying
    function buyTicket(uint256 numberOfTickets) public payable isLotteryStart {
        require(
            msg.value == ticketPrice * numberOfTickets,
            "Ticket cost is not correct"
        );
        uint256 prevCount = playersEntryCount[msg.sender];

        require(
            _MaxPerPlayerEntryCount > prevCount &&
                _MaxPerPlayerEntryCount >= numberOfTickets,
            "A player cannot purchase more than maximum allowed ticket"
        );

        // Increment the count of entries for the participant
        playersEntryCount[msg.sender] += numberOfTickets;
        totalEntries += numberOfTickets;

        if (!isPlayer(msg.sender)) {
            players.push(msg.sender);
        }

        for (uint256 i = 0; i < numberOfTickets; i++) {
            playerSelector.push(msg.sender); //Add the player to the playerSelector array
        }

        emit NewTicketBought(msg.sender); //Emit the event that a new ticket was bought
    }

    function resetPlayersEntryCount() private {
        for (uint256 i = 0; i < players.length; i++) {
            playersEntryCount[players[i]] = 0;
        }
    }

    // token id by winner position
    function tokenByWinningPosition(
        uint256 _position
    ) public view returns (uint256, address, bool) {
        for (uint256 i = 0; i < stagedNfts.length; i++) {
            if (stagedNfts[i].winningPosition == _position) {
                return (
                    stagedNfts[i].tokenId,
                    stagedNfts[i].contractAddress,
                    true
                );
            }
        }

        return (0, address(0), false);
    }

    // pick winners
    function getWinners(
        uint256[] memory winnerIndices
    ) public view returns (Winner[] memory) {
        require(!status, "Lottery is still running"); //Lottery must not be running
        require(
            winnerIndices.length > 0,
            "WinnerIndices length could not be zero."
        );

        Winner[] memory winnerArray = new Winner[](winnerIndices.length);

        for (uint256 i = 0; i < winnerIndices.length; i++) {
            address winner = players[i];
            uint256 positon = i + 1;
            (
                uint256 tokenId,
                address contractAddress,

            ) = tokenByWinningPosition(positon);

            winnerArray[i] = Winner(
                lotteryId,
                winner,
                tokenId,
                contractAddress,
                positon
            );
        }

        return winnerArray;
    }

    // distribute winners

    function distribute(Winner[] memory _winners) public ownerOrManager {
        require(!status, "Lottery is still running"); //Lottery must not be running
        require(_winners.length > 0, "Winner array length should not be zero.");

        for (uint256 i = 0; i < _winners.length; i++) {
            setWinnerAddress(
                _winners[i].id,
                _winners[i].winnerAddress,
                _winners[i].tokenId,
                _winners[i].contractAddress,
                _winners[i].winningPosition
            );
        }
        isTransferred = Transferred.Done;
        emit TokenDistributed(lotteryId);
        resetPlayersEntryCount();
        delete playerSelector;
        delete players;
        status = false;
        totalEntries = 0;
        delete stagedNfts;
    }

    // get functions

    function getPlayers() public view returns (address[] memory) {
        return players;
    }

    function getPlayerEntryCount(address player) public view returns (uint256) {
        return playersEntryCount[player];
    }

    function getPlayerSelector() public view returns (address[] memory) {
        return playerSelector;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance; //Return the contract balance
    }

    //get winner indices

    function withdrawBalance() public onlyOwner {
        require(address(this).balance > 0, "No balance to withdraw.");
        uint256 amount = address(this).balance;
        payable(owner).transfer(amount);
        emit BalanceWithdrawn(amount);
    }

    function getLotteryId() public view returns (uint) {
        return lotteryId;
    }

    //Master reset function to reset the contract
    function resetContract() public ownerOrManager {
        delete playerSelector;
        delete players;
        status = false;
        ticketPrice = 0;
        totalEntries = 0;
        resetPlayersEntryCount();
        _MaxPerPlayerEntryCount = 1;
        delete stagedNfts;
        delete lotteryId;
        isTransferred = Transferred.Notset;
    }
}
