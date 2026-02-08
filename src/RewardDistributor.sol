// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* =========================================================
                    INTERFACES
   ========================================================= */

interface IERC20Minimal {
    function balanceOf(address user) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/* =========================================================
                NEBBY REWARD DISTRIBUTOR
   =========================================================
   Responsibilities:
   - Hold BNB allocated for holder rewards
   - Enforce 24h holding requirement
   - Enforce minimum holding threshold (0.01%)
   - Reset eligibility on any token sell
   - Allow eligible holders to claim rewards

   Non-responsibilities:
   - Token transfers
   - Vault fund management
   ========================================================= */

contract RewardDistributor {
    /* =========================================================
                        CONSTANTS
       ========================================================= */

    uint256 public constant HOLD_PERIOD = 24 hours;
    uint256 public constant MIN_BPS = 1; // 0.01% = 1 basis point

    /* =========================================================
                        STATE
       ========================================================= */

    IERC20Minimal public immutable token;

    // Last timestamp when holder became eligible
    mapping(address => uint256) public lastHoldTimestamp;

    // Track claimed rewards (optional but audit-friendly)
    mapping(address => uint256) public totalClaimed;

    /* =========================================================
                        EVENTS
       ========================================================= */

    event EligibilityReset(address indexed user, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 amount);

    /* =========================================================
                        CONSTRUCTOR
       ========================================================= */

    constructor(address _token) {
        require(_token != address(0), "Zero token");
        token = IERC20Minimal(_token);
    }

    /* =========================================================
                    ELIGIBILITY LOGIC
       ========================================================= */

    function isEligible(address user) public view returns (bool) {
        if (lastHoldTimestamp[user] == 0) return false;

        // must hold for 24h
        if (block.timestamp < lastHoldTimestamp[user] + HOLD_PERIOD) {
            return false;
        }

        uint256 balance = token.balanceOf(user);
        uint256 supply = token.totalSupply();

        if (supply == 0) return false;

        // minimum 0.01% holding
        uint256 minRequired = (supply * MIN_BPS) / 10_000;
        if (balance < minRequired) return false;

        return true;
    }

    /* =========================================================
                TOKEN HOOKS (CALLED BY TOKEN)
       =========================================================
       IMPORTANT:
       - Token MUST call these on transfers
       - Any sell or transfer OUT resets timer
       ========================================================= */

    function onTokenReceived(address user) external {
        lastHoldTimestamp[user] = block.timestamp;
    }

    function onTokenSent(address user) external {
        lastHoldTimestamp[user] = block.timestamp;
        emit EligibilityReset(user, block.timestamp);
    }

    /* =========================================================
                    CLAIM LOGIC
       ========================================================= */

    function claim() external {
        require(isEligible(msg.sender), "Not eligible");

        uint256 reward = _calculateReward(msg.sender);
        require(reward > 0, "No rewards");

        totalClaimed[msg.sender] += reward;

        (bool ok,) = msg.sender.call{value: reward}("");
        require(ok, "BNB transfer failed");

        emit RewardClaimed(msg.sender, reward);
    }

    /* =========================================================
                    INTERNAL LOGIC
       ========================================================= */

    function _calculateReward(address user)
        internal
        view
        returns (uint256)
    {
        // Simple proportional model (example)
        uint256 balance = token.balanceOf(user);
        uint256 supply = token.totalSupply();

        return (address(this).balance * balance) / supply;
    }

    /* =========================================================
                    RECEIVE BNB
       ========================================================= */

    receive() external payable {}
}
