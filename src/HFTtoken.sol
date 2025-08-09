// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract HFTtoken is ERC20, Ownable {
    ///////////////////////////////
    //     ERRORS
    ///////////////////////////////
    error HFTtoken__canClaimOnlyOnceInAMonth();
    error HFTtoken__insifficientAMountToBid();
    error HFTtoken__transferTokensToAnotherAddressIsDisables();

    event HFTtoken_claimedTokensSuccessful(address indexed claimer, uint256 indexed amount);
    event HFTtoken_bidOnProposalSuccessful(uint256 indexed proposalId, address indexed bidder);

    // Track monthly claims per address
    mapping(address => uint256) public lastClaimTime;

    // bids ids
    mapping(address => uint256[]) public bidsByAddress;

    uint256 public CLAIM_INTERVAL = 30 days;
    uint256 public CLAIM_AMOUNT = 150 ether; // 150 tokens with 18 decimals
    uint256 public BID_FEE = 25 ether;

    // Transfer restrictions
    bool public transfersEnabled;
    mapping(address => bool) public whitelisted;

    constructor(address initialOwner) ERC20("HIGH_FIVE", "HFT") Ownable(initialOwner) {
        transfersEnabled = false; // Disable transfers by default
        whitelisted[initialOwner] = true; // Whitelist owner for initial distribution
    }

    // Monthly claim function
    function claimTokens() public {
        require(
            lastClaimTime[msg.sender] == 0 // First-time claim
                || block.timestamp >= lastClaimTime[msg.sender] + CLAIM_INTERVAL, // Subsequent claims
            HFTtoken__canClaimOnlyOnceInAMonth()
        );
        // require(balanceOf(msg.sender) == 0, "Already has tokens");

        lastClaimTime[msg.sender] = block.timestamp;
        _mint(msg.sender, CLAIM_AMOUNT);
        emit HFTtoken_claimedTokensSuccessful(msg.sender, CLAIM_AMOUNT);
    }

    function placeBid(uint256 _proposalId) public {
        require(balanceOf(msg.sender) >= 25e18, HFTtoken__insifficientAMountToBid());
        burnHFT(msg.sender, 25e18);
        bidsByAddress[msg.sender].push(_proposalId);
        emit HFTtoken_bidOnProposalSuccessful(_proposalId, msg.sender);
    }

    // Override transfer functions with restrictions
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0)) {
            // Not a mint operation
            require(transfersEnabled || whitelisted[from], HFTtoken__transferTokensToAnotherAddressIsDisables());
            require(to != from, "Cannot transfer to self");

            // Prevent transfers to addresses that already have tokens
            if (!whitelisted[to]) {
                require(balanceOf(to) == 0, "Recipient already has tokens");
            }
        }

        super._update(from, to, value);
    }

    // Admin functions
    function enableTransfers(bool _enabled) external onlyOwner {
        transfersEnabled = _enabled;
    }

    function whitelistAddress(address _addr, bool _whitelisted) external onlyOwner {
        whitelisted[_addr] = _whitelisted;
    }

    function updateClaimAmount(uint256 _newAmount) external onlyOwner {
        CLAIM_AMOUNT = _newAmount;
    }

    function getBidsOfUser(address _bidder) public view returns (uint256[] memory _ids) {
        return bidsByAddress[_bidder];
    }

    function updateBidFee(uint256 _newBidFee) external onlyOwner {
        BID_FEE = _newBidFee;
    }

    function mintHFT(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function burnHFT(address _onBehalfOf, uint256 _amount) internal {
        _burn(_onBehalfOf, _amount);
    }
}
