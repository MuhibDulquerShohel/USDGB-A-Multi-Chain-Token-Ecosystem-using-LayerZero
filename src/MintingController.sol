// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IUSDGB {
    function mint(address to, uint256 amount) external;
}

contract USDGBMinting is AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant COMPLIANCE_ADMIN = keccak256("COMPLIANCE_ADMIN");

    IUSDGB public usdgb;

    // LIMITS (Set in constructor)
    uint256 public softLimit;
    uint256 public hardLimit;

    struct PendingTx {
        address user;
        uint256 amount;
        uint256 timestamp;
        bool processed;
    }

    mapping(uint256 => PendingTx) public complianceQueue;
    uint256 public queueNonce;

    event TransactionQueued(
        uint256 indexed txId,
        address indexed user,
        uint256 amount
    );
    event TransactionApproved(
        uint256 indexed txId,
        address indexed user,
        uint256 amount
    );
    event TransactionRejected(uint256 indexed txId, string reason);
    event LimitsUpdated(uint256 newSoftLimit, uint256 newHardLimit);

    constructor(address _usdgb, address _admin) {
        usdgb = IUSDGB(_usdgb);
        // Default Limits: Soft 10k, Hard 1M
        softLimit = 10_000 * 10 ** 18;
        hardLimit = 1_000_000 * 10 ** 18;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(COMPLIANCE_ADMIN, _admin);
    }

    // --- MINTING LOGIC ---
    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(amount < hardLimit, "Exceeds Hard Limit");

        // Green Lane
        if (amount <= softLimit) {
            usdgb.mint(to, amount);
            return;
        }

        // Yellow Lane (Queue)
        uint256 id = queueNonce++;
        complianceQueue[id] = PendingTx({
            user: to,
            amount: amount,
            timestamp: block.timestamp,
            processed: false
        });
        emit TransactionQueued(id, to, amount);
    }

    // --- COMPLIANCE TOOLS ---
    function approveTransaction(
        uint256 txId
    ) external onlyRole(COMPLIANCE_ADMIN) {
        PendingTx storage request = complianceQueue[txId];
        require(!request.processed, "Processed");
        request.processed = true;
        usdgb.mint(request.user, request.amount);
        emit TransactionApproved(txId, request.user, request.amount);
    }

    function rejectTransaction(
        uint256 txId,
        string memory reason
    ) external onlyRole(COMPLIANCE_ADMIN) {
        PendingTx storage request = complianceQueue[txId];
        require(!request.processed, "Processed");
        request.processed = true;
        emit TransactionRejected(txId, reason);
    }

    // --- ADMIN ---
    function setLimits(
        uint256 _soft,
        uint256 _hard
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        softLimit = _soft;
        hardLimit = _hard;
        emit LimitsUpdated(_soft, _hard);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
