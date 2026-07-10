// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AssetRegistry {
    //////////////////
    //// ERRORS ////
    /////////////////

    error AssetRegistry__NotOwner();
    error AssetRegistry__NotTimelock();
    error AssetRegistry__NotGuardian();

    error AssetRegistry__RegistryPaused();
    error AssetRegistry__AlreadyPaused();
    error AssetRegistry__NotPaused();

    error AssetRegistry__AssetAlreadyRegistered();
    error AssetRegistry__AssetNotRegistered();

    error AssetRegistry__AssetAlreadyEnabled();
    error AssetRegistry__AssetAlreadyDisabled();

    error AssetRegistry__InvalidAsset();
    error AssetRegistry__InvalidDecimals();
    error AssetRegistry__InvalidAssetType();
    error AssetRegistry__ValueUnchanged();

    error AssetRegistry__InvalidTimelock();
    error AssetRegistry__InvalidGuardian();
    error AssetRegistry__InvalidOwner();

    /////////////////
    //// EVENT ////
    ////////////////

    event AssetRegistered(address indexed asset, AssetType assetType, uint8 decimals);

    event AssetUpdated(address indexed asset, AssetType oldType, AssetType newType);

    event AssetEnabled(address indexed asset);

    event AssetDisabled(address indexed asset, address indexed by);

    event AssetDelisted(address indexed asset);

    event RegistryPaused(address indexed by);

    event RegistryUnpaused(address indexed by);

    event TimelockUpdated(address indexed oldTimelock, address indexed newTimelock);

    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);

    ////////////////
    //// ENUM ////
    ///////////////

    enum AssetType {
        None,
        CollateralOnly,
        BorrowableOnly,
        CollateralAndBorrowable
    }

    //////////////////
    //// STRUCT ////
    //////////////////

    struct AssetConfig {
        uint8 decimals;
        AssetType assetType;
        bool enabled;
    }

    /////////////////////
    //// VARIABLES ////
    ////////////////////

    uint256 public assetCount;
    address public owner;
    address public pendingOwner;
    address public timelock;
    address public guardian;
    bool public registryPaused;

    ///////////////////
    //// MAPPING ////
    //////////////////

    mapping(address => AssetConfig) public assets;
    mapping(address => bool) public isRegistered;

    /////////////////
    //// ARRAY ////
    ////////////////

    address[] public assetList;

    /////////////////////
    //// MODIFIERS ////
    ////////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) revert AssetRegistry__NotOwner();
        _;
    }

    modifier onlyTimelock() {
        if (msg.sender != timelock) revert AssetRegistry__NotTimelock();
        _;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert AssetRegistry__NotGuardian();
        _;
    }

    modifier whenNotPaused() {
        if (registryPaused) revert AssetRegistry__RegistryPaused();
        _;
    }

    ///////////////////////
    //// CONSTRUCTOR ////
    //////////////////////

    constructor(address _timelock, address _guardian) {
        if (_timelock == address(0)) revert AssetRegistry__InvalidTimelock();
        if (_guardian == address(0)) revert AssetRegistry__InvalidGuardian();

        timelock = _timelock;
        guardian = _guardian;

        owner = msg.sender;
    }

    /////////////////////////////
    //// EXTERNAL FUNCTION ////
    ////////////////////////////

    function registerAsset(address asset, AssetType assetType, uint8 decimals) external whenNotPaused onlyTimelock {
        if (asset == address(0)) revert AssetRegistry__InvalidAsset();

        if (assetType == AssetType.None) {
            revert AssetRegistry__InvalidAssetType();
        }

        if (decimals < 6 || decimals > 18) {
            revert AssetRegistry__InvalidDecimals();
        }

        if (isRegistered[asset]) revert AssetRegistry__AssetAlreadyRegistered();

        isRegistered[asset] = true;

        AssetConfig memory config = AssetConfig({decimals: decimals, assetType: assetType, enabled: false});

        assets[asset] = config;

        assetList.push(asset);

        assetCount++;

        emit AssetRegistered(asset, assetType, decimals);
    }

    function updateAsset(address asset, AssetType newType) external whenNotPaused onlyTimelock {
        if (!isRegistered[asset]) revert AssetRegistry__AssetNotRegistered();

        if (newType == AssetType.None) revert AssetRegistry__InvalidAssetType();

        AssetType oldType = assets[asset].assetType;

        if (oldType == newType) revert AssetRegistry__ValueUnchanged();

        assets[asset].assetType = newType;

        emit AssetUpdated(asset, oldType, newType);
    }

    function enableAsset(address asset) external onlyTimelock whenNotPaused {
        if (!isRegistered[asset]) revert AssetRegistry__AssetNotRegistered();

        if (assets[asset].enabled) revert AssetRegistry__AssetAlreadyEnabled();

        assets[asset].enabled = true;

        emit AssetEnabled(asset);
    }

    function disableAsset(address asset) external onlyGuardian {
        if (!isRegistered[asset]) revert AssetRegistry__AssetNotRegistered();

        if (!assets[asset].enabled) {
            revert AssetRegistry__AssetAlreadyDisabled();
        }

        assets[asset].enabled = false;

        emit AssetDisabled(asset, msg.sender);
    }

    function delistAsset(address asset) external onlyTimelock whenNotPaused {
        if (!isRegistered[asset]) revert AssetRegistry__AssetNotRegistered();

        for (uint256 i = 0; i < assetList.length; i++) {
            if (assetList[i] == asset) {
                assetList[i] = assetList[assetList.length - 1];
                assetList.pop();
                break;
            }
        }

        delete assets[asset];
        isRegistered[asset] = false;
        assetCount--;

        emit AssetDelisted(asset);
    }

    /////////////////////////////////////
    //// PAUSE & UNPAUSE FUNCTIONS ////
    ////////////////////////////////////

    function pauseRegistry() external onlyGuardian {
        if (registryPaused) revert AssetRegistry__AlreadyPaused();

        registryPaused = true;

        emit RegistryPaused(msg.sender);
    }

    function unpauseRegistry() external onlyGuardian {
        if (!registryPaused) revert AssetRegistry__NotPaused();

        registryPaused = false;

        emit RegistryUnpaused(msg.sender);
    }

    /////////////////////
    //// OWNERSHIP ////
    ////////////////////

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert AssetRegistry__InvalidOwner();
        }

        pendingOwner = newOwner;
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert AssetRegistry__NotOwner();

        owner = pendingOwner;
        pendingOwner = address(0);
    }

    function transferGuardian(address newGuardian) external onlyOwner {
        if (newGuardian == address(0)) revert AssetRegistry__InvalidGuardian();

        address oldGuardian = guardian;
        guardian = newGuardian;

        emit GuardianUpdated(oldGuardian, newGuardian);
    }

    function setTimelock(address newTimelock) external onlyOwner {
        if (newTimelock == address(0)) {
            revert AssetRegistry__InvalidTimelock();
        }

        address oldTimelock = timelock;

        timelock = newTimelock;

        emit TimelockUpdated(oldTimelock, newTimelock);
    }
}
