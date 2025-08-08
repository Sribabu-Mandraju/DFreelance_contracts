// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

event ProposalStateUpdated(uint256 indexed proposalId, uint8 indexed newState, uint256 timestamp);

event PaymentSuccessful(uint256 indexed proposalId, address indexed client, uint256 indexed amount);

event ProposalCreated(uint256 indexed proposalId, address indexed client);

event BidPlaced(uint256 indexed proposalId, address indexed bidder);

event DaoMemberAdded(address indexed member, uint8 role);

event DaoMemberRemoved(address indexed member);

event PlatformFeeUpdated(uint256 newFee);

event BidFeeUpdated(uint256 newBidFee);
