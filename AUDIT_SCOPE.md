# Arche Audit Scope

This document is the canonical scoping note for the Arche / arUSD Ethereum
mainnet deployment.

Arche does not have a custom vault implementation contract in `src/`. The
deployment creates:

1. an arUSD Yearn V3 vault clone through Yearn's canonical VaultFactory, and
2. a HealthCheckAccountant from Yearn vault-periphery.

The important review work is the deployed address mapping, the pinned upstream
source that backs those addresses, and the Arche deployment/configuration logic.

For browser review on GitHub, use the shortcut files in
`audit-scope/source/`. For local review, the canonical `lib/...` submodule
paths resolve after cloning with `--recurse-submodules`.

## Deployed Contracts

| Name | Address | How it was deployed | Canonical source |
| --- | --- | --- | --- |
| arUSD vault / token | `0x33FfC177A7278FF84aaB314A036bC7b799B7Cc15` | `CREATE2` clone created by Yearn `VaultFactory` | `lib/yearn-vaults-v3/contracts/VaultV3.vy` |
| HealthCheckAccountant | `0x462f89759f6ddcbdb39EE563576FfDdA3399716c` | Direct `CREATE` from deployment script | `lib/vault-periphery/contracts/accountants/HealthCheckAccountant.sol` |

The arUSD vault implementation was not deployed by Arche. The clone points to
Yearn's existing V3 vault implementation:

`0xd8063123BBA3B480569244AE66BFE72B6c84b00d`

The factory used to create the vault clone:

`0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F`

The broadcast artifact that proves the deployment and setup sequence is:

`broadcast/DeployArche.s.sol/1/run-latest.json`

## Files In Scope

### Arche-authored deployment and configuration

| File | Why it matters |
| --- | --- |
| `script/ArcheDeployBase.sol` | Core deployment/configuration logic: deploys accountant, calls Yearn factory, sets vault roles, adds yvUSDC-1 strategy, sets limits, starts Safe handoff |
| `script/DeployArche.s.sol` | Mainnet deployment entrypoint and environment assumptions |
| `handoff/arche-handoff.json` | Safe batch to accept role manager, accept fee manager, and revoke deployer roles |
| `broadcast/DeployArche.s.sol/1/run-latest.json` | Exact mainnet transaction sequence and constructor arguments |
| `test/ArcheFork.t.sol` | Mainnet-fork tests covering deployment and lifecycle behavior |

### Pinned upstream source used by deployed contracts

| File | Why it matters |
| --- | --- |
| `audit-scope/source/ArcheDeployBase.sol` | Shortcut to the core Arche deployment/configuration logic |
| `audit-scope/source/DeployArche.s.sol` | Shortcut to the mainnet deployment entrypoint |
| `audit-scope/source/HealthCheckAccountant.sol` | Shortcut to the deployed Accountant source |
| `audit-scope/source/VaultV3.vy` | Shortcut to the arUSD vault implementation source |
| `audit-scope/source/VaultFactory.vy` | Shortcut to the factory source used to create arUSD |
| `audit-scope/source/IVault.sol` | Shortcut to the vault interface used by scripts/tests |
| `audit-scope/source/Roles.sol` | Shortcut to Yearn role constants |

Canonical local paths after cloning with submodules:

| File | Why it matters |
| --- | --- |
| `lib/yearn-vaults-v3/contracts/VaultV3.vy` | Runtime implementation used by the arUSD vault clone |
| `lib/yearn-vaults-v3/contracts/VaultFactory.vy` | Factory called by the deployment script to create arUSD |
| `lib/yearn-vaults-v3/contracts/interfaces/IVault.sol` | Interface used by the deployment script and tests |
| `lib/vault-periphery/contracts/accountants/HealthCheckAccountant.sol` | Runtime source for the deployed Accountant |
| `lib/vault-periphery/contracts/libraries/Roles.sol` | Role constants used by Yearn periphery/accountant/vault permissions |

## External Contracts And Dependencies

These addresses are existing external dependencies, not custom Arche contracts:

| Dependency | Address | Scope note |
| --- | --- | --- |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | Existing asset token |
| yvUSDC-1 strategy | `0xBe53A109B494E5c9f97b9Cd39Fe969BE68BF6204` | Existing Yearn ERC-4626 vault used as Arche's first strategy |
| Arche Safe | `0x3207bFbCa46D1D6316ef92F71e44B5C069d71886` | Long-term role manager / fee manager / fee recipient |
| Deployment EOA | `0x0139f765E8895BcA388605Fb7b635a5ADb510D65` | Temporary deployer, revoked by Safe handoff |

## Configuration To Verify

| Setting | Value |
| --- | --- |
| Asset | USDC |
| Vault name | `Arche USD` |
| Vault symbol | `arUSD` |
| Decimals | `6` |
| Profit max unlock time | `864000` seconds |
| Deposit limit | `50,000,000 USDC` |
| First strategy | yvUSDC-1 |
| Arche management fee | `0` |
| Arche performance fee | `0` |
| Safe role bitmask | `16383` |
| Accountant max fee | `10000` bps |
| Accountant max gain | `20000` bps |
| Accountant max loss | `1` bps |

## Explicitly Out Of Scope

- There is no custom Arche strategy contract in this release.
- Arche did not deploy a custom vault implementation.
- The initial strategy is the existing Yearn yvUSDC-1 vault.
- Future Arche strategies should be scoped and reviewed separately before they
  are added by the Safe.

## Verify Locally

Clone with submodules:

```sh
git clone --recurse-submodules https://github.com/yieldarche/arche-contracts-audit.git
cd arche-contracts-audit
```

Run the fork tests:

```sh
forge test
```

If `ETH_RPC_URL` is not set, the tests fall back to:

`https://ethereum-rpc.publicnode.com`
