// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {
    GOLDBACKBOND,
    IAccessControl_GBB,
    IERC20_GBB
} from "../src/DemoUSDGB.sol";
import {USDGBMinting, Pausable} from "../src/MintingController.sol";
import {CollateralToken} from "../src/CollateralToken.sol";
import {DemoPriceFeed} from "../src/DemoPriceFeed.sol";
import {DemoGoldPriceFeed} from "../src/DemoGoldPriceFeed.sol";
import {Guardian, IAccessControl} from "../src/Guardian.sol";
import {
    LpRewardPool,
    Pausable,
    IAccessControl,
    GoldBonusVault,
    CertificateStaking
} from "../src/StakingContracts.sol";

contract GuardianTest is Test {
    bytes32 public DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant EXECUTIVE_ADMIN_ROLE =
        keccak256("EXECUTIVE_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    GOLDBACKBOND public usdgb;
    USDGBMinting public mintingController;
    Guardian public guardian;
    DemoPriceFeed public demoPriceFeed;
    CollateralToken public collateralToken;
    CollateralToken public lpToken;
    LpRewardPool public lpRewardPool;
    DemoGoldPriceFeed public demoGoldPriceFeed;
    GoldBonusVault public goldBonusVault;
    CertificateStaking public certificateStaking;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant RATIO_PRECISION = 10000;

    address public LZEndPointAddress = address(1);
    address public owner = address(this);
    address public multi_sig_address = address(this);
    address public riskBot = address(1);
    address public prankWallet = address(5);

    function setUp() public {
        usdgb = new GOLDBACKBOND(LZEndPointAddress, owner);
        lpToken = new CollateralToken();
        demoGoldPriceFeed = new DemoGoldPriceFeed();
        demoPriceFeed = new DemoPriceFeed();
        lpRewardPool = new LpRewardPool(
            address(usdgb),
            address(lpToken),
            address(this)
        );
        collateralToken = new CollateralToken();
        mintingController = new USDGBMinting(address(usdgb), owner);
        goldBonusVault = new GoldBonusVault(
            address(usdgb),
            address(lpRewardPool),
            address(demoGoldPriceFeed),
            address(this)
        );
        certificateStaking = new CertificateStaking(
            address(usdgb),
            address(this)
        );

        collateralToken = new CollateralToken();
        guardian = new Guardian(
            multi_sig_address,
            riskBot,
            address(mintingController),
            address(lpRewardPool),
            address(certificateStaking),
            address(goldBonusVault)
        );

        mintingController.grantRole(DEFAULT_ADMIN_ROLE, address(guardian));
    }

    function test_if_guardian_contract_is_initialized_successfully() public {
        Guardian newGuardian = new Guardian(
            multi_sig_address,
            riskBot,
            address(mintingController),
            address(lpRewardPool),
            address(certificateStaking),
            address(goldBonusVault)
        );
        address mcAddress = address(newGuardian.mintingContract());
        assertEq(mcAddress, address(mintingController));
        address lpAddress = address(newGuardian.lpRewardPool());
        assertEq(lpAddress, address(lpRewardPool));
        address csAddress = address(newGuardian.certificateStaking());
        assertEq(csAddress, address(certificateStaking));
        address gbvAddress = address(newGuardian.goldBonusVault());
        assertEq(gbvAddress, address(goldBonusVault));

        bool hasDefaultAdminRole = newGuardian.hasRole(
            DEFAULT_ADMIN_ROLE,
            multi_sig_address
        );
        assertTrue(hasDefaultAdminRole);
        bool hasExecutiveAdminRole = newGuardian.hasRole(
            EXECUTIVE_ADMIN_ROLE,
            multi_sig_address
        );
        assertTrue(hasExecutiveAdminRole);
        bool hasRiskManagerRole = newGuardian.hasRole(
            RISK_MANAGER_ROLE,
            riskBot
        );
        assertTrue(hasRiskManagerRole);
    }

    function test_if_revert_if_non_risk_manager_call_emergencyGlobalPause_function()
        public
    {
        vm.startPrank(prankWallet);
        vm.expectRevert("Not authorized");

        guardian.emergencyGlobalPause();
        vm.stopPrank();
    }

    function test_if_risk_manager_can_call_emergencyGlobalPause_function()
        public
    {
        vm.startPrank(riskBot);
        vm.expectEmit(address(guardian));
        emit Guardian.EmergencyGlobalPause(address(riskBot));
        guardian.emergencyGlobalPause();
        bool isPaused = mintingController.paused();
        assertTrue(isPaused);
        vm.stopPrank();
    }
    function test_if_executive_manager_can_call_emergencyGlobalPause_function()
        public
    {
        // vm.expectEmit(address(guardian));
        // emit Guardian.EmergencyGlobalPause(
        //     address(riskBot)

        // );
        lpRewardPool.grantRole(PAUSER_ROLE, address(guardian));
        certificateStaking.grantRole(PAUSER_ROLE, address(guardian));
        goldBonusVault.grantRole(PAUSER_ROLE, address(guardian));
        guardian.emergencyGlobalPause();
        bool isPausedM = mintingController.paused();
        assertTrue(isPausedM);
        bool isPausedLP = lpRewardPool.paused();
        assertTrue(isPausedLP);
        bool isPausedCS = certificateStaking.paused();
        assertTrue(isPausedCS);
        bool isPausedGBV = goldBonusVault.paused();
        assertTrue(isPausedGBV);
    }

    function test_if_revert_if_non_EXECUTIVE_ADMIN_ROLE_call_restoreOperations_function()
        public
    {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                prankWallet,
                EXECUTIVE_ADMIN_ROLE
            )
        );
        guardian.restoreOperations();
        vm.stopPrank();
    }

    function test_if_EXECUTIVE_ADMIN_ROLE_can_call_restoreOperations_function()
        public
    {
        //  vm.expectEmit(address(guardian));
        // emit Guardian.EmergencyGlobalPause(
        //     address(this)

        // );
        lpRewardPool.grantRole(PAUSER_ROLE, address(guardian));
        certificateStaking.grantRole(PAUSER_ROLE, address(guardian));
        goldBonusVault.grantRole(PAUSER_ROLE, address(guardian));

        guardian.emergencyGlobalPause();
        bool isPausedM = mintingController.paused();
        assertTrue(isPausedM);
        bool isPausedLP = lpRewardPool.paused();
        assertTrue(isPausedLP);
        bool isPausedCS = certificateStaking.paused();
        assertTrue(isPausedCS);
        bool isPausedGBV = goldBonusVault.paused();
        assertTrue(isPausedGBV);

        vm.startPrank(multi_sig_address);

        lpRewardPool.grantRole(DEFAULT_ADMIN_ROLE, address(guardian));
        certificateStaking.grantRole(DEFAULT_ADMIN_ROLE, address(guardian));
        goldBonusVault.grantRole(DEFAULT_ADMIN_ROLE, address(guardian));
        vm.expectEmit(address(guardian));
        emit Guardian.OperationsRestored(address(multi_sig_address));
        guardian.restoreOperations();
        bool isPausedMAfter = mintingController.paused();
        assertFalse(isPausedMAfter);
        bool isPausedLPAfter = lpRewardPool.paused();
        assertFalse(isPausedLPAfter);
        bool isPausedCSAfter = certificateStaking.paused();
        assertFalse(isPausedCSAfter);
        bool isPausedGBVAfter = goldBonusVault.paused();
        assertFalse(isPausedGBVAfter);
        vm.stopPrank();
    }

    // function test_if_revert_if_non_EXECUTIVE_ADMIN_ROLE_call_updateLimits_function()
    //     public
    // {
    //     vm.startPrank(prankWallet);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IAccessControl.AccessControlUnauthorizedAccount.selector,
    //             prankWallet,
    //             EXECUTIVE_ADMIN_ROLE
    //         )
    //     );
    //     guardian.updateLimits(1e18, 100e18);
    //     vm.stopPrank();
    // }

    // function test_if_EXECUTIVE_ADMIN_ROLE_can_call_updateLimits_function()
    //     public
    // {
    //     vm.stopPrank();
    //     vm.startPrank(multi_sig_address);
    //     guardian.updateLimits(10000e18, 100000000e18);
    //     uint256 softLimit = mintingController.softLimit();
    //     uint256 hardLimit = mintingController.hardLimit();
    //     assertEq(softLimit, 10000e18);
    //     assertEq(hardLimit, 100000000e18);
    // }

    function test_if_revert_if_non_EXECUTIVE_ADMIN_ROLE_call_updateTarget_function()
        public
    {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                prankWallet,
                EXECUTIVE_ADMIN_ROLE
            )
        );
        guardian.updateTargets(
            address(mintingController),
            address(lpRewardPool),
            address(certificateStaking),
            address(goldBonusVault)
        );
        vm.stopPrank();
    }

    function test_if_EXECUTIVE_ADMIN_ROLE_can_call_updateTarget_function()
        public
    {
        USDGBMinting newMintingController = new USDGBMinting(
            address(usdgb),
            multi_sig_address
        );
        LpRewardPool newLpRewardPool = new LpRewardPool(
            address(usdgb),
            address(lpToken),
            address(this)
        );
        CertificateStaking newCertificateStaking = new CertificateStaking(
            address(usdgb),
            address(this)
        );
        GoldBonusVault newGoldBonusVault = new GoldBonusVault(
            address(usdgb),
            address(newLpRewardPool),
            address(demoGoldPriceFeed),
            address(this)
        );

        vm.startPrank(multi_sig_address);
        guardian.updateTargets(
            address(newMintingController),
            address(newLpRewardPool),
            address(newCertificateStaking),
            address(newGoldBonusVault)
        );
        address mintingContractAddress = address(guardian.mintingContract());
        assertEq(mintingContractAddress, address(newMintingController));
        address lpRewardPoolAddress = address(guardian.lpRewardPool());
        assertEq(lpRewardPoolAddress, address(newLpRewardPool));
        address certificateStakingAddress = address(
            guardian.certificateStaking()
        );
        assertEq(certificateStakingAddress, address(newCertificateStaking));
        address goldBonusVaultAddress = address(guardian.goldBonusVault());
        assertEq(goldBonusVaultAddress, address(newGoldBonusVault));
        vm.stopPrank();
    }
}
