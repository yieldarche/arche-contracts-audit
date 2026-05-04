# Audit Scope File Index

This directory is an auditor-facing index. It keeps the files to review in one
place without duplicating source code from the pinned submodules.

The `source/` directory contains symlinks to the exact in-scope source files:

- `source/ArcheDeployBase.sol`
- `source/DeployArche.s.sol`
- `source/HealthCheckAccountant.sol`
- `source/VaultV3.vy`
- `source/VaultFactory.vy`
- `source/IVault.sol`
- `source/Roles.sol`

These shortcut files render on GitHub and point to the canonical source files
in `script/` and pinned `lib/` submodules. For local review, clone with
`--recurse-submodules` so every target resolves.

## Primary Files

Review these first:

| File | Role |
| --- | --- |
| `../AUDIT_SCOPE.md` | Full scope, deployed addresses, and out-of-scope notes |
| `../script/ArcheDeployBase.sol` | Core Arche deployment/configuration logic |
| `../script/DeployArche.s.sol` | Mainnet deployment entrypoint |
| `../lib/vault-periphery/contracts/accountants/HealthCheckAccountant.sol` | Source for deployed Accountant |
| `../lib/yearn-vaults-v3/contracts/VaultV3.vy` | Runtime implementation used by arUSD clone |
| `../lib/yearn-vaults-v3/contracts/VaultFactory.vy` | Factory used to create arUSD clone |
| `../lib/yearn-vaults-v3/contracts/interfaces/IVault.sol` | Vault interface used by scripts/tests |
| `../lib/vault-periphery/contracts/libraries/Roles.sol` | Role constants used by Yearn permissions |

## Deployment Evidence

| File | Role |
| --- | --- |
| `../broadcast/DeployArche.s.sol/1/run-latest.json` | Mainnet deployment transaction sequence |
| `../handoff/arche-handoff.json` | Safe ownership handoff batch |
| `../test/ArcheFork.t.sol` | Fork test coverage for deployment and lifecycle |

## Layout Note

There are no custom Arche implementation contracts under `src/`. That is
intentional: the deployed arUSD vault is a Yearn V3 clone, and the Accountant
comes from the pinned Yearn vault-periphery submodule.
