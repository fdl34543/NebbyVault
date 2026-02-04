// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {VaultBase} from "./interfaces/VaultBase.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IRouter {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

contract NebbyTaxVault is VaultBase {
    /* =========================
            CONSTANTS
    ========================== */

    address public constant DEAD =
        0x000000000000000000000000000000000000dEaD;

    uint256 public constant BUYBACK_SHARE = 80; // %
    uint256 public constant RESERVE_SHARE = 20; // %

    // buyback breakdown (from 80%)
    uint256 public constant BURN_SHARE = 20;
    uint256 public constant HOLDER_REWARD_SHARE = 40;
    uint256 public constant PLATFORM_REWARD_SHARE = 20;

    /* =========================
            IMMUTABLES
    ========================== */

    address public immutable nebbyToken;
    address public immutable rewardDistributor;
    address public immutable platformWallet;
    address public immutable router;
    address public immutable WBNB;

    /* =========================
            ROLES
    ========================== */

    address public operator;

    /* =========================
            STATS
    ========================== */

    uint256 public totalReceivedBNB;
    uint256 public totalBuybackBNB;
    uint256 public totalBurnBNB;
    uint256 public totalRewardBNB;
    uint256 public totalPlatformBNB;

    /* =========================
            EVENTS
    ========================== */

    event BNBReceived(uint256 amount);
    event BuybackExecuted(uint256 amountBNB);
    event OperatorUpdated(address operator);

    /* =========================
            CONSTRUCTOR
    ========================== */

    constructor(
        address _nebbyToken,
        address _rewardDistributor,
        address _platformWallet,
        address _router,
        address _wbnb,
        address _operator
    ) {
        nebbyToken = _nebbyToken;
        rewardDistributor = _rewardDistributor;
        platformWallet = _platformWallet;
        router = _router;
        WBNB = _wbnb;
        operator = _operator;
    }

    /* =========================
            RECEIVE TAX
    ========================== */

    receive() external payable {
        totalReceivedBNB += msg.value;
        emit BNBReceived(msg.value);
    }

    /* =========================
            BUYBACK ENGINE
    ========================== */

    function executeBuyback(uint256 amountBNB)
        external
        onlyOperatorOrGuardian
    {
        require(amountBNB <= address(this).balance, "Insufficient balance");

        uint256 buybackAmount = (amountBNB * BUYBACK_SHARE) / 100;
        uint256 reserveAmount = amountBNB - buybackAmount;

        // ---- split buyback engine ----
        uint256 burnAmount =
            (buybackAmount * BURN_SHARE) / 100;

        uint256 rewardAmount =
            (buybackAmount * HOLDER_REWARD_SHARE) / 100;

        uint256 platformAmount =
            (buybackAmount * PLATFORM_REWARD_SHARE) / 100;

        // ---- burn ----
        _swapBNBForToken(burnAmount, DEAD);
        totalBurnBNB += burnAmount;

        // ---- holder rewards ----
        (bool ok1,) = rewardDistributor.call{value: rewardAmount}("");
        require(ok1, "Reward transfer failed");
        totalRewardBNB += rewardAmount;

        // ---- platform rewards ----
        (bool ok2,) = platformWallet.call{value: platformAmount}("");
        require(ok2, "Platform transfer failed");
        totalPlatformBNB += platformAmount;

        totalBuybackBNB += buybackAmount;

        // reserveAmount stays in vault (strategic reserve)

        emit BuybackExecuted(amountBNB);
    }

    function _swapBNBForToken(uint256 amount, address to) internal {
        address[] memory path = new address[](2);

        path[0] = WBNB;
        path[1] = nebbyToken;

        IRouter(router)
            .swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
                0,
                path,
                to,
                block.timestamp
            );
    }

    /* =========================
            ADMIN
    ========================== */

    function setOperator(address _operator)
        external
        onlyOperatorOrGuardian
    {
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    modifier onlyOperatorOrGuardian() {
        require(
            msg.sender == operator || msg.sender == _getGuardian(),
            "Not authorized"
        );
        _;
    }

    /* =========================
            FLAP UI
    ========================== */

    /* ========= TEST / VIEW HELPERS ========= */

    function guardian() public view returns (address) {
        return _getGuardian();
    }

    function description() public view override returns (string memory) {
        uint256 bal = address(this).balance / 1e14;

        return string(
            abi.encodePacked(
                "Nebby Tax Vault. ",
                "100% of token tax (5% buy / 5% sell) and 1% platform fee are routed here. ",
                "80% is processed by an automated buyback engine: ",
                "20% burned, 40% distributed to eligible long-term holders ",
                "(minimum 24h holding and >=0.01% supply), ",
                "20% allocated to platform incentives. ",
                "Remaining 20% held as strategic reserves. ",
                "Current vault balance: ",
                _toString(bal / 10000),
                ".",
                _padZeros(_toString(bal % 10000), 4),
                " BNB."
            )
        );
    }

    /* =========================
            UTILS
    ========================== */

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _padZeros(string memory str, uint256 len)
        internal
        pure
        returns (string memory)
    {
        bytes memory b = bytes(str);
        if (b.length >= len) return str;

        bytes memory out = new bytes(len);
        uint256 diff = len - b.length;

        for (uint256 i = 0; i < diff; i++) out[i] = "0";
        for (uint256 i = 0; i < b.length; i++) out[diff + i] = b[i];

        return string(out);
    }

}

