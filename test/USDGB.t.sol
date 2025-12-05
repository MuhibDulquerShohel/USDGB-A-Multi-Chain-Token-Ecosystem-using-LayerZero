// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {
    GOLDBACKBOND,
    IAccessControl_GBB,
    IERC20_GBB
} from "../src/DemoUSDGB.sol";
import {GOLDBACKBONDBase} from "../src/OFTBase.sol";
import {USDGBMinting, Pausable} from "../src/MintingController.sol";
import {CollateralToken} from "../src/CollateralToken.sol";
import {DemoPriceFeed} from "../src/DemoPriceFeed.sol";
import {Guardian, IAccessControl} from "../src/Guardian.sol";

contract USDGBTest is Test {
    bytes32 public DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant EXECUTIVE_ADMIN_ROLE =
        keccak256("EXECUTIVE_ADMIN_ROLE");

    GOLDBACKBONDBase public usdgb;
    USDGBMinting public mintingController;
    Guardian public guardian;
    DemoPriceFeed public demoPriceFeed;
    CollateralToken public collateralToken;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant RATIO_PRECISION = 10000;

    address public LZEndPointAddress = address(1);
    address public owner = address(this);
    address public multi_sig_address = address(this);
    address public riskBot = address(1);
    address public prankWallet = address(5);

    // function setUp() public {
    //     usdgb = new GOLDBACKBONDBase(LZEndPointAddress);
    //     mintingController = new USDGBMinting(address(usdgb), owner);
    //     demoPriceFeed = new DemoPriceFeed();
    //     collateralToken = new CollateralToken();
    //     guardian = new Guardian(
    //         address(mintingController),
    //         multi_sig_address,
    //         riskBot
    //     );

    //     mintingController.grantRole(DEFAULT_ADMIN_ROLE, address(guardian));
    // }

    // function test_deploy() public{
    //     usdgb = new GOLDBACKBONDBase(0x6EDCE65403992e310A62460808c4b910D972f10f);
    // }

}