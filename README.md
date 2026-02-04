# Nebby Tax Vault

Nebby Tax Vault is a Flap-compatible on-chain vault designed to securely receive token tax revenue, execute automated buybacks, and serve as the foundation for Nebby’s long-term tokenomics.

The vault strictly follows the **Flap Vault Specification**, including Guardian access requirements, dynamic vault descriptions, and chain-restricted behavior.

---

## Overview

All token tax and platform fees are routed directly into this vault. Funds held in the vault are processed according to the following allocation model:

- **100% of tax revenue flows into the vault**
- **80% Buyback Engine**
  - 20% Token burn
  - 40% Rewards for eligible long-term holders  
    *(minimum 24h holding period and ≥0.01% of total supply)*
  - 20% Platform incentives
- **20% Strategic reserves**

> ⚠️ Reward distribution and holder eligibility logic are implemented in a separate RewardDistributor contract and are intentionally out of scope for this vault.

---

## Key Properties

- Fully compliant with **Flap Vault Specification**
- Guardian-enabled permissioned functions (mandatory by Flap)
- Chain-aware behavior (BNB Mainnet & BNB Testnet only)
- No upgradeability
- Explicit and minimal access control
- Transparent accounting for received funds

---

## Architecture

### Core Components

- **NebbyTaxVault**
  - Receives native BNB tax revenue
  - Executes automated buybacks via a DEX router
  - Enforces operator and guardian authorization
  - Exposes a dynamic `description()` for Flap VaultPortal UI

- **VaultBase (Flap)**
  - Provides Guardian resolution
  - Enforces supported chain constraints
  - Defines the required `description()` interface

- **MockRouter (Test-only)**
  - Simulates PancakeSwap behavior
  - Enables full buyback execution testing without real swaps

---

## Access Control Model

| Role | Permissions |
|---|---|
| Operator | Executes routine buybacks |
| Guardian (Flap) | Emergency fallback for permissioned functions |
| Public | Can send BNB to the vault |

All unauthorized calls to permissioned functions are strictly rejected.

---

## Supported Chains

The vault explicitly supports only the following networks, as required by Flap:

- **BNB Mainnet** (chainId: 56)
- **BNB Testnet** (chainId: 97)

Any interaction on unsupported chains will revert with `UnsupportedChain`.

---

## Testing

All tests are written using **Foundry** and focus on correctness, security, and Flap compliance.

### Test Coverage

- Vault deployment on supported chains
- Receiving BNB and accounting correctness
- Successful buyback execution (mocked router)
- Operator access control
- Guardian access control (mandatory by Flap)
- Unauthorized access rejection
- Vault description availability for UI

### Test Design Principles

- Buyback execution path is fully exercised
- No dead code or unreachable logic
- No over-mocking of core vault behavior
- Reverts are intentional and explicitly tested
- Tests reflect realistic production behavior

---

## Test Results

The following results were obtained from a successful Foundry test run:

```text
Ran 6 tests for test/NebbyTaxVault.t.sol:NebbyTaxVaultTest

[PASS] test_receiveBNB()
Logs:
  Vault deployed at: 0x2e234DAe75C793f67A35089C9d99245E1C58470b
  MockRouter deployed at: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  ChainId: 97
  Vault balance: 5000000000000000000

  - Vault received BNB correctly
  - totalReceivedBNB accounting matched actual balance
  
[PASS] test_buybackSucceeds()
Logs:
  Vault deployed at: 0x2e234DAe75C793f67A35089C9d99245E1C58470b
  MockRouter deployed at: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  ChainId: 97
  Vault balance before buyback: 5000000000000000000
  Vault balance after buyback: 4360000000000000000

  - Vault balance reduced after buyback execution
  - Mock router successfully received BNB

[PASS] test_descriptionExists()
Logs:
  Vault deployed at: 0x2e234DAe75C793f67A35089C9d99245E1C58470b
  MockRouter deployed at: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  ChainId: 97
  Description: Nebby Tax Vault. 100% of token tax (5% buy / 5% sell) and 1% platform fee are routed here. 80% is processed by an automated buyback engine: 20% burned, 40% distributed to eligible long-term holders (minimum 24h holding and >=0.01% supply), 20% allocated to platform incentives. Remaining 20% held as strategic reserves. Current vault balance: 0.0000 BNB.

  - description() returned a non-empty, human-readable string

[PASS] test_guardianCanCall()
Logs:
  Vault deployed at: 0x2e234DAe75C793f67A35089C9d99245E1C58470b
  MockRouter deployed at: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
  ChainId: 97
  Guardian address: 0x76Fa8C526f8Bc27ba6958B76DeEf92a0dbE46950

  - Guardian address resolved correctly
  - Guardian successfully executed permissioned function

[PASS] test_nonOperatorRejected()
  - Unauthorized address reverted as expected

[PASS] test_operatorCanCallBuyback()
  - Operator successfully executed buyback

Suite result: ok  
6 passed; 0 failed; 0 skipped  
````

These results confirm that the vault logic is executable, secure, and Flap-compliant.

---

## Running Tests

### Install Dependencies

```bash
forge install
```

### Run All Tests

```bash
forge test -vv
```

### Run Vault Tests Only

```bash
forge test --match-contract NebbyTaxVaultTest -vv
```

---

## Repository Structure

```text
src/
├─ NebbyTaxVault.sol
└─ interfaces/
   └─ VaultBase.sol

test/
├─ NebbyTaxVault.t.sol
└─ mocks/
   └─ MockRouter.sol
```

---

## Security Considerations

* The vault does **not** expose any withdrawal function
* All permissioned actions require Operator or Guardian authorization
* Guardian access cannot be revoked
* Chain restrictions prevent misuse on unsupported networks
* Buyback execution is explicit and isolated

---

## Audit Readiness

This contract is designed to be audit-ready:

* Clear separation of responsibilities
* Minimal external dependencies
* Explicit authorization logic
* Deterministic control flow
* Comprehensive and passing test suite

The vault is suitable for:

* Automated static analysis
* Manual security audits
* Flap VaultPortal verification

---

## License

MIT License