// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { GOLDBACKBONDArbitrum } from "../src/OFTArbitrum.sol";

contract DeployOApp is Script {
    function run() external {
        console.log("HyperEVM deployment script started, please wait.....");
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        GOLDBACKBONDArbitrum usdgb = new GOLDBACKBONDArbitrum(0x6EDCE65403992e310A62460808c4b910D972f10f);
        vm.stopBroadcast();

        console.log("GOLDBACKBOND HyperEVM version deployed to:", address(usdgb));
    }
}
//forge script script/DeployToHyper.s.sol --fork-url https://rpcs.chain.link/hyperevm/testnet --broadcast --verify
//forge script script/DeployToHyper.s.sol --fork-url https://hyperevm-testnet.gateway.tatum.io/ --broadcast --verify
//forge script script/DeployToHyper.s.sol --fork-url https://rpc.hyperliquid-testnet.xyz/evm --broadcast --verify
//forge script script/DeployToHyper.s.sol --fork-url https://hyperliquid-testnet.drpc.org --broadcast --verify