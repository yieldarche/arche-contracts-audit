# Arche Audit Scope

Audit these two deployed targets:

| Target | Address | Source |
| --- | --- | --- |
| arUSD vault / token | `0x33FfC177A7278FF84aaB314A036bC7b799B7Cc15` | `audit-scope/source/VaultV3.vy` |
| HealthCheckAccountant | `0x462f89759f6ddcbdb39EE563576FfDdA3399716c` | `audit-scope/source/HealthCheckAccountant.sol` |

## Yearn Linkage

arUSD is a Yearn V3 vault clone. Arche did not deploy a custom vault
implementation.

| Component | Address / path |
| --- | --- |
| arUSD clone | `0x33FfC177A7278FF84aaB314A036bC7b799B7Cc15` |
| Yearn VaultV3 implementation | `0xd8063123BBA3B480569244AE66BFE72B6c84b00d` |
| Yearn VaultFactory | `0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F` |
| VaultV3 source | `audit-scope/source/VaultV3.vy` |
| yvUSDC-1 first strategy | `0xBe53A109B494E5c9f97b9Cd39Fe969BE68BF6204` |

The Accountant source is from the pinned Yearn vault-periphery submodule:

`audit-scope/source/HealthCheckAccountant.sol`

## Arche Files To Review

| File | Purpose |
| --- | --- |
| `script/ArcheDeployBase.sol` | Deployment/configuration logic |
| `script/DeployArche.s.sol` | Mainnet deployment entrypoint |
| `broadcast/DeployArche.s.sol/1/run-latest.json` | Actual mainnet transaction artifact |
| `handoff/arche-handoff.json` | Safe handoff batch |
| `test/ArcheFork.t.sol` | Mainnet-fork tests |

## Admin Addresses

| Address | Role |
| --- | --- |
| `0x3207bFbCa46D1D6316ef92F71e44B5C069d71886` | Arche Safe, current admin |
| `0x0139f765E8895BcA388605Fb7b635a5ADb510D65` | Deployment EOA, retired/revoked |

## Out Of Scope

- No custom Arche strategy was deployed.
- No custom Arche vault implementation was deployed.
- Full Yearn V3 re-audit is not requested unless scoped separately.
