// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { GOLDBACKBONDBase } from "../src/OFTBase.sol";

contract DeployOApp is Script {
    function run() external {
        console.log("EVM deployment script started, please wait.....");
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        GOLDBACKBONDBase usdgb = new GOLDBACKBONDBase(0x6EDCE65403992e310A62460808c4b910D972f10f, true);
        vm.stopBroadcast();

        console.log("GOLDBACKBOND EVM version deployed to:", address(usdgb));
    }
}
//forge script script/DeployToEVM.s.sol --fork-url "put your rpc url here" --broadcast --verify
//forge script script/0-DeployToEVM.s.sol --fork-url  --broadcast --verify
//forge create src/OFTEthereum.sol:GOLDBACKBOND --rpc-url  --private-key 
