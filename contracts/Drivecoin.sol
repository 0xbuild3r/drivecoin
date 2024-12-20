// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DriveCoin is ERC20 {

    constructor() ERC20("DriveCoin", "DRIVE") {
        _mint(msg.sender, 1000000 * 10 ** 18); // Initial supply
    }


    // Mint new tokens (restricted to CoinManager)
    function mint(address to, uint256 amount) external  {
        _mint(to, amount);
    }

    // Burn tokens (restricted to CoinManager)
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract StakingPool is Ownable {
    DriveCoin public driveCoin;
    address public coinManager;
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public rewards;

    event Staked(address indexed carOwner, uint256 amount);
    event RewardIssued(address indexed carOwner, uint256 amount);

    constructor(DriveCoin _driveCoin, address _coinManager) Ownable(_coinManager) {
        driveCoin = _driveCoin;
        coinManager = _coinManager;
    }

    modifier onlyCoinManager() {
        require(msg.sender == coinManager, "Not authorized");
        _;
    }

    // Car owners can stake DriveCoin
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(driveCoin.transferFrom(msg.sender, address(this), amount), "Stake failed");

        stakes[msg.sender] += amount;
        emit Staked(msg.sender, amount);
    }

    // Called by CoinManager to reward staked car owners
    function reward(address carOwner, uint256 amount) external onlyCoinManager {
        require(stakes[carOwner] > 0, "Car owner has no stake");
        rewards[carOwner] += amount;
        driveCoin.mint(carOwner, amount); // Mint reward tokens directly to the car owner
        emit RewardIssued(carOwner, amount);
    }

    // Function to reduce stake (used by CoinManager for burnFromStake)
    function reduceStake(address carOwner, uint256 amount) external onlyCoinManager {
        require(stakes[carOwner] >= amount, "Insufficient stake to burn");
        stakes[carOwner] -= amount;
    }
}

contract CoinManager is Ownable {
    DriveCoin public driveCoin;
    StakingPool public stakingPool;
    address public government;

    event BurnFromStake(address indexed carOwner, uint256 amount);
    event CarRewarded(address indexed carOwner, uint256 amount);
    event UserRewarded(address indexed user, uint256 amount);

    constructor(DriveCoin _driveCoin, address _government) Ownable(msg.sender) {
        driveCoin = _driveCoin;
        government = _government;

        // Deploy StakingPool with CoinManager as the owner
        stakingPool = new StakingPool(driveCoin, address(this));
    }

    modifier onlyGovernment() {
        require(msg.sender == government, "Only government can call this function");
        _;
    }

    // Burns tokens from a staked car owner, called by government
    function burnFromStake(address carOwner, uint256 amount) external onlyGovernment {
        stakingPool.reduceStake(carOwner, amount); // Reduce stake in StakingPool
        driveCoin.burn(address(stakingPool), amount); // Burn tokens from the staking pool contract
        emit BurnFromStake(carOwner, amount);
    }

    // Rewards car owners, incentivizing off-peak or idle behavior
    function rewardCar(address carOwner, uint256 amount) external onlyGovernment {
        stakingPool.reward(carOwner, amount);
        emit CarRewarded(carOwner, amount);
    }

    // Rewards users for public transportation usage at peak times
    function rewardUser(address user, uint256 amount) external onlyGovernment {
        driveCoin.mint(user, amount); // Mint tokens directly to the user
        emit UserRewarded(user, amount);
    }

    // Allows owner to set a new government address if needed
    function setGovernment(address _newGovernment) external onlyOwner {
        government = _newGovernment;
    }
}
