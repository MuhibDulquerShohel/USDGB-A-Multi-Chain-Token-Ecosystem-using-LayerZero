// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Chainlink Interface for GoldBonusVault
interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

interface IGOLDBACKBOND is IERC20 {}

// ==========================================
// CONTRACT 1: LP REWARD POOL (Liquidity Rewards)
// ==========================================
contract LpRewardPool is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IGOLDBACKBOND;
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct UserStake {
        uint256 lpAmount;
        uint256 startTime;
        uint256 lastClaimTime;
    }

    IGOLDBACKBOND public immutable GBB_TOKEN;
    IERC20 public immutable LP_TOKEN;
    
    uint256 public immutable LAUNCH_TIME;
    uint256 public constant SECONDS_PER_MONTH = 30 days;
    
    mapping(address => UserStake) public userStakes;
    
    // CHANGED: "APY" to "APR" for compliance
    //[span_0](start_span)//[span_0](end_span) Refers to rate tiers
    uint256[4] public aprTiers = [50, 30, 20, 10]; // APR %

    constructor(address _gbbToken, address _lpToken, address _admin) {
        require(_gbbToken != address(0) && _lpToken != address(0), "Zero address");
        GBB_TOKEN = IGOLDBACKBOND(_gbbToken);
        LP_TOKEN = IERC20(_lpToken);
        LAUNCH_TIME = block.timestamp;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        UserStake storage stakeInfo = userStakes[msg.sender];

        _claimReward(msg.sender); // Claim pending before restaking

        LP_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        stakeInfo.lpAmount += amount;
        
        if (stakeInfo.startTime == 0) {
            stakeInfo.startTime = block.timestamp;
        }
        stakeInfo.lastClaimTime = block.timestamp;
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        UserStake storage stakeInfo = userStakes[msg.sender];
        require(amount > 0 && stakeInfo.lpAmount >= amount, "Insufficient stake");

        _claimReward(msg.sender);

        stakeInfo.lpAmount -= amount;
        LP_TOKEN.safeTransfer(msg.sender, amount);

        if (stakeInfo.lpAmount == 0) {
            delete userStakes[msg.sender];
        }
    }

    function claimReward() external nonReentrant whenNotPaused {
        _claimReward(msg.sender);
    }

    // CHANGED: "APY" logic to "APR"
    function calculateReward(address user) public view returns (uint256) {
        UserStake memory stakeInfo = userStakes[user];
        if (stakeInfo.lpAmount == 0) return 0;

        uint256 timeSinceLaunch = block.timestamp - LAUNCH_TIME;
        uint256 currentMonthIndex = timeSinceLaunch / SECONDS_PER_MONTH;
        //[span_1](start_span)//[span_1](end_span) Selecting rate based on time
        uint256 apr = (currentMonthIndex >= 3) ? aprTiers[3] : aprTiers[currentMonthIndex];
        
        uint256 timeElapsed = block.timestamp - stakeInfo.lastClaimTime;
        // Reward = (staked * APR * time) / (365 days * 100)
        return (stakeInfo.lpAmount * apr * timeElapsed) / (365 days * 100);
    }

    function _claimReward(address user) internal {
        uint256 reward = calculateReward(user);
        if (reward > 0) {
            require(reward <= GBB_TOKEN.balanceOf(address(this)), "Reward pool empty");
            userStakes[user].lastClaimTime = block.timestamp;
            GBB_TOKEN.safeTransfer(user, reward);
        }
    }

    // --- Guardian Controls ---
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}

// ==========================================
// CONTRACT 2: GOLD BONUS VAULT (Oracle)
// ==========================================
contract GoldBonusVault is AccessControl, Pausable {
    using SafeERC20 for IGOLDBACKBOND;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IGOLDBACKBOND public immutable GBB_TOKEN;
    LpRewardPool public immutable LP_REWARD_POOL;
    AggregatorV3Interface internal immutable PRICE_FEED;

    uint256 public baselineGoldPrice;
    
    // CHANGED: Cap logic to APR
    //[span_2](start_span)//[span_2](end_span) 15% Max APR bonus
    uint256 public constant BONUS_CAP = 15; 

    event BonusDistributed(address indexed user, uint256 amount);

    constructor(address _gbbToken, address _lpRewardPool, address _priceFeed, address _admin) {
        GBB_TOKEN = IGOLDBACKBOND(_gbbToken);
        LP_REWARD_POOL = LpRewardPool(_lpRewardPool);
        PRICE_FEED = AggregatorV3Interface(_priceFeed);
        
        (, int256 price,,,) = PRICE_FEED.latestRoundData();
        baselineGoldPrice = uint256(price);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    function getLatestGoldPrice() public view returns (uint256) {
        (, int256 price,,,) = PRICE_FEED.latestRoundData();
        return uint256(price);
    }

    // CHANGED: Fully implemented distribution logic (replacing comment)
    // NOTE: This processes a batch of users. If the list is huge, call this in chunks (e.g., 50 users at a time).
    function distributeBonus(address[] calldata users) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        uint256 currentPrice = getLatestGoldPrice();
        if (currentPrice <= baselineGoldPrice) return;

        uint256 percentIncrease = ((currentPrice - baselineGoldPrice) * 100) / baselineGoldPrice;
        
        //[span_3](start_span)// CHANGED: APY to APR[span_3](end_span)
        uint256 bonusApr = (percentIncrease / 5) * 3; 
        if (bonusApr > BONUS_CAP) bonusApr = BONUS_CAP;
        
        // Safety check
        if (bonusApr == 0) return;

        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            
            // Read stake directly from the other contract
            (uint256 stakedAmount, , ) = LP_REWARD_POOL.userStakes(user);

            if (stakedAmount > 0) {
                // Calculate 1 month worth of the Bonus APR
                // Formula: (Stake * APR * 30 days) / (365 days * 100)
                uint256 bonusAmount = (stakedAmount * bonusApr * 30 days) / (365 days * 100);

                if (bonusAmount > 0 && GBB_TOKEN.balanceOf(address(this)) >= bonusAmount) {
                    GBB_TOKEN.safeTransfer(user, bonusAmount);
                    emit BonusDistributed(user, bonusAmount);
                }
            }
        }
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}

// ==========================================
// CONTRACT 3: CERTIFICATE STAKING (Lockup)
// ==========================================
contract CertificateStaking is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IGOLDBACKBOND;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IGOLDBACKBOND public immutable GBB_TOKEN;

    struct Stake {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => Stake) public userStakes;
    mapping(address => bool) public approvedLenders;

    constructor(address _gbbToken, address _admin) {
        GBB_TOKEN = IGOLDBACKBOND(_gbbToken);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
    }

    function stakeForCertificate(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        require(userStakes[msg.sender].amount == 0, "Already staking");

        GBB_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        
        userStakes[msg.sender] = Stake({
            amount: amount,
            unlockTime: block.timestamp + 365 days
        });
    }

    function withdraw() external nonReentrant whenNotPaused {
        Stake memory stakeInfo = userStakes[msg.sender];
        require(stakeInfo.amount > 0, "No stake found");
        require(block.timestamp >= stakeInfo.unlockTime, "Stake is locked");

        delete userStakes[msg.sender];
        GBB_TOKEN.safeTransfer(msg.sender, stakeInfo.amount);
    }

    // Returns leverage value (3x) for lending protocols
    function getLeverageEligibility(address user) external view returns (bool isEligible, uint256 leverageValue) {
        Stake memory stakeInfo = userStakes[user];
        if (stakeInfo.amount > 0) {
            // Logic assumes collateral is valid for leverage as long as it exists in the contract
            //[span_4](start_span)//[span_4](end_span) Returns 3x leverage value
            return (true, stakeInfo.amount * 3);
        }
        return (false, 0);
    }
    
    // --- Admin / Guardian ---
    function addLender(address lender) external onlyRole(DEFAULT_ADMIN_ROLE) {
        approvedLenders[lender] = true;
    }

    function removeLender(address lender) external onlyRole(DEFAULT_ADMIN_ROLE) {
        approvedLenders[lender] = false;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
