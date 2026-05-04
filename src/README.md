# Source Layout Note

This directory is intentionally empty.

Arche did not deploy custom implementation contracts from `src/` in this
release. The deployed arUSD vault is a Yearn V3 clone created by Yearn's
VaultFactory, and the deployed Accountant source is in the pinned
vault-periphery submodule.

For the audit scope and exact files to review, see:

- `../AUDIT_SCOPE.md`
- `../audit-scope/README.md`
