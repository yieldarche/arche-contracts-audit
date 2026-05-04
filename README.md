# Arche Audit Scope

This repo is for reviewing the Arche / arUSD Ethereum mainnet deployment.

## Audit Targets

| Target | Address | Source |
| --- | --- | --- |
| arUSD vault / token | `0x33FfC177A7278FF84aaB314A036bC7b799B7Cc15` | `audit-scope/source/VaultV3.vy` |
| HealthCheckAccountant | `0x462f89759f6ddcbdb39EE563576FfDdA3399716c` | `audit-scope/source/HealthCheckAccountant.sol` |

## How This Links To Yearn

- arUSD is a Yearn V3 vault clone, not a custom Arche vault implementation.
- The arUSD clone uses Yearn's existing VaultV3 implementation at
  `0xd8063123BBA3B480569244AE66BFE72B6c84b00d`.
- The clone was created by Yearn's VaultFactory at
  `0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F`.
- The Accountant source comes from the pinned Yearn vault-periphery submodule.
- The first strategy is existing Yearn yvUSDC-1:
  `0xBe53A109B494E5c9f97b9Cd39Fe969BE68BF6204`.

## Arche Configuration To Review

| File | Purpose |
| --- | --- |
| `script/ArcheDeployBase.sol` | Deploys/configures the vault and Accountant |
| `script/DeployArche.s.sol` | Mainnet deployment entrypoint |
| `broadcast/DeployArche.s.sol/1/run-latest.json` | Mainnet deployment transaction artifact |
| `handoff/arche-handoff.json` | Safe handoff batch |
| `test/ArcheFork.t.sol` | Mainnet-fork tests |

## Admin Addresses

| Address | Role |
| --- | --- |
| `0x3207bFbCa46D1D6316ef92F71e44B5C069d71886` | Arche Safe, current admin |
| `0x0139f765E8895BcA388605Fb7b635a5ADb510D65` | Deployment EOA, retired/revoked |

## Not In Scope

- No custom Arche strategy was deployed.
- No custom Arche vault implementation was deployed.
- A full re-audit of all Yearn V3 code is not requested unless scoped separately.

## Run Tests

```sh
git clone --recurse-submodules https://github.com/yieldarche/arche-contracts-audit.git
cd arche-contracts-audit
forge test
```
