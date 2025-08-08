// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error InvalidAddress(address user);
error InvalidBudget(uint256 amount);
error InvalidTime(uint256 startTime, uint256 endTime);
error OnlyClientCanCall(address caller);
error OnlyBidderCanCall(address caller);
error CantModifyFinalState();
error InvalidProposalState();
error BidderAlreadyExists();
error PaymentFailed();
error InvalidStateForPayment(uint256 proposalId, uint8 currentState);
error InvalidProposalId(uint256 proposalId);
error NotAuthorized();
error InsufficientBidFee();

error OnlyBidderCanStartWork();
error MustBeInFundedState();
error BidderCanOnlyStartWork();
error OnlyClientOrBidderCanDispute();
error MustCompleteMilestone1First();
error MustCompleteMilestone2First();
