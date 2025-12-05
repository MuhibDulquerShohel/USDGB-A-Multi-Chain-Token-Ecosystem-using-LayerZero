-include .env

###############################
# DEPLOY CONTRACTS
###############################

deploy-oft-to-sepolia:
	forge create src/OFTEthereum.sol:GOLDBACKBOND \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY)

deploy-oft-to-mumbai:
	forge create src/OFT_Mumbai.sol:GOLDBACKBOND \
		--rpc-url $(MUMBAI_RPC_URL) \
		--private-key $(PRIVATE_KEY)

###############################
# VERIFY CONTRACTS

###############################

verify-deployed-contract-on-sepolia:
	forge verify-contract --chain-id 11155111 --watch \
		$(SEPOLIA_OFT_ADDRESS) \
		src/OFT_Sepolia.sol:OFT_Sepolia \
		--etherscan-api-key $(ETHERSCAN_KEY)

verify-deployed-contract-on-mumbai:
	forge verify-contract --chain-id 80001 --watch \
		$(MUMBAI_OFT_ADDRESS) \
		src/OFT_Mumbai.sol:OFT_Mumbai \
		--etherscan-api-key $(POLYGONSCAN_KEY)

#forge verify-contract --chain-id 40161 --watch \
		0xa8d57a9f03acf9cdfc3cd378e3c3859661dcb91a \
		src/OFTHyperEVM.sol:GOLDBACKBONDHyper \
		--etherscan-api-key "4X3C1RKQBPFFG4D2K89CC62IHBNM8VMXU2" --verifier etherscan
###############################
# SET PEERS (WIRE UP CONTRACTS)
###############################

set-peer-on-sepolia-contract:
	cast send $(SEPOLIA_OFT_ADDRESS) \
		"setPeer(uint32,bytes32)" 40109 $(MUMBAI_BYTES32_PEER) \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY)

set-peer-on-mumbai-contract:
	cast send $(MUMBAI_OFT_ADDRESS) \
		"setPeer(uint32,bytes32)" 40161 $(SEPOLIA_BYTES32_PEER) \
		--rpc-url $(MUMBAI_RPC_URL) \
		--private-key $(PRIVATE_KEY)

###############################
# CHECK PEERS
###############################

check-sepolia-peer:
	cast call $(SEPOLIA_OFT_ADDRESS) \
		"isPeer(uint32,bytes32)(bool)" \
		40109 $(MUMBAI_BYTES32_PEER) \
		--rpc-url $(SEPOLIA_RPC_URL)

check-mumbai-peer:
	cast call $(MUMBAI_OFT_ADDRESS) \
		"isPeer(uint32,bytes32)(bool)" \
		40161 $(SEPOLIA_BYTES32_PEER) \
		--rpc-url $(MUMBAI_RPC_URL)

###############################
# TOTAL SUPPLY
###############################

check-sepolia-total-supply:
	cast call $(SEPOLIA_OFT_ADDRESS) "totalSupply()(uint)" \
		--rpc-url $(SEPOLIA_RPC_URL)

check-mumbai-total-supply:
	cast call $(MUMBAI_OFT_ADDRESS) "totalSupply()(uint)" \
		--rpc-url $(MUMBAI_RPC_URL)

###############################
# SEND TOKENS
###############################

send-tokens-from-sepolia-to-mumbai:
	cast send $(SEPOLIA_OFT_ADDRESS) \
		"send(uint32,bytes32,uint256,uint256,bytes,bytes,bytes,address)" \
		40245 $(MUMBAI_BYTES32_PEER) 1000000000000000000 0 "0x" "0x" "0x" $(SEPOLIA_OFT_ADDRESS) \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY)
