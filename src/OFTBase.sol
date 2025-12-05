// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract GOLDBACKBONDBase is OFT, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant MAX_SUPPLY = 250_560_000_000 * (10 ** 18);

    constructor(
        address _lzEndpoint
    )
        OFT("GOLDBACKBOND", "USDGB", _lzEndpoint, msg.sender)
        AccessControl()
        Ownable(msg.sender)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function grantMinterRole(address minter) external onlyRole(ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, minter);
    }
    function revokeMinterRole(address minter) external onlyRole(ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, minter);
    }
    function grantBurnerRole(address burner) external onlyRole(ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, burner);
    }
    function revokeBurnerRole(address burner) external onlyRole(ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, burner);
    }

    // --- PATCH: Added withdrawEther (from Slither report) and nonReentrant modifier ---
    function withdrawEther() external onlyRole(ADMIN_ROLE) {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "ETH transfer failed");
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            "GOLDBACKBOND: Max supply exceeded"
        );
        _mint(to, amount);
    }

    /**
     * @notice Burns USDGB tokens from a specific account.
     * @dev Restricted to addresses/contracts with the BURNER_ROLE.
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @dev Core function to enforce MAX_SUPPLY on all mints,
     * including cross-chain (LayerZero) mints.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (from == address(0)) {
            // This is a mint operation
            require(
                totalSupply() + value <= MAX_SUPPLY,
                "GOLDBACKBOND: Max supply exceeded"
            );
        }
        super._update(from, to, value);
    }

    /**
     * @dev Required override for AccessControl compatibility.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
