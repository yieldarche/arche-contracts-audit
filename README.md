# Arche Contracts

Audit repository for the Arche / arUSD Ethereum mainnet deployment.

Start here:

- [AUDIT_SCOPE.md](./AUDIT_SCOPE.md) gives the exact deployed addresses,
  source files, configuration, and out-of-scope dependencies.
- [audit-scope/README.md](./audit-scope/README.md) is a short file index for
  auditors who just want the paths to review.

This repo is intentionally not laid out like a normal protocol with custom
contracts under `src/`. Arche deployed a Yearn V3 vault clone plus a
HealthCheckAccountant, using pinned upstream Yearn source and Arche deployment
configuration.

## Deployment Summary

Arche deployed two new contract addresses:

| Contract | Address | Deployment path |
| --- | --- | --- |
| arUSD vault / token | `0x33FfC177A7278FF84aaB314A036bC7b799B7Cc15` | Yearn V3 vault clone created by the canonical Yearn `VaultFactory` |
| HealthCheckAccountant | `0x462f89759f6ddcbdb39EE563576FfDdA3399716c` | Direct `CREATE` deployment from `HealthCheckAccountant` |

The arUSD vault is a Yearn V3 minimal proxy clone. The implementation was not
deployed by Arche; it is Yearn's existing V3 vault implementation:

`0xd8063123BBA3B480569244AE66BFE72B6c84b00d`

## External And Arche Admin Addresses

| Address | Owner / role |
| --- | --- |
| `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | USDC, external dependency |
| `0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F` | Yearn V3 VaultFactory, external dependency |
| `0xBe53A109B494E5c9f97b9Cd39Fe969BE68BF6204` | yvUSDC-1 strategy, external Yearn dependency |
| `0x3207bFbCa46D1D6316ef92F71e44B5C069d71886` | Arche Safe, current admin / role owner |
| `0x0139f765E8895BcA388605Fb7b635a5ADb510D65` | Arche deployment EOA, now retired/revoked |

## Minimal Audit Scope

| Path | Purpose |
| --- | --- |
| `audit-scope/source/HealthCheckAccountant.sol` | Source for deployed Accountant |
| `audit-scope/source/VaultV3.vy` | Existing Yearn V3 implementation used by the arUSD vault clone |

The deployment and handoff files are configuration/evidence, not additional
deployed contract source:

| Path | Purpose |
| --- | --- |
| `script/ArcheDeployBase.sol` | Shared deployment logic and production configuration |
| `script/DeployArche.s.sol` | Mainnet deployment entrypoint |
| `broadcast/DeployArche.s.sol/1/run-latest.json` | Actual mainnet broadcast artifact |
| `handoff/arche-handoff.json` | Safe batch that accepts ownership roles and retires the deployer |
| `test/ArcheFork.t.sol` | Mainnet-fork deployment and lifecycle tests |

## Upstream Dependency Pins

The deployed vault and accountant rely on pinned upstream code:

| Dependency | Commit / tag shown by submodule |
| --- | --- |
| `lib/yearn-vaults-v3` | `104a2b233bc6d43ba40720d68355b04d2dc31795` (`v3.0.4`) |
| `lib/vault-periphery` | `06684958dc81d572fa8213c44bf96da14943402f` (`v3.0.1`) |
| `lib/forge-std` | `0844d7e1fc5e60d77b68e469bff60265f236c398` (`v1.15.0`) |

Reference files, not requested for LOC count unless a full Yearn re-audit is
separately requested:

- `lib/yearn-vaults-v3/contracts/VaultFactory.vy`
- `lib/yearn-vaults-v3/contracts/interfaces/IVault.sol`
- `lib/vault-periphery/contracts/libraries/Roles.sol`

## Configuration

The deployed vault:

- asset: USDC
- name: `Arche USD`
- symbol: `arUSD`
- decimals: `6`
- profit max unlock time: `864000` seconds
- deposit limit: `50,000,000 USDC`
- first strategy: yvUSDC-1
- Arche-level management fee: `0`
- Arche-level performance fee: `0`
- Safe role bitmask: `16383`

## Verify

Clone with submodules:

```sh
git clone --recurse-submodules https://github.com/yieldarche/arche-contracts-audit.git
cd arche-contracts-audit
```

Run the mainnet-fork tests:

```sh
forge test
```

If `ETH_RPC_URL` is not set, the tests fall back to
`https://ethereum-rpc.publicnode.com`.

## Scope Note

No custom Arche strategy contract was deployed in this release. The initial
vault allocates to the existing Yearn yvUSDC-1 vault. Future Arche strategies
would be deployed and reviewed separately before being added to the vault by
the Safe.
