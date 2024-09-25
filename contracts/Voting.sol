// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Voting is ReentrancyGuard {
    // State variables
    address payable public contractOwner;
    uint256 private freeTokens = 2;
    uint256 public tokenPrice;
    uint256 public proposalFee;
    uint256 public proposalId;
    uint256 public constant QUORUM = 5;
   
    constructor() {
        contractOwner = payable(msg.sender);
        tokenPrice = 0.01 ether;
        proposalFee = 0.1 ether;
        proposalId = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "You are not the owner");
        _;
    }

    // Main proposal structure for DAO
    struct Proposal {
        address proposalOwner;
        string description;
        uint256 votingPeriod;
        uint256 votesInFavor;
        uint256 votesAgainst;
        uint256 noOfVoters;
        bool isApproved;
        bool isFinalized;
    }

    // Mappings
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public tokens;
    mapping(address => bool) private hasClaimedFreeTokens;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // Events
    event FreeTokensClaimed(address indexed user, uint256 amount);
    event TokensPurchased(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposalOwner, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool inFavor);
    event ProposalFinalized(uint256 indexed proposalId, bool isApproved);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event FreeTokensUpdated(uint256 newAmount);
    event TokenPriceUpdated(uint256 newPrice);
    event ProposalFeeUpdated(uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ProposalRemoved(uint256 indexed proposalId);

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    //------------------------------User functions---------------------------------------------------------//

    function claimFreeTokens() public nonReentrant {
        require(!hasClaimedFreeTokens[msg.sender], "You have already claimed your free tokens");

        tokens[msg.sender] += freeTokens;
        hasClaimedFreeTokens[msg.sender] = true;
        emit FreeTokensClaimed(msg.sender, freeTokens);
    }

    function buyTokens() public payable nonReentrant {
        require(msg.value >= tokenPrice, "Please send a proper amount");
        
        uint256 addTokens = msg.value / tokenPrice;
        //Return the excess amount...
        uint256 excess = msg.value % tokenPrice;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
        tokens[msg.sender] += addTokens;
        emit TokensPurchased(msg.sender, addTokens);
    }

    function checkTokens() public view returns (uint256) {
        return tokens[msg.sender];
    }

    function createProposal(string memory _description, uint256 _votingPeriod) public payable nonReentrant {
        require(msg.value == proposalFee, "Please send proper proposal fee!");
        uint256 votingPeriodEnd = block.timestamp + (_votingPeriod * 1 days);
        proposals[proposalId] = Proposal(
            msg.sender,
            _description,
            votingPeriodEnd,
            0,
            0,
            0,
            false,
            false
        );
        emit ProposalCreated(proposalId, msg.sender, _description);
        proposalId++;
    }

    function vote(uint256 _proposalId, bool voteInFavor) public nonReentrant {
        Proposal storage proposal = proposals[_proposalId];

        require(_proposalId < proposalId, "Invalid proposal");
        require(block.timestamp < proposal.votingPeriod, "Voting period has ended");
        require(tokens[msg.sender] >= 1, "You don't have any tokens to vote");
        require(!hasVoted[_proposalId][msg.sender], "You have already voted for this proposal");
        
        if (voteInFavor) {
            proposal.votesInFavor++;
        } else {
            proposal.votesAgainst++;
        }
        proposal.noOfVoters++;
        hasVoted[_proposalId][msg.sender] = true;
        tokens[msg.sender]--;
        
        emit Voted(_proposalId, msg.sender, voteInFavor);
    }

    function finalizeProposal(uint256 _proposalId) public {
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp >= proposal.votingPeriod, "The voting period is not over");
        require(!proposal.isFinalized, "This proposal has already been finalised");
        
        //Quorum check
        if (proposal.noOfVoters < QUORUM){
            proposal.isApproved = false;
            proposal.isFinalized = true;
            emit ProposalFinalized(_proposalId, false);
        }
        else{
        proposal.isApproved = proposal.votesInFavor > proposal.votesAgainst;
        proposal.isFinalized = true;
        emit ProposalFinalized(_proposalId, proposal.isApproved);
        }
    }

    //----------------------------------Admin functions----------------------------------------------------//

    function withdrawAllFunds() public onlyOwner nonReentrant {
        require(address(this).balance > 0, "No amount to withdraw!");
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
        emit FundsWithdrawn(contractOwner, amount);
    }

    function updateFreeTokens(uint256 _newToken) public onlyOwner {
        freeTokens = _newToken;
        emit FreeTokensUpdated(_newToken);
    }

    function updateTokenPrice(uint256 _newPrice) public onlyOwner {
        tokenPrice = _newPrice;
        emit TokenPriceUpdated(_newPrice);
    }

    function updateProposalFee(uint256 _newFee) public onlyOwner {
        proposalFee = _newFee;
        emit ProposalFeeUpdated(_newFee);
    }

    function transferOwnership(address payable _newOwner) public onlyOwner {
        require(_newOwner != address(0), "New owner is the zero address");
        address oldOwner = contractOwner;
        contractOwner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }

    function removeProposal(uint256 _proposalId) public onlyOwner {
        Proposal storage proposalToRemove = proposals[_proposalId];
        require(_proposalId < proposalId, "Invalid proposal Id");
        require(!proposalToRemove.isFinalized, "Cannot remove finalized proposal");
        require(proposalToRemove.noOfVoters == 0, "Cannot remove proposal with voters");

        payable(proposalToRemove.proposalOwner).transfer(proposalFee);
    
        delete proposals[_proposalId];
        emit ProposalRemoved(_proposalId);
    }
}