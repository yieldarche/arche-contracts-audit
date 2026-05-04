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

## Existing External Contracts

| Dependency | Address |
| --- | --- |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| Yearn V3 VaultFactory | `0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F` |
| yvUSDC-1 strategy | `0xBe53A109B494E5c9f97b9Cd39Fe969BE68BF6204` |
| Arche Safe | `0x3207bFbCa46D1D6316ef92F71e44B5C069d71886` |
| Deployment EOA, now retired | `0x0139f765E8895BcA388605Fb7b635a5ADb510D65` |

## Fast Scope

| Path | Purpose |
| --- | --- |
| `script/ArcheDeployBase.sol` | Shared deployment logic and production configuration |
| `script/DeployArche.s.sol` | Mainnet deployment entrypoint |
| `lib/vault-periphery/contracts/accountants/HealthCheckAccountant.sol` | Source for deployed Accountant |
| `lib/yearn-vaults-v3/contracts/VaultV3.vy` | Yearn V3 vault implementation used by arUSD clone |
| `lib/yearn-vaults-v3/contracts/VaultFactory.vy` | Factory that created the arUSD vault clone |
| `broadcast/DeployArche.s.sol/1/run-latest.json` | Actual mainnet broadcast artifact |
| `handoff/arche-handoff.json` | Safe batch that accepts ownership roles and retires the deployer |
| `test/ArcheFork.t.sol` | Mainnet-fork deployment and lifecycle tests |
| `foundry.toml` / `remappings.txt` / `foundry.lock` | Build configuration |
| `.gitmodules` | Pinned upstream dependency repositories |

## Upstream Dependency Pins

The deployed vault and accountant rely on pinned upstream code:

| Dependency | Commit / tag shown by submodule |
| --- | --- |
| `lib/yearn-vaults-v3` | `104a2b233bc6d43ba40720d68355b04d2dc31795` (`v3.0.4`) |
| `lib/vault-periphery` | `06684958dc81d572fa8213c44bf96da14943402f` (`v3.0.1`) |
| `lib/forge-std` | `0844d7e1fc5e60d77b68e469bff60265f236c398` (`v1.15.0`) |

Important upstream source files:

- `lib/yearn-vaults-v3/contracts/VaultFactory.vy`
- `lib/yearn-vaults-v3/contracts/VaultV3.vy`
- `lib/yearn-vaults-v3/contracts/interfaces/IVault.sol`
- `lib/vault-periphery/contracts/accountants/HealthCheckAccountant.sol`
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
git clone --recurse-submodules https://github.com/yieldarche/arche-contracts.git
cd arche-contracts
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
