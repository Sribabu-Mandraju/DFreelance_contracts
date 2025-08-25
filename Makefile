-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.1.0 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

coverage :; forge coverage --report debug > coverage-report.txt

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
	endif

deploy:
	@forge script script/DeployContracts.s.sol:DeployContracts --rpc-url $(ANVIL_RPC_URL) --private-key $(PRIVATE_KEY) -vvvvv --broadcast

deploy-local:
	@forge script script/DeployLocal.s.sol:DeployLocal --rpc-url $(ANVIL_RPC_URL) --private-key $(PRIVATE_KEY)  --broadcast -vv

deploy-base:
	@forge script script/DeployBase.s.sol:DeployBase --rpc-url $(BASE_SEPOLIA_RPC_URL) --private-key $(WALLET_PRIVATE_KEY)  --broadcast -vvvvv

deploy-transfer:
	@forge script script/interactions/EnableTransfers.s.sol:EnableTransfer --rpc-url $(BASE_SEPOLIA_RPC_URL) --private-key $(WALLET_PRIVATE_KEY)  --broadcast -vvvvv
	
deploy-escrow:
	@forge script script/interactions/Escrow_Interaction.s.sol:Escrow_Interaction --rpc-url $(BASE_SEPOLIA_RPC_URL) --private-key $(WALLET_PRIVATE_KEY)  --broadcast -vvvvv


verify-base:
	forge verify-contract \
  0xC7Ac55fF5C832fDc8572C5F0C6E203BB329Af35B \
  src/TimeLockNFTStaking.sol:TimeLockNFTStaking \
  --chain-id 8453 \
  --verifier etherscan \
  --verifier-url https://api.basescan.org/api \
  --etherscan-api-key $(BASE_SCAN_API_KEY) \
  --compiler-version 0.8.28 \
  --rpc-url https://base-mainnet.g.alchemy.com/v2/1kKjc1l5XNcYUfnpMkIht \

verify-contract:
  forge verify-contract \
  --chain base-sepolia \
  --etherscan-api-key QFTNJ48YRWCIV4JK52FT91HYUYN77AY1DH \
  --compiler-version v0.8.24+commit.e11b9ed9 \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x036CbD53842c5426634e7929541eC2318f3dCF7e 0xd0f8B61b0EB48f54e10e3daA68bAC846e4bC2F56 0x30217A8C17EF5571639948D118D086c73f823058) \
  0xb7eBD3c77C8c0B0Cf783b7C8930C01BCDf8c562C \
  src/Escrow.sol:Escrow



check-verify:
	forge verify-contract \
  --verifier-url https://api-sepolia.basescan.org/api \
  --etherscan-api-key QFTNJ48YRWCIV4JK52FT91HYUYN77AY1DH \
  0xb7eBD3c77C8c0B0Cf783b7C8930C01BCDf8c562C \
  src/Escrow.sol:Escrow
