# Audit Source Shortcuts

The two deployed source targets are:

| Target | Shortcut |
| --- | --- |
| arUSD vault / token | `source/VaultV3.vy` |
| HealthCheckAccountant | `source/HealthCheckAccountant.sol` |

`source/VaultV3.vy` points to the pinned Yearn V3 vault implementation.
`source/HealthCheckAccountant.sol` points to the pinned Yearn vault-periphery
Accountant source.

Arche-specific deployment/configuration files are listed in `../AUDIT_SCOPE.md`.
