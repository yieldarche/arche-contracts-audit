// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {Script, console2} from "forge-std/Script.sol";
import {ArcheDeployBase} from "./ArcheDeployBase.sol";

/**
 * @title DeployArche
 * @notice Production deployment script for the Arche / arUSD vault.
 *
 * Requires two env vars:
 *   DEPLOYER_PK : private key that pays deployment gas. Must be funded on mainnet.
 *   SAFE        : Gnosis Safe multisig that will own the vault long-term.
 *
 * Usage:
 *   forge script script/DeployArche.s.sol:DeployArche \
 *     --rpc-url $ETH_RPC_URL \
 *     --broadcast \
 *     --verify
 *
 * Post-deploy checklist (SAFE executes these before revoking DEPLOYER roles):
 *   1. IVault(vault).accept_role_manager()
 *   2. HealthCheckAccountant(accountant).acceptFeeManager()
 *   3. IVault(vault).set_role(DEPLOYER, 0)   // revoke deployer's 16383-role grant
 */
contract DeployArche is Script, ArcheDeployBase {
    function run() external returns (address vault, address accountant) {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address safe = vm.envAddress("SAFE");
        address deployer = vm.addr(deployerPk);

        require(safe != address(0), "SAFE env var is zero");
        require(safe != deployer, "SAFE must differ from deployer");

        console2.log("=== Arche / arUSD deployment ===");
        console2.log("Deployer  :", deployer);
        console2.log("Safe      :", safe);
        console2.log("USDC      :", USDC);
        console2.log("Factory   :", VAULT_FACTORY);
        console2.log("Strategy  :", YVUSDC1_STRATEGY);

        vm.startBroadcast(deployerPk);
        (vault, accountant) = _deployArche(deployer, safe);
        vm.stopBroadcast();

        console2.log("=== Deployed ===");
        console2.log("Vault      :", vault);
        console2.log("Accountant :", accountant);
        console2.log("");
        console2.log("NEXT STEPS (execute from SAFE):");
        console2.log("  1. vault.accept_role_manager()");
        console2.log("  2. accountant.acceptFeeManager()");
        console2.log("  3. vault.set_role(deployer, 0) -- revoke deployer roles");
    }
}
