// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// =================================================================================================
// ||                                                                                             ||
// ||                      START: GOLDBACKBOND (USDGB) TOKEN CONTRACT                             ||
// ||                                                                                             ||
// =================================================================================================

// --- OpenZeppelin Dependencies for GOLDBACKBOND ---
abstract contract Context_GBB {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}
interface IERC165_GBB {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
abstract contract ERC165_GBB is IERC165_GBB {
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return interfaceId == type(IERC165_GBB).interfaceId;
    }
}
interface IAccessControl_GBB {
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
}
abstract contract ReentrancyGuard_GBB {
    uint256 private _status;
    constructor() {
        _status = 1;
    } // _NOT_ENTERED
    modifier nonReentrant() {
        require(_status != 2, "ReentrancyGuard: reentrant call");
        _status = 2;
        _;
        _status = 1;
    } // 2 = _ENTERED
}
abstract contract AccessControl_GBB is
    Context_GBB,
    IAccessControl_GBB,
    ERC165_GBB
{
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }
    mapping(bytes32 => RoleData) private _roles;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IAccessControl_GBB).interfaceId ||
            super.supportsInterface(interfaceId);
    }
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }
    function _checkRole(bytes32 role) internal view virtual {
        require(
            hasRole(role, _msgSender()),
            "AccessControl: account is missing role"
        );
    }
    function getRoleAdmin(
        bytes32 role
    ) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }
    function grantRole(
        bytes32 role,
        address account
    ) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }
    function revokeRole(
        bytes32 role,
        address account
    ) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
    function renounceRole(
        bytes32 role,
        address callerConfirmation
    ) public virtual override {
        require(
            callerConfirmation == _msgSender(),
            "AccessControl: can only renounce roles for self"
        );
        _revokeRole(role, callerConfirmation);
    }
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}
// --- LayerZero V2 & ERC20 Dependencies ---
interface ILayerZeroEndpointV2_GBB {
    function send(
        address receiver,
        bytes calldata message,
        bytes calldata options
    ) external payable;
}
interface IERC20_GBB {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}
interface IERC20Metadata_GBB is IERC20_GBB {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
abstract contract OFT_GBB {
    address internal immutable lzEndpoint;
    address internal immutable delegate;
    constructor(address _lzEndpoint, address _delegate) {
        lzEndpoint = _lzEndpoint;
        delegate = _delegate;
    }
    function _debit(address from, uint256 amount) internal virtual;
    function _credit(address to, uint256 amount) internal virtual;
}

// --------------------------- GOLDBACKBOND (USDGB) CONTRACT ---------------------------
contract GOLDBACKBOND is
    OFT_GBB,
    AccessControl_GBB,
    IERC20Metadata_GBB,
    ReentrancyGuard_GBB
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public usdcaInsuranceFund;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    event InsuranceFundUpdated(address indexed newFundAddress);

    constructor(
        address lzEndpointAddress,
        address delegateAddress
    ) OFT_GBB(lzEndpointAddress, delegateAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, delegateAddress);
        _grantRole(ADMIN_ROLE, delegateAddress);
        _name = "Goldbackbond";
        _symbol = "USDGB";
    }

    // ERC20 Views
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function decimals() public pure virtual returns (uint8) {
        return 18;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    // ERC20 Functions
    function transfer(
        address to,
        uint256 value
    ) public virtual override returns (bool) {
        _transfer(_msgSender(), to, value);
        return true;
    }
    function approve(
        address spender,
        uint256 value
    ) public virtual override returns (bool) {
        _approve(_msgSender(), spender, value);
        return true;
    }
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual override returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        _transfer(from, to, value);
        return true;
    }

    // Supply Control
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    // Admin Functions
    function setUsdcaInsuranceFund(
        address fundAddress
    ) external onlyRole(ADMIN_ROLE) {
        // --- PATCH: Added zero-address check (from Slither report) ---
        require(fundAddress != address(0), "Guardian: Address cannot be zero");
        usdcaInsuranceFund = fundAddress;
        emit InsuranceFundUpdated(fundAddress);
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
    function withdrawEther() external onlyRole(ADMIN_ROLE) nonReentrant {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "ETH transfer failed");
    }

    // LayerZero OFT Implementation
    function _debit(address from, uint256 amount) internal override {
        _burn(from, amount);
    }
    function _credit(address to, uint256 amount) internal override {
        _mint(to, amount);
    }

    // Internal Logic
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "ERC20: transfer from zero");
        require(to != address(0), "ERC20: transfer to zero");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "ERC20: insufficient balance");
        unchecked {
            _balances[from] = fromBalance - value;
        }
        _balances[to] += value;
        emit Transfer(from, to, value);
    }
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to zero");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from zero");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from zero");
        require(spender != address(0), "ERC20: approve to zero");
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - value);
            }
        }
    }
}
