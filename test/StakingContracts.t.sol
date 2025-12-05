// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {
    GOLDBACKBOND,
    IAccessControl_GBB,
    IERC20_GBB
} from "../src/DemoUSDGB.sol";
import {USDGBMinting} from "../src/MintingController.sol";
import {CollateralToken, IERC20} from "../src/CollateralToken.sol";
import {DemoPriceFeed} from "../src/DemoPriceFeed.sol";
import {
    LpRewardPool,
    Pausable,
    IAccessControl,
    GoldBonusVault, CertificateStaking
} from "../src/StakingContracts.sol";
// import {LPToken, IERC20} from "../src/LPToken.sol";
import {DemoGoldPriceFeed} from "../src/DemoGoldPriceFeed.sol";

contract StakingContractsTest is Test {
    bytes32 public DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public PAUSER_ROLE = keccak256("PAUSER_ROLE");
    GOLDBACKBOND public usdgb;
    USDGBMinting public mintingController;
    DemoPriceFeed public demoPriceFeed;
    CollateralToken public collateralToken;
    LpRewardPool public lpRewardPool;
    DemoGoldPriceFeed public demoGoldPriceFeed;
    CollateralToken public lpToken;
    GoldBonusVault public goldBonusVault;
    CertificateStaking public certificateStaking;

    address public LZEndPointAddress = address(1);
    address public owner = address(this);
    address public prankWallet = address(5);
    address[] public users;

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
    }

    function test_if_revert_if_GBB_token_address_is_zero_while_initializing_LpRewardPool()
        public
    {
        vm.expectRevert("Zero address");
        new LpRewardPool(
            address(0),
            address(lpToken),
            address(demoGoldPriceFeed)
        );
    }
    function test_if_revert_if_lp_token_address_is_zero_while_initializing_LpRewardPool()
        public
    {
        vm.expectRevert("Zero address");
        new LpRewardPool(
            address(usdgb),
            address(0),
            address(demoGoldPriceFeed)
        );
    }

    function test_if_lp_reward_pool_initialized_correctly() public view {
        assertEq(address(lpRewardPool.GBB_TOKEN()), address(usdgb));
        assertEq(address(lpRewardPool.LP_TOKEN()), address(lpToken));
    }

    function test_if_revert_if_staking_is_paused_while_calling_staking_function()
        public
    {
        lpRewardPool.pause();
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        lpRewardPool.stake(1e18);
    }

    function test_if_revert_if_amount_is_zero_while_calling_staking_function()
        public
    {
        vm.expectRevert("Cannot stake 0");
        lpRewardPool.stake(0);
    }

    function test_if_revert_if_usdgb_balance_is_less_than_reward_while_calling_stake_function()
        public
    {
        lpToken.approve(address(lpRewardPool), 100e18);
        lpRewardPool.stake(1e18);
        skip(30 days);
        vm.expectRevert("Reward pool empty");
        lpRewardPool.stake(1e18);
    }

    function test_if_user_can_successfully_stake() public {
        lpToken.approve(address(lpRewardPool), 100e18);
        uint256 amount = 1e18;
        vm.expectEmit(address(lpToken));
        emit IERC20.Transfer(address(this), address(lpRewardPool), amount);
        // vm.expectEmit(address(lpRewardPool));
        // emit LpRewardPool.Staked(address(this), amount);
        lpRewardPool.stake(amount);
        (
            uint256 lpAmount,
            uint256 lastClaimTimeBase,
            uint256 lastClaimTimeGoldBonus
        ) = lpRewardPool.userStakes(address(this));
        assertEq(lpAmount, amount);
        assertEq(lastClaimTimeBase, block.timestamp);
        assertEq(lastClaimTimeGoldBonus, block.timestamp);
    }

    function test_if_revert_if_staking_is_paused_while_calling_withdraw_function()
        public
    {
        lpRewardPool.pause();
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        lpRewardPool.withdraw(1e18);
    }

    function test_if_revert_if_amount_is_zero_while_calling_withdraw_function()
        public
    {
        vm.expectRevert("Insufficient stake");
        lpRewardPool.withdraw(0);
    }

    function test_if_revert_if_amount_is_greater_than_staked_amount_while_calling_withdraw_function()
        public
    {
        lpToken.approve(address(lpRewardPool), 100e18);
        uint256 amount = 1e18;
        vm.expectEmit(address(lpToken));
        emit IERC20.Transfer(address(this), address(lpRewardPool), amount);

        lpRewardPool.stake(amount);
        vm.expectRevert("Insufficient stake");
        lpRewardPool.withdraw(amount + 1);
    }

    function test_if_revert_if_usdgb_balance_is_less_than_reward_while_calling_withdraw_function()
        public
    {
        lpToken.approve(address(lpRewardPool), 100e18);
        uint256 amount = 1e18;
        vm.expectEmit(address(lpToken));
        emit IERC20.Transfer(address(this), address(lpRewardPool), amount);
        lpRewardPool.stake(amount);
        skip(30 days);
        vm.expectRevert("Reward pool empty");

        lpRewardPool.withdraw(1e18);
    }

    function test_if_user_can_successfully_call_withdraw_function() public {
        lpToken.approve(address(lpRewardPool), 100e18);
        uint256 amount = 1e18;
        vm.expectEmit(address(lpToken));
        emit IERC20.Transfer(address(this), address(lpRewardPool), amount);

        lpRewardPool.stake(amount);
        (
            uint256 lpAmount,
            uint256 lastClaimTimeBase,
            uint256 lastClaimTimeGoldBonus
        ) = lpRewardPool.userStakes(address(this));
        assertEq(lpAmount, amount);
        assertEq(lastClaimTimeBase, block.timestamp);
        assertEq(lastClaimTimeGoldBonus, block.timestamp);
        skip(30 days);
        mintingController.grantRole(MINTER_ROLE, address(this));
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        mintingController.mint(address(this), 10e18);
        usdgb.transfer(address(lpRewardPool), 1e18);

        lpRewardPool.withdraw(amount);
    }

    function test_if_revert_if_staking_is_paused_while_calling_claimReward_function()
        public
    {
        lpRewardPool.pause();
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        lpRewardPool.claimReward();
    }

    function test_if_revert_if_usdgb_balance_is_less_than_reward_while_calling_claimReward_function()
        public
    {
        lpToken.approve(address(lpRewardPool), 100e18);
        uint256 amount = 1e18;
        vm.expectEmit(address(lpToken));
        emit IERC20.Transfer(address(this), address(lpRewardPool), amount);
        lpRewardPool.stake(amount);
        skip(30 days);
        vm.expectRevert("Reward pool empty");

        lpRewardPool.claimReward();
    }

    function test_if_user_can_successfully_call_claimReward_function() public {
        lpToken.approve(address(lpRewardPool), 100e18);
        uint256 amount = 1e18;

        lpRewardPool.stake(amount);
        (
            uint256 lpAmount,
            uint256 lastClaimTimeBase,
            uint256 lastClaimTimeGoldBonus
        ) = lpRewardPool.userStakes(address(this));
        assertEq(lpAmount, amount);
        assertEq(lastClaimTimeBase, block.timestamp);
        assertEq(lastClaimTimeGoldBonus, block.timestamp);
        skip(30 days);
        mintingController.grantRole(MINTER_ROLE, address(this));
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        mintingController.mint(address(this), 10e18);
        usdgb.transfer(address(lpRewardPool), 1e18);
        // uint256 reward = lpRewardPool.calculateReward(address(this));
        lpRewardPool.claimReward();
    }

    function test_if_revert_if_non_PAUSER_ROLE_calls_pause_function() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     IAccessControl.AccessControlUnauthorizedAccount.selector,
            //     prankWallet,
            //     PAUSER_ROLE
            // )
        );
        lpRewardPool.pause();
        vm.stopPrank();
    }

    function test_if_Pauser_can_successfully_call_pause_function() public {
        lpRewardPool.grantRole(PAUSER_ROLE, address(this));
        lpRewardPool.pause();
        assertEq(lpRewardPool.paused(), true);
    }
    function test_if_revert_if_non_PAUSER_ROLE_calls_unpause_function() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     IAccessControl.AccessControlUnauthorizedAccount.selector,
            //     prankWallet,
            //     PAUSER_ROLE
            // )
        );
        lpRewardPool.unpause();
        vm.stopPrank();
    }

    function test_if_Pauser_can_successfully_call_unpause_function() public {
        lpRewardPool.grantRole(PAUSER_ROLE, address(this));
        lpRewardPool.pause();
        assertEq(lpRewardPool.paused(), true);
        lpRewardPool.unpause();
        assertEq(lpRewardPool.paused(), false);
    }

    function test_if_gold_vault_initialized_correctly() public view {
        assertEq(address(goldBonusVault.GBB_TOKEN()), address(usdgb));
        assertEq(address(goldBonusVault.LP_REWARD_POOL()), address(lpRewardPool));
        bool hasAdminRole = goldBonusVault.hasRole(
            DEFAULT_ADMIN_ROLE,
            address(this)
        );
        assertEq(hasAdminRole, true);
        bool hadPauserRole = goldBonusVault.hasRole(
            PAUSER_ROLE,
            address(this)
        );
        assertEq(hadPauserRole, true);
    }

    function test_if_getLatestGoldPrice_function_works_correctly() public view{
        (, int256 price,,,) = demoGoldPriceFeed.latestRoundData();
        
        uint256 goldPrice = goldBonusVault.getLatestGoldPrice();
        assertEq(goldPrice, uint256(price));
    }

    function test_if_revert_if_non_admin_calls_distributeBonus_function() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                prankWallet,
                DEFAULT_ADMIN_ROLE
            )
        );
        users.push(address(6));
        goldBonusVault.distributeBonus(users);
        vm.stopPrank();
    }

    function test_if_revert_if_paused_while_calling_distributeBonus_function() public {
        goldBonusVault.pause();
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        users.push(address(6));
        goldBonusVault.distributeBonus(users);
    }

    function test_if_distributeBonus_function_works_correctly() public {
        users.push(address(6));
        users.push(address(7));
        users.push(address(8));

        lpToken.transfer(address(6), 1e18);
        lpToken.transfer(address(7), 1e18);
        lpToken.transfer(address(8), 1e18);

        vm.startPrank(address(6));
        lpToken.approve(address(lpRewardPool), 1e18);
        lpRewardPool.stake(1e18);
        vm.stopPrank();
        vm.startPrank(address(7));
        lpToken.approve(address(lpRewardPool), 1e18);
        lpRewardPool.stake(1e18);
        vm.stopPrank();
        vm.startPrank(address(8));
        lpToken.approve(address(lpRewardPool), 1e18);
        lpRewardPool.stake(1e18);
        vm.stopPrank();
        skip(30 days);
        uint256 balanceOf6Before = usdgb.balanceOf(address(6));
        uint256 balanceOf7Before = usdgb.balanceOf(address(7)); 
        uint256 balanceOf8Before = usdgb.balanceOf(address(8));

        mintingController.grantRole(MINTER_ROLE, address(this));
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        mintingController.mint(address(this), 10e18);
        usdgb.transfer(address(goldBonusVault), 5e18);
        demoGoldPriceFeed.updateReverse(true);
        goldBonusVault.distributeBonus(users);

        uint256 balanceOf6After = usdgb.balanceOf(address(6));
        uint256 balanceOf7After = usdgb.balanceOf(address(7));
        uint256 balanceOf8After = usdgb.balanceOf(address(8));
        assertGt(balanceOf6After, balanceOf6Before);
        assertGt(balanceOf7After, balanceOf7Before);
        assertGt(balanceOf8After, balanceOf8Before);

    }

        function test_if_revert_if_non_PAUSER_ROLE_calls_pause_function_of_goldVault() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     IAccessControl.AccessControlUnauthorizedAccount.selector,
            //     prankWallet,
            //     PAUSER_ROLE
            // )
        );
        goldBonusVault.pause();
        vm.stopPrank();
    }

    function test_if_Pauser_can_successfully_call_pause_function_of_goldVault() public {
        goldBonusVault.grantRole(PAUSER_ROLE, address(this));
        goldBonusVault.pause();
        assertEq(goldBonusVault.paused(), true);
    }
    function test_if_revert_if_non_PAUSER_ROLE_calls_unpause_function_of_goldVault() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     IAccessControl.AccessControlUnauthorizedAccount.selector,
            //     prankWallet,
            //     PAUSER_ROLE
            // )
        );
        goldBonusVault.unpause();
        vm.stopPrank();
    }

    function test_if_admin_can_successfully_call_unpause_function_of_goldVault() public {
        goldBonusVault.grantRole(DEFAULT_ADMIN_ROLE, address(this));
        goldBonusVault.pause();
        assertEq(goldBonusVault.paused(), true);
        goldBonusVault.unpause();
        assertEq(goldBonusVault.paused(), false);
    }

    function test_if_CertificateStaking_initialized_correctly() public view {
        assertEq(address(certificateStaking.GBB_TOKEN()), address(usdgb));
        bool hasAdminRole = certificateStaking.hasRole(
            DEFAULT_ADMIN_ROLE,
            address(this)
        );
        assertEq(hasAdminRole, true);
    }

    function test_if_revert_if_paused_while_calling_stakeForCertificate_function()
        public
    {
        certificateStaking.pause();
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        certificateStaking.stakeForCertificate(1e18);
    }

    function test_if_revert_if_amount_is_zero_while_calling_stakeForCertificate_function()
        public
    {
        vm.expectRevert("Cannot stake 0");
        certificateStaking.stakeForCertificate(0);
    }
    function test_if_revert_if_user_already_staked_while_calling_stakeForCertificate_function()
        public
    {
         mintingController.grantRole(MINTER_ROLE, address(this));
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        mintingController.mint(address(this), 10e18);
        usdgb.approve(address(certificateStaking), 10e18);
        certificateStaking.stakeForCertificate(1e18);
        vm.expectRevert("Already staking");
        certificateStaking.stakeForCertificate(1e18);
    }

    function test_if_user_can_successfully_stakeForCertificate() public {
         mintingController.grantRole(MINTER_ROLE, address(this));
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        mintingController.mint(address(this), 10e18);
        uint256 amount = 1e18;
         usdgb.approve(address(certificateStaking), 10e18);
         (uint256 stakedAmountBefore, uint256 unlockTimeBefore) = certificateStaking.userStakes(
            address(this)
        );
        assertEq(stakedAmountBefore, 0);
        assertEq(unlockTimeBefore, 0);
        vm.expectEmit(address(usdgb));
        emit IERC20.Transfer(address(this), address(certificateStaking), amount);
        certificateStaking.stakeForCertificate(amount);
        (uint256 stakedAmount, uint256 unlockTime) = certificateStaking.userStakes(
            address(this)
        );
        assertEq(stakedAmount, amount);
        assertEq(unlockTime, block.timestamp + 365 days);
    }

     function test_if_revert_if_paused_while_calling_withdraw_function()
        public
    {
        certificateStaking.pause();
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        certificateStaking.withdraw();
    }

    function test_if_revert_if_not_staked_while_calling_withdraw_function()
        public
    {
        vm.expectRevert("No stake found");
        certificateStaking.withdraw();
    }

    function test_if_revert_if_stake_time_is_not_completed_while_calling_withdraw_function()
        public
    {
         mintingController.grantRole(MINTER_ROLE, address(this));
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        mintingController.mint(address(this), 10e18);
        usdgb.approve(address(certificateStaking), 10e18);
        certificateStaking.stakeForCertificate(1e18);
        skip(15 days);
        vm.expectRevert("Stake is locked");
        certificateStaking.withdraw();
    }

    function test_if_user_can_successfully_call_withdraw_function_of_stakeForCertificate() public {
         mintingController.grantRole(MINTER_ROLE, address(this));
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        mintingController.mint(address(this), 10e18);
        uint256 amount = 1e18;
         usdgb.approve(address(certificateStaking), 10e18);
        certificateStaking.stakeForCertificate(amount);
        skip(366 days);
        uint256 balanceBefore = usdgb.balanceOf(address(this));
        vm.expectEmit(address(usdgb));
        emit IERC20.Transfer(address(certificateStaking), address(this), amount);
        certificateStaking.withdraw();
        uint256 balanceAfter = usdgb.balanceOf(address(this));
        assertEq(balanceAfter - balanceBefore, amount);
    }

    function test_if_return_false_if_user_is_not_eligible_for_leverage() public view {
        (bool isEligible, uint256 levrageAmount) = certificateStaking.getLeverageEligibility(
            address(this)
        );
        assertEq(isEligible, false);
        assertEq(levrageAmount, 0);
    }
    function test_if_return_true_if_user_is__eligible_for_leverage() public {
         mintingController.grantRole(MINTER_ROLE, address(this));
        usdgb.grantRole(MINTER_ROLE, address(mintingController));
        mintingController.mint(address(this), 10e18);
        uint256 amount = 1e18;
         usdgb.approve(address(certificateStaking), 10e18);
        certificateStaking.stakeForCertificate(amount);
       (bool isEligible, uint256 levrageAmount) = certificateStaking.getLeverageEligibility(
            address(this)
        );
        assertEq(isEligible, true);
        assertEq(levrageAmount, amount * 3);
    }

    function test_if_revert_if_non_admin_calls_addLender_function() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                prankWallet,
                DEFAULT_ADMIN_ROLE
            )
        );
        certificateStaking.addLender(address(10));
        vm.stopPrank();
    }

    function test_if_admin_can_successfully_call_addLender_function() public {
        certificateStaking.addLender(address(10));
        bool isLender = certificateStaking.approvedLenders(address(10));
        assertEq(isLender, true);
    }
    function test_if_revert_if_non_admin_calls_removeLender_function() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                prankWallet,
                DEFAULT_ADMIN_ROLE
            )
        );
        certificateStaking.removeLender(address(10));
        vm.stopPrank();
    }

    function test_if_admin_can_successfully_call_removeLender_function() public {
        certificateStaking.addLender(address(10));
        bool isLender = certificateStaking.approvedLenders(address(10));
        assertEq(isLender, true);
        certificateStaking.removeLender(address(10));
        bool isLenderAfter = certificateStaking.approvedLenders(address(10));
        assertEq(isLenderAfter, false);
    }

    function test_if_revert_if_non_admin_call_pause_function_of_certificateStaking() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     IAccessControl.AccessControlUnauthorizedAccount.selector,
            //     prankWallet,
            //     PAUSER_ROLE
            // )
        );
        certificateStaking.pause();
        vm.stopPrank();
    }

    function test_if_admin_can_successfully_call_pause_function_of_certificateStaking() public {
        certificateStaking.grantRole(PAUSER_ROLE, address(this));
        certificateStaking.pause();
        assertEq(certificateStaking.paused(), true);
    }
    function test_if_revert_if_non_admin_call_unpause_function_of_certificateStaking() public {
        vm.startPrank(prankWallet);
        vm.expectRevert(
            // abi.encodeWithSelector(
            //     IAccessControl.AccessControlUnauthorizedAccount.selector,
            //     prankWallet,
            //     PAUSER_ROLE
            // )
        );
        certificateStaking.unpause();
        vm.stopPrank();
    }

    function test_if_admin_can_successfully_call_unpause_function_of_certificateStaking() public {
        certificateStaking.grantRole(PAUSER_ROLE, address(this));
        certificateStaking.pause();
        certificateStaking.unpause();
        assertEq(certificateStaking.paused(), false);
    }

}
