// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NebbyTaxVault.sol";
import "./mocks/MockRouter.sol";

/* =========================================================
                    NEBBY TAX VAULT TEST SUITE
   =========================================================
   This test suite validates the Nebby Flap-compatible vault.

   Scope:
   - Vault basic functionality
   - Buyback execution success path
   - Operator & Guardian access control
   - Unauthorized access protection
   - Flap UI requirements (description)

   Out of scope:
   - Holder reward eligibility (24h rule)
   - Token transfer logic
   - Reward distribution logic
   ========================================================= */

contract NebbyTaxVaultTest is Test {
    /* =========================================================
                        STATE VARIABLES
       ========================================================= */

    NebbyTaxVault vault;
    MockRouter router;

    // Roles
    address operator = address(0x1111);
    address rewardDistributor = address(0x2222);
    address platformWallet = address(0x3333);

    // Dummy external dependencies
    address nebbyToken = address(0xAAAA);
    address wbnb = address(0xCCCC);

    /* =========================================================
                            SETUP
       =========================================================
       Purpose:
       - Prepare a clean test environment before each test
       - Simulate a Flap-supported chain (BNB Testnet)
       - Deploy MockRouter and Vault with dummy dependencies

       Validates:
       - Vault deployment does not revert
       - ChainId-dependent logic (Guardian / Portal) works
       ========================================================= */

    function setUp() public {
        // Simulate BNB Testnet (Flap supported chain)
        vm.chainId(97);

        router = new MockRouter();

        vault = new NebbyTaxVault(
            nebbyToken,
            rewardDistributor,
            platformWallet,
            address(router),
            wbnb,
            operator
        );

        console.log("Vault deployed at:", address(vault));
        console.log("MockRouter deployed at:", address(router));
        console.log("ChainId:", block.chainid);
    }

    /* =========================================================
                BASIC VAULT FUNCTIONALITY
       =========================================================
       Validates:
       - Vault can receive native BNB via receive()
       - Vault balance is updated correctly
       - totalReceivedBNB accounting works
       - No permission is required to send BNB to the vault

       Security rationale:
       - Vault must safely accept tax revenue
       - Receiving funds must not depend on operator/guardian
       ========================================================= */

    function test_receiveBNB() public {
        vm.deal(address(this), 10 ether);

        (bool ok,) = address(vault).call{value: 5 ether}("");
        assertTrue(ok);

        console.log("Vault balance:", address(vault).balance);

        assertEq(address(vault).balance, 5 ether);
        assertEq(vault.totalReceivedBNB(), 5 ether);
    }

    /* =========================================================
                    BUYBACK SUCCESS TEST
       =========================================================
       Validates:
       - Operator can successfully trigger buyback
       - Buyback logic does not revert under normal conditions
       - Vault sends BNB to the router
       - Vault balance is reduced after buyback

       Test strategy:
       - Use MockRouter to simulate PancakeSwap
       - No real token swap occurs
       - Focus on control flow and fund movement

       Security rationale:
       - Ensures buyback is executable (not dead code)
       ========================================================= */

    function test_buybackSucceeds() public {
        vm.deal(address(this), 10 ether);

        // Fund the vault
        (bool ok,) = address(vault).call{value: 5 ether}("");
        require(ok);

        uint256 balanceBefore = address(vault).balance;
        console.log("Vault balance before buyback:", balanceBefore);

        // Operator triggers buyback
        vm.prank(operator);
        vault.executeBuyback(1 ether);

        uint256 balanceAfter = address(vault).balance;
        console.log("Vault balance after buyback:", balanceAfter);

        // Vault must spend BNB
        assertLt(balanceAfter, balanceBefore);
    }

    /* =========================================================
                OPERATOR ACCESS CONTROL
       =========================================================
       Validates:
       - Operator address can call permissioned functions
       - No authorization revert for operator

       Security rationale:
       - Operator is responsible for routine buybacks
       ========================================================= */

    function test_operatorCanCallBuyback() public {
        vm.deal(address(this), 2 ether);
        address(vault).call{value: 2 ether}("");

        vm.prank(operator);
        vault.executeBuyback(0.5 ether);
    }

    /* =========================================================
                GUARDIAN ACCESS CONTROL
       =========================================================
       Validates:
       - Guardian address is resolved from VaultBase
       - Guardian can call permissioned functions
       - Guardian acts as emergency fallback

       Flap compliance:
       - Guardian access is mandatory
       ========================================================= */

    function test_guardianCanCall() public {
        address guardian = vault.guardian();
        console.log("Guardian address:", guardian);

        vm.deal(address(this), 2 ether);
        address(vault).call{value: 2 ether}("");

        vm.prank(guardian);
        vault.executeBuyback(0.5 ether);
    }

    /* =========================================================
            UNAUTHORIZED ACCESS PROTECTION
       =========================================================
       Validates:
       - Arbitrary addresses cannot call permissioned functions
       - Unauthorized calls revert with expected reason

       Security rationale:
       - Prevents malicious or accidental execution
       ========================================================= */

    function test_nonOperatorRejected() public {
        vm.deal(address(this), 2 ether);
        address(vault).call{value: 2 ether}("");

        vm.prank(address(0x9999));
        vm.expectRevert("Not authorized");
        vault.executeBuyback(0.5 ether);
    }

    /* =========================================================
                FLAP UI REQUIREMENTS
       =========================================================
       Validates:
       - description() function exists
       - Description is non-empty
       - Suitable for VaultPortal display

       Flap compliance:
       - VaultPortal relies on description() for UI
       ========================================================= */

    function test_descriptionExists() public {
        string memory desc = vault.description();
        console.log("Description:", desc);

        assertGt(bytes(desc).length, 0);
    }
}
