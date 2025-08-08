// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Proposal} from "./Proposal.sol";
import {IHFTtoken} from "./interfaces/IHFTtoken.sol";

contract Governer {
    event ProposalCreated(address indexed proposalAddress, uint256 indexed proposalId);
    event bidPlacedSuccessfully(address indexed bidderAddress, uint256 indexed proposalId);

    enum ROLE {
        MANAGER,
        DAO_MEMBER
    }

    struct UpdateProposal {
        uint256 updateProposalId;
        string proposalTitle;
        uint256 totalAgreements;
        bool isUpdateProposalCompleted;
    }

    struct DAOMember {
        address member;
        ROLE role;
    }

    struct Proposal_type {
        uint256 proposalId;
        address proposalAddress;
    }

    Proposal_type[] public s_proposals;

    uint256 public proposalCount;

    DAOMember[] public s_daoMembers;
    address public tresureAddress;
    uint256 private PLATFORM_FEE;
    address public PLATFORM_TOKEN;
    uint256 public BID_FEE;

    UpdateProposal[] private upgradeProposals;

    constructor(
        DAOMember[] memory _daoMembers,
        uint256 _platformFee,
        address _tresureAddress,
        address _platformTokenAddress,
        uint256 _bidFee
    ) {
        for (uint256 i = 0; i < _daoMembers.length; i++) {
            s_daoMembers.push(_daoMembers[i]);
        }
        s_daoMembers.push(DAOMember(msg.sender, ROLE.MANAGER));
        PLATFORM_FEE = _platformFee;
        tresureAddress = _tresureAddress;
        PLATFORM_TOKEN = _platformTokenAddress;
        BID_FEE = _bidFee;
    }

    function add_DaoMember(DAOMember memory _daoMember) public {
        s_daoMembers.push(_daoMember);
    }

    function remove_DaoMember(uint256 _index) public {
        s_daoMembers[_index] = s_daoMembers[s_daoMembers.length];
        s_daoMembers.pop();
    }

    function createProposal(uint256 _deadline, uint256 _budget) public {
        Proposal newProposal = new Proposal(proposalCount, msg.sender, _deadline, _budget, tresureAddress);
        s_proposals.push(Proposal_type(proposalCount, address(newProposal)));
        emit ProposalCreated(address(newProposal), proposalCount);
        proposalCount++;
    }

    function getAllProposals() public view returns (Proposal_type[] memory) {
        return s_proposals;
    }

    // Getter for single proposal
    function getProposal(uint256 proposalId) public view returns (Proposal_type memory) {
        require(proposalId < s_proposals.length, "Invalid proposal ID");
        return s_proposals[proposalId];
    }

    // function setBidFee(uint256 _newBidFee) public onlyOwner {

    // }

    // Getter for paginated results
    function getProposals(uint256 offset, uint256 limit) public view returns (Proposal_type[] memory) {
        uint256 end = offset + limit;
        if (end > s_proposals.length) {
            end = s_proposals.length;
        }
        if (end < offset) {
            return new Proposal_type[](0);
        }

        Proposal_type[] memory result = new Proposal_type[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = s_proposals[i];
        }
        return result;
    }

    // function makeBid(uint256 _proposalId) public {
    //     IHFTtoken(PLATFORM_TOKEN).burnHFT
    // }
}
