# Audit Scope File Index

This directory is an auditor-facing index. It keeps the minimal deployed
contract source targets easy to find without duplicating source code from the
pinned submodules.

The `source/` directory contains symlinks to the two deployed contract source
targets:

- `source/HealthCheckAccountant.sol`
- `source/VaultV3.vy`

These shortcut files render on GitHub and point to canonical source files in
pinned `lib/` submodules. For local review, clone with
`--recurse-submodules` so every target resolves.

## Primary Files

Review these first:

| File | Role |
| --- | --- |
| `../AUDIT_SCOPE.md` | Full scope, deployed addresses, and out-of-scope notes |
| `source/HealthCheckAccountant.sol` | Source for deployed Accountant |
| `source/VaultV3.vy` | Existing Yearn V3 implementation used by arUSD clone |
| `../script/ArcheDeployBase.sol` | Core Arche deployment/configuration logic |
| `../script/DeployArche.s.sol` | Mainnet deployment entrypoint |

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

The whole Yearn submodule tree is present for reproducibility, not because the
minimal Arche scope asks auditors to count every Yearn file as audit LOC.
