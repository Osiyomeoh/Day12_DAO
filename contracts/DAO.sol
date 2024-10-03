// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAO {
    IERC20 public governanceToken;
    uint256 public proposalCount;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        address targetContract;
        bytes callData;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public constant VOTING_PERIOD = 3 days;

    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event Voted(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    constructor(IERC20 _governanceToken) {
        governanceToken = _governanceToken;
    }

    // function createProposal(string memory description, address _targetContract, bytes memory _callData) 
    //     external 
    //     onlyTokenHolder 
    //     returns (uint256) 
    // {
    //     require(_targetContract != address(0), "Invalid target contract");
    //     require(_callData.length > 0, "Empty call data");
        
    //     proposalCount++;
    //     uint256 newProposalId = proposalCount;

    //     proposals[newProposalId] = Proposal({
    //         id: newProposalId,
    //         proposer: msg.sender,
    //         description: description,
    //         forVotes: 0,
    //         againstVotes: 0,
    //         startTime: block.timestamp,
    //         endTime: block.timestamp + VOTING_PERIOD,
    //         executed: false,
    //         targetContract: _targetContract,
    //         callData: _callData
    //     });

    //     emit ProposalCreated(newProposalId, msg.sender, description);
    //     return newProposalId;
    // }

    // function vote(uint256 proposalId, bool support) external {
    //     Proposal storage proposal = proposals[proposalId];
    //     require(block.timestamp <= proposal.endTime, "Voting period has ended");
    //     require(!hasVoted[proposalId][msg.sender], "Already voted on this proposal");

    //     uint256 votingPower = governanceToken.balanceOf(msg.sender);
    //     require(votingPower > 0, "Must hold governance tokens to vote");

    //     if (support) {
    //         proposal.forVotes += votingPower;
    //     } else {
    //         proposal.againstVotes += votingPower;
    //     }

    //     hasVoted[proposalId][msg.sender] = true;

    //     emit Voted(proposalId, msg.sender, support, votingPower);
    // }

    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.executed == false, "Proposal already executed");
        require(block.timestamp >= proposal.endTime, "Voting period not ended");
        require(proposal.forVotes > proposal.againstVotes, "Proposal did not pass");

        // ... (other checks)

        proposal.executed = true;
        
        // This is likely where the execution is failing
        (bool success, ) = proposal.targetContract.call(proposal.callData);
        require(success, "Proposal execution failed");

        emit ProposalExecuted(proposalId);
    }

    // New functions

    function getProposal(uint256 proposalId) public view returns (Proposal memory) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        return proposals[proposalId];
    }

    function getVotingPower(address account) public view returns (uint256) {
        return governanceToken.balanceOf(account);
    }

    // Additional access control
    modifier onlyTokenHolder() {
        require(governanceToken.balanceOf(msg.sender) > 0, "Must hold governance tokens");
        _;
    }

    // Safety check for proposal creation
    function createProposal(string memory description, address _targetContract, bytes memory _callData) 
        external 
        onlyTokenHolder 
        returns (uint256) 
    {
        require(_targetContract != address(0), "Invalid target contract");
        require(_callData.length > 0, "Empty call data");
        
        proposalCount++;
        uint256 newProposalId = proposalCount;

        proposals[newProposalId] = Proposal({
            id: newProposalId,
            proposer: msg.sender,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            executed: false,
            targetContract: _targetContract,
            callData: _callData
        });

        emit ProposalCreated(newProposalId, msg.sender, description);
        return newProposalId;
    }

    // Safety check for voting
    function vote(uint256 proposalId, bool support) external onlyTokenHolder {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted on this proposal");

        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        require(votingPower > 0, "Must hold governance tokens to vote");

        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }

        hasVoted[proposalId][msg.sender] = true;

        emit Voted(proposalId, msg.sender, support, votingPower);
    }

    // New state variable for quorum
    uint256 public quorum;

    // Function to set quorum (only callable by the DAO itself through a proposal)
    function setQuorum(uint256 newQuorum) external {
        require(msg.sender == address(this), "Only DAO can set quorum");
        quorum = newQuorum;
    }

}
