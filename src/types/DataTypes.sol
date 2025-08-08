// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum ProposalState {
    Draft, // 0
    Active, // 1
    Awarded, // 2
    Funded, // 3
    InProgress, // 4
    MilestonePayout_ONE, // 5
    MilestonePayout_TWO, // 6
    MilestonePayout_THREE, // 7
    Completed, // 8
    Disputed, // 9
    Cancelled, // 10
    Refunded // 11

}

enum Role {
    MANAGER, // 0
    DAO_MEMBER // 1

}

enum ImprovementType {
    PLATFORM_TOKEN_UPDATE,
    PAYMENT_INSTANCES_UPDATE,
    TREASURY_ADDRESS_UPDATE,
    ESCROW_ADDRESS_UPDATE,
    USDC_ADDRESS_UPDATE
}

struct Proposal {
    uint256 id;
    address client;
    address bidder;
    uint256 startTime;
    uint256 endTime;
    uint256 budget;
    uint256 bidAmount;
    uint8 state;
}

struct DaoMember {
    address member;
    Role role;
}

struct ImprovementProposal {
    uint256 ipId;
    uint256 proposalRaisedTime;
    uint256 totalVotes;
    bool isAccepted;
    ImprovementType proposalType;
}
