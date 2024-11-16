// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DriveCoin is ERC20, Ownable {
    constructor() ERC20("DriveCoin", "DRIVE") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** 18); // Initial supply
    }

    // Mint new tokens (restricted to owner, typically CoinManager)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Burn tokens (restricted to owner, typically CoinManager)
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}

contract StakingPool is Ownable {
    DriveCoin public driveCoin;
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public rewards;

    uint256 public myUint256Var; // Bitkub Next variable
    address public myAddressVar; // Bitkub Next variable

    event Staked(address indexed carOwner, uint256 amount);
    event RewardIssued(address indexed carOwner, uint256 amount);
    event VariablesUpdated(uint256 myUint256Var, address myAddressVar);

    constructor(DriveCoin _driveCoin) Ownable(msg.sender) {
        driveCoin = _driveCoin;
    }

    // Car owners can stake DriveCoin
    function stake(uint256 amount, uint256 var_, address bitkubNext_) external {
        require(amount > 0, "Amount must be greater than zero");
        require(driveCoin.transferFrom(msg.sender, address(this), amount), "Stake failed");

        stakes[msg.sender] += amount;
        myUint256Var = var_;
        myAddressVar = bitkubNext_;
        emit VariablesUpdated(var_, bitkubNext_);
        emit Staked(msg.sender, amount);
    }

    // Called by CoinManager to reward staked car owners
    function reward(address carOwner, uint256 amount, uint256 var_, address bitkubNext_) external onlyOwner {
        require(stakes[carOwner] > 0, "Car owner has no stake");
        
        rewards[carOwner] += amount;
        driveCoin.mint(carOwner, amount); // Mint reward tokens directly to the car owner
        
        // Update Bitkub Next variables
        myUint256Var = var_;
        myAddressVar = bitkubNext_;
        emit VariablesUpdated(var_, bitkubNext_);
        emit RewardIssued(carOwner, amount);
    }

    // Function to reduce stake (used by CoinManager for burnFromStake)
    function reduceStake(address carOwner, uint256 amount) external onlyOwner {
        require(stakes[carOwner] >= amount, "Insufficient stake to burn");
        stakes[carOwner] -= amount;
    }
}

contract CoinManager is Ownable {
    DriveCoin public driveCoin;
    StakingPool public stakingPool;
    address public government;

    uint256 public myUint256Var; // Bitkub Next variable
    address public myAddressVar; // Bitkub Next variable

    event BurnFromStake(address indexed carOwner, uint256 amount);
    event CarRewarded(address indexed carOwner, uint256 amount);
    event UserRewarded(address indexed user, uint256 amount);
    event VariablesUpdated(uint256 myUint256Var, address myAddressVar);

    constructor(DriveCoin _driveCoin, StakingPool _stakingPool, address _government) Ownable(msg.sender) {
        driveCoin = _driveCoin;
        stakingPool = _stakingPool;
        government = _government;
    }

    modifier onlyGovernment() {
        require(msg.sender == government, "Only government can call this function");
        _;
    }

    // Burns tokens from a staked car owner, called by government
    function burnFromStake(address carOwner, uint256 amount, uint256 var_, address bitkubNext_) external onlyGovernment {
        stakingPool.reduceStake(carOwner, amount); // Reduce stake in StakingPool
        driveCoin.burn(address(stakingPool), amount); // Burn tokens from the staking pool contract
        
        // Update Bitkub Next variables
        myUint256Var = var_;
        myAddressVar = bitkubNext_;
        emit VariablesUpdated(var_, bitkubNext_);
        emit BurnFromStake(carOwner, amount);
    }

    // Rewards car owners, incentivizing off-peak or idle behavior
    function rewardCar(address carOwner, uint256 amount, uint256 var_, address bitkubNext_) external onlyGovernment {
        stakingPool.reward(carOwner, amount, var_, bitkubNext_);
        emit CarRewarded(carOwner, amount);
    }

    // Rewards users for public transportation usage at peak times
    function rewardUser(address user, uint256 amount, uint256 var_, address bitkubNext_) external onlyGovernment {
        driveCoin.mint(user, amount); // Mint tokens directly to the user
        
        // Update Bitkub Next variables
        myUint256Var = var_;
        myAddressVar = bitkubNext_;
        emit VariablesUpdated(var_, bitkubNext_);
        emit UserRewarded(user, amount);
    }

    // Allows owner to set a new government address if needed
    function setGovernment(address _newGovernment) external onlyOwner {
        government = _newGovernment;
    }
}
