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
    GoldBonusVault, CertificateStaking
} from "../src/StakingContracts.sol";

contract USDGBMintingTest is Test {
    bytes32 public DEFAULT_ADMIN_ROLE = 0x00;
   bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // For Partners/APIs
    bytes32 public constant COMPLIANCE_ADMIN = keccak256("COMPLIANCE_ADMIN"); // For Human Reviewers
    bytes32 public constant EXECUTIVE_ADMIN_ROLE =
        keccak256("EXECUTIVE_ADMIN_ROLE");
         bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");

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
        mintingController = new USDGBMinting(address(usdgb), owner);
        demoPriceFeed = new DemoPriceFeed();
        collateralToken = new CollateralToken();
        lpToken = new CollateralToken();
        demoGoldPriceFeed = new DemoGoldPriceFeed();

        lpRewardPool = new LpRewardPool(
            address(usdgb),
            address(lpToken),
            address(this)
        );
       
        
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
       guardian = new Guardian(
            multi_sig_address,
            riskBot,
            address(mintingController), address(lpRewardPool),
            address(certificateStaking),address(goldBonusVault)
        );

        mintingController.grantRole(DEFAULT_ADMIN_ROLE, address(guardian));
        
    }

    function test_if_minting_controller_is_initialized_successfully()
        public
    {
        USDGBMinting newMintingController = new USDGBMinting(
            address(usdgb),
            multi_sig_address
        );
        address usdgbAddress = address(newMintingController.usdgb());
        assertEq(usdgbAddress, address(usdgb));
        uint256 softLimit = newMintingController.softLimit();
        uint256 hardLimit = newMintingController.hardLimit();
        assertEq(softLimit, 10_000 * 10 ** 18);
        assertEq(hardLimit, 1_000_000 * 10 ** 18);

        bool hasDefaultAdminRole =
            newMintingController.hasRole(DEFAULT_ADMIN_ROLE, address(multi_sig_address));
        assertTrue(hasDefaultAdminRole);
        bool hasComplianceAdminRole =
            newMintingController.hasRole(
                mintingController.COMPLIANCE_ADMIN(),
                address(multi_sig_address)
            );
        assertTrue(hasComplianceAdminRole);
    }

    function test_if_revert_if_non_minter_calls_minting()
        public
    {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                prankWallet,
                MINTER_ROLE
            )
        );
        mintingController.mint(prankWallet, 1000 * PRECISION);
        vm.stopPrank();
    }

    function test_if_revert_if_minting_is_paused_while_calling_mint_function() public {
        vm.startPrank(riskBot);
        vm.expectEmit(address(guardian));
        emit Guardian.EmergencyGlobalPause(
            address(riskBot)
        );
        guardian.emergencyGlobalPause();
        bool isPaused = mintingController.paused();
        assertTrue(isPaused);
        vm.stopPrank();
        mintingController.grantRole(MINTER_ROLE, multi_sig_address);
        vm.startPrank(multi_sig_address);
        vm.expectRevert(
            abi.encodeWithSelector(
                Pausable.EnforcedPause.selector
            )
        );
        mintingController.mint(owner, 10e18);
        vm.stopPrank();
    }

    function test_if_revert_if_amount_exceeds_hard_limit_while_calling_mint_function()
        public
    {
        mintingController.grantRole(MINTER_ROLE, multi_sig_address);
        vm.startPrank(multi_sig_address);
        vm.expectRevert("Exceeds Hard Limit");
        mintingController.mint(owner, 1_000_001 * PRECISION);
        vm.stopPrank();
    }

    function test_if_minter_can_mint_successfully_if_amount_is_within_soft_limit()
        public
    {
        mintingController.grantRole(MINTER_ROLE, multi_sig_address);
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        vm.startPrank(multi_sig_address);
        mintingController.mint(owner, 10_000 * PRECISION);
        uint256 balance = usdgb.balanceOf(owner);
        assertEq(balance, 10_000 * PRECISION);
        vm.stopPrank();
    }

    function test_if_send_to_transaction_queue_if_amount_exceeds_soft_limit()
        public
    {
        mintingController.grantRole(MINTER_ROLE, multi_sig_address);
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        vm.startPrank(multi_sig_address);
        vm.expectEmit(address(mintingController));
        emit USDGBMinting.TransactionQueued(0, owner, 10_001 * PRECISION);
         // Minting amount exceeds soft limit
        mintingController.mint(owner, 10_001 * PRECISION);
        uint256 balance = usdgb.balanceOf(owner);
        assertEq(balance, 0); // Not minted yet
        ( address user, uint256 amount,, bool processed) =
            mintingController.complianceQueue(0);
        assertEq(user, owner);
        assertEq(amount, 10_001 * PRECISION);
        assertFalse(processed);
        vm.stopPrank();
    }

    function test_if_revert_if_non_COMPLIANCE_ADMIN_calls_approve_transaction_function()
        public
    {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                prankWallet,
                COMPLIANCE_ADMIN
            )
        );
        mintingController.approveTransaction(0);
        vm.stopPrank();
    } 

    function test_if_revert_if_approve_transaction_request_is_already_processed()
        public
    {
        mintingController.grantRole(MINTER_ROLE, multi_sig_address);
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        vm.startPrank(multi_sig_address);
        vm.expectEmit(address(mintingController));
        emit USDGBMinting.TransactionQueued(0, owner, 10_001 * PRECISION);
         // Minting amount exceeds soft limit
        mintingController.mint(owner, 10_001 * PRECISION);
        uint256 balance = usdgb.balanceOf(owner);
        assertEq(balance, 0); // Not minted yet
        ( address user, uint256 amount,, bool processed) =
            mintingController.complianceQueue(0);
        assertEq(user, owner);
        assertEq(amount, 10_001 * PRECISION);
        assertFalse(processed);
        vm.stopPrank();

        vm.startPrank(multi_sig_address);
        mintingController.approveTransaction(0);
        vm.expectRevert("Processed");
        mintingController.approveTransaction(0);
        vm.stopPrank();
    }  

    function test_if_COMPLIANCE_ADMIN_can_approve_transaction_successfully()
        public
    {
        mintingController.grantRole(MINTER_ROLE, multi_sig_address);
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        vm.startPrank(multi_sig_address);
        vm.expectEmit(address(mintingController));
        emit USDGBMinting.TransactionQueued(0, owner, 10_001 * PRECISION);
         // Minting amount exceeds soft limit
        mintingController.mint(owner, 10_001 * PRECISION);
        uint256 balance = usdgb.balanceOf(owner);
        assertEq(balance, 0); // Not minted yet
        ( address user, uint256 amount,, bool processed) =
            mintingController.complianceQueue(0);
        assertEq(user, owner);
        assertEq(amount, 10_001 * PRECISION);
        assertFalse(processed);
        vm.stopPrank();

        vm.startPrank(multi_sig_address);
        vm.expectEmit(address(mintingController));
        emit USDGBMinting.TransactionApproved(0, owner, 10_001 * PRECISION);
        mintingController.approveTransaction(0);
        balance = usdgb.balanceOf(owner);
        assertEq(balance, 10_001 * PRECISION);
        ( user, amount,, processed) =
            mintingController.complianceQueue(0);
        assertTrue(processed); // Processed
        vm.stopPrank();
    }

    function test_if_revert_if_non_COMPLIANCE_ADMIN_calls_rejectTransaction_function()
        public
    {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                prankWallet,
                COMPLIANCE_ADMIN
            )
        );
        mintingController.rejectTransaction(0, "Test rejection");
        vm.stopPrank();
    } 

    function test_if_revert_if_transaction_request_is_already_processed_while_calling_rejectTransaction()
        public
    {
        mintingController.grantRole(MINTER_ROLE, multi_sig_address);
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        vm.startPrank(multi_sig_address);
        vm.expectEmit(address(mintingController));
        emit USDGBMinting.TransactionQueued(0, owner, 10_001 * PRECISION);
         // Minting amount exceeds soft limit
        mintingController.mint(owner, 10_001 * PRECISION);
        uint256 balance = usdgb.balanceOf(owner);
        assertEq(balance, 0); // Not minted yet
        ( address user, uint256 amount,, bool processed) =
            mintingController.complianceQueue(0);
        assertEq(user, owner);
        assertEq(amount, 10_001 * PRECISION);
        assertFalse(processed);
        vm.stopPrank();

        vm.startPrank(multi_sig_address);
        mintingController.approveTransaction(0);
        vm.expectRevert("Processed");
        mintingController.rejectTransaction(0,"Test rejection");
        vm.stopPrank();
    } 


    function test_if_COMPLIANCE_ADMIN_can_rejectTransaction_successfully()
        public
    {
        mintingController.grantRole(MINTER_ROLE, multi_sig_address);
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        vm.startPrank(multi_sig_address);
        vm.expectEmit(address(mintingController));
        emit USDGBMinting.TransactionQueued(0, owner, 10_001 * PRECISION);
         // Minting amount exceeds soft limit
        mintingController.mint(owner, 10_001 * PRECISION);
        uint256 balance = usdgb.balanceOf(owner);
        assertEq(balance, 0); // Not minted yet
        ( address user, uint256 amount,, bool processed) =
            mintingController.complianceQueue(0);
        assertEq(user, owner);
        assertEq(amount, 10_001 * PRECISION);
        assertFalse(processed);
        vm.stopPrank();

        vm.startPrank(multi_sig_address);
        vm.expectEmit(address(mintingController));
        emit USDGBMinting.TransactionRejected(0, "Test rejection");
        mintingController.rejectTransaction(0, "Test rejection");
        balance = usdgb.balanceOf(owner);
        assertEq(balance,0);
        ( user, amount,, processed) =
            mintingController.complianceQueue(0);
        assertTrue(processed); // Processed
        vm.stopPrank();
    }

    //  function test_if_revert_if_non_EXECUTIVE_ADMIN_ROLE_call_updateLimits_function()
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


    function test_if_revert_if_non_risk_manager_call_emergencyGlobalPause_function()
        public
    {
        vm.startPrank(prankWallet);
        vm.expectRevert(
          "Not authorized"
        );

        guardian.emergencyGlobalPause();
        vm.stopPrank();
    }

    function test_if_risk_manager_can_call_emergencyGlobalPause_function()
        public
    {
        vm.startPrank(riskBot);
        vm.expectEmit(address(guardian));
        emit Guardian.EmergencyGlobalPause(
            address(riskBot)
        );
        guardian.emergencyGlobalPause();
        bool isPaused = mintingController.paused();
        assertTrue(isPaused);
        vm.stopPrank();
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
        vm.startPrank(riskBot);
        vm.expectEmit(address(guardian));
        emit Guardian.EmergencyGlobalPause(
            address(riskBot)
        );
        guardian.emergencyGlobalPause();
        bool isPausedOne = mintingController.paused();
        assertTrue(isPausedOne);
        vm.stopPrank();
        vm.startPrank(multi_sig_address);

        
        guardian.restoreOperations();
        bool isPaused = mintingController.paused();
        assertFalse(isPaused);
    }



}