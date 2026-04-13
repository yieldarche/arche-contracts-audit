// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {HealthCheckAccountant} from "@vault-periphery/accountants/HealthCheckAccountant.sol";

/**
 * @title ArcheDeployBase
 * @notice Shared deployment logic for the Arche / arUSD yield vault.
 *
 * This is an UNMODIFIED Yearn v3.0.4 Multi-Strategy Vault deployed via Yearn's
 * canonical VaultFactory. The attached "strategy" is actually yvUSDC-1 itself
 * (Yearn's public USDC allocator vault at 0xBe53...6204), meaning Arche is a
 * meta-vault: user USDC -> Arche -> yvUSDC-1 -> (sUSDS + 6 fallback strategies).
 *
 * This pattern was chosen after discovering that Yearn's direct USDCToUSDS Lender
 * strategy (0x7130570B...) is allowlist-gated -- only yvUSDC-1 can deposit into it.
 * By using yvUSDC-1 as our strategy, we inherit Yearn's yield without requiring
 * Yearn governance to allowlist us. Verified on mainnet 2026-04-11:
 *   - yvUSDC-1.maxDeposit(anyAddr) = $21.9M (public, no allowlist)
 *   - yvUSDC-1.asset() = USDC (matches for add_strategy)
 *   - yvUSDC-1 is a Yearn v3.0.2 vault, fully ERC-4626 compliant
 *
 * Fee note: yvUSDC-1 already charges a 10% perf fee via its own Accountant.
 * To avoid double-charging Arche depositors, Arche's Accountant is deployed
 * with perf fee = 0. We still deploy the Accountant so fees can be switched
 * on later by the Safe (e.g., if we add our own custom strategies earning
 * fees not already taken by Yearn).
 *
 * All other parameters match yvUSDC-1's live on-chain config exactly, verified
 * via `cast call` on mainnet 2026-04-11.
 *
 * ====================================================================
 * INTEGRATOR NOTES (frontends, routers, aggregators, contract integrations)
 * ====================================================================
 *
 * 1. DO NOT call `redeem(balanceOf(owner), ...)` or `withdraw(convertToAssets(balanceOf(owner)), ...)`
 *    for full exits. Due to Yearn v3's strict `current_total_idle >= requested_assets`
 *    check in `_redeem` combined with yvUSDC-1's own internal `maxRedeem` rounding
 *    (which returns ~1 share less than our actual balance), a naive full-balance
 *    redeem reverts with "insufficient assets in vault" on a 1-2 wei shortfall.
 *
 *    CORRECT PATTERN for full exits:
 *        uint256 maxOut = IVault(arche).maxWithdraw(owner, maxLossBps);
 *        IVault(arche).withdraw(maxOut, receiver, owner, maxLossBps);
 *
 *    `maxWithdraw` pre-simulates the queue walk and returns exactly what's
 *    retrievable. `maxLossBps = 0` is safe since rounding-dust loss is never
 *    passed on to users — it stays as un-retrieved yvUSDC-1 shares that
 *    accrue back into the vault on the next report cycle.
 *
 * 2. `withdraw()` and `redeem()` return VALUES ARE NOT symmetric:
 *      - `withdraw(assets)` returns SHARES BURNED
 *      - `redeem(shares)`   returns ASSETS TRANSFERRED
 *    Measure user payouts from USDC balance diff or the `Withdraw` event,
 *    not from the function return value.
 *
 * 3. The 2-wei-dust is not a share-price exploit. Rounding always favors
 *    the vault (ROUND_DOWN on assets out, ROUND_UP on shares in), so any
 *    residual dust benefits remaining holders. Yearn v3's `totalAssets`
 *    is `total_idle + total_debt` (storage-tracked), NOT ERC20 balanceOf,
 *    so direct asset donations cannot inflate pps. No seed deposit required.
 *
 * 4. First-deposit edge case: Yearn v3 mints 1:1 on empty vault (no virtual
 *    decimal offset). This is standard and not exploitable here because of
 *    note #3. Still, the team may optionally make a small first deposit
 *    from the Safe as a sanity-check seeding (non-security).
 * ====================================================================
 */
abstract contract ArcheDeployBase {
    // ---------------------------------------------------------------------
    // CANONICAL ETHEREUM MAINNET ADDRESSES
    // All cross-verified on mainnet 2026-04-11 via Foundry cast call.
    // Sources: Circle Etherscan label, Yearn's repo at v3.0.4 tag, ydaemon.
    // ---------------------------------------------------------------------

    /// @notice Circle USDC. 6 decimals.
    address internal constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @notice Yearn VaultFactory v3.0.4 ("chore: deploy 304"). apiVersion="3.0.4", shutdown=false.
    address internal constant VAULT_FACTORY =
        0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F;

    /// @notice yvUSDC-1 — Yearn's public USDC allocator vault, used as Arche's strategy.
    /// @dev v3.0.2, $28M TVL, $50M cap ($21.9M headroom as of 2026-04-11), asset=USDC.
    ///      Allocates 99.84% into the gated USDCToUSDS Lender under the hood.
    ///      Public ERC-4626: anyone can deposit (unlike the direct USDCToUSDS strategy
    ///      which has an allowlist that only contains yvUSDC-1 itself).
    address internal constant YVUSDC1_STRATEGY =
        0xBe53A109B494E5c9f97b9Cd39Fe969BE68BF6204;

    // ---------------------------------------------------------------------
    // VAULT PARAMETERS (match yvUSDC-1 live config exactly)
    // ---------------------------------------------------------------------

    /// @notice 10 days. Time over which reported profits linearly unlock into share price.
    uint256 internal constant PROFIT_MAX_UNLOCK_TIME = 864_000;

    /// @notice $50M hard cap on total deposits. Matches yvUSDC-1's deliberate safety rail.
    uint256 internal constant DEPOSIT_LIMIT = 50_000_000 * 1e6;

    /// @notice Bitmask of all 14 Yearn v3 operational roles granted to the Safe.
    ///         1 + 2 + 4 + 8 + 16 + 32 + 64 + 128 + 256 + 512 + 1024 + 2048 + 4096 + 8192 = 16383
    uint256 internal constant ALL_ROLES = 16_383;

    // ---------------------------------------------------------------------
    // ACCOUNTANT FEE PARAMETERS (match yvUSDC-1's deployed Accountant exactly)
    // Verified via: cast call 0x5A74Cb32... defaultConfig() => (0, 1000, 0, 10000, 20000, 1)
    // ---------------------------------------------------------------------

    /// @notice 0 bps annual management fee.
    uint16 internal constant MGMT_FEE = 0;

    /// @notice 0 bps = no Arche-level performance fee.
    /// @dev Set to 0 because yvUSDC-1 already charges 10% at its level.
    ///      Would double-charge depositors if we took another cut on top.
    ///      The Accountant is still deployed so the Safe can switch fees on
    ///      later (e.g., if we add custom strategies earning non-Yearn yield).
    uint16 internal constant PERF_FEE = 0;

    /// @notice 0 bps refund ratio (no loss refund mechanism).
    uint16 internal constant REFUND_RATIO = 0;

    /// @notice 10000 bps = 100% max fee cap as % of gain. Effectively uncapped.
    uint16 internal constant MAX_FEE = 10_000;

    /// @notice 20000 bps = 200% max single-report gain. Healthcheck sanity bound.
    uint16 internal constant MAX_GAIN = 20_000;

    /// @notice 1 bps = 0.01% max single-report loss. Strict healthcheck — any larger loss
    ///         reverts and requires explicit skipHealthCheck by the feeManager.
    uint16 internal constant MAX_LOSS = 1;

    // ---------------------------------------------------------------------
    // VAULT NAME / SYMBOL
    // ---------------------------------------------------------------------

    string internal constant VAULT_NAME = "Arche USD";
    string internal constant VAULT_SYMBOL = "arUSD";

    // ---------------------------------------------------------------------
    // DEPLOY
    // ---------------------------------------------------------------------

    /**
     * @notice Deploys the Arche vault + Accountant and wires everything up.
     *
     * Caller must be `deployer` (broadcast or prank context). After this
     * function returns, `deployer` is temporarily both role_manager AND
     * holds all 14 operational roles. The two-step handoff to `safe` is
     * STARTED but not complete — the Safe must call the two accept functions
     * below in a subsequent transaction:
     *
     *   1. IVault(vault).accept_role_manager()
     *   2. HealthCheckAccountant(accountant).acceptFeeManager()
     *
     * Only after those two accepts should `deployer` revoke its own operational
     * roles via `vault.set_role(deployer, 0)` (executed by the Safe).
     *
     * @param deployer EOA that pays gas and temporarily holds power.
     * @param safe     Gnosis Safe multisig that will own the vault long-term.
     * @return vault       The deployed Arche vault (ERC-4626 share token).
     * @return accountant  The deployed HealthCheckAccountant.
     */
    function _deployArche(address deployer, address safe)
        internal
        returns (address vault, address accountant)
    {
        // --- 1. Deploy the Accountant -----------------------------------
        // feeManager = deployer temporarily (two-step transfer to Safe below).
        // feeRecipient = Safe directly (this is a one-step setter, safe to set
        // to final recipient immediately since it only receives fee shares).
        accountant = address(
            new HealthCheckAccountant(
                deployer,       // _feeManager
                safe,           // _feeRecipient
                MGMT_FEE,       // defaultManagement
                PERF_FEE,       // defaultPerformance
                REFUND_RATIO,   // defaultRefund
                MAX_FEE,        // defaultMaxFee
                MAX_GAIN,       // defaultMaxGain
                MAX_LOSS        // defaultMaxLoss
            )
        );

        // --- 2. Deploy the vault via Yearn VaultFactory -----------------
        // role_manager starts as deployer so we can configure everything in
        // this same tx; transferred to Safe at the end.
        vault = _deployVaultViaFactory(deployer);

        IVault v = IVault(vault);

        // --- 3. Grant deployer all operational roles so it can configure -
        // Without this, `role_manager` has only meta-power (grant/revoke roles)
        // but no operational permissions. Grant all 16383 to self first.
        v.set_role(deployer, ALL_ROLES);

        // --- 4. Wire up the Accountant ----------------------------------
        v.set_accountant(accountant);
        HealthCheckAccountant(accountant).addVault(vault);

        // --- 5. Set the $50M deposit cap --------------------------------
        v.set_deposit_limit(DEPOSIT_LIMIT);

        // --- 6. Attach the single sUSDS strategy ------------------------
        // Note: we use the 1-arg version which defaults add_to_queue=True.
        v.add_strategy(YVUSDC1_STRATEGY);

        // Uncap the max_debt on the strategy so it can absorb the full
        // deposit_limit. The vault will never push more than idle * limit,
        // and deposit_limit itself is the real cap.
        v.update_max_debt_for_strategy(
            YVUSDC1_STRATEGY,
            type(uint256).max
        );

        // --- 7. Grant the Safe all operational roles --------------------
        v.set_role(safe, ALL_ROLES);

        // --- 8. Start the two-step transfer of role_manager to Safe -----
        // Safe must call vault.accept_role_manager() to complete.
        v.transfer_role_manager(safe);

        // --- 9. Start the two-step transfer of feeManager to Safe -------
        // Safe must call accountant.acceptFeeManager() to complete.
        HealthCheckAccountant(accountant).setFutureFeeManager(safe);
    }

    /**
     * @notice Wrapper that calls the Vyper factory via a low-level call so we
     *         don't need a dedicated IVaultFactory Solidity interface.
     *         Signature: deploy_new_vault(address,string,string,address,uint256) returns (address)
     */
    function _deployVaultViaFactory(address deployer)
        private
        returns (address vault)
    {
        (bool ok, bytes memory ret) = VAULT_FACTORY.call(
            abi.encodeWithSignature(
                "deploy_new_vault(address,string,string,address,uint256)",
                USDC,
                VAULT_NAME,
                VAULT_SYMBOL,
                deployer,
                PROFIT_MAX_UNLOCK_TIME
            )
        );
        require(ok, "VaultFactory.deploy_new_vault failed");
        vault = abi.decode(ret, (address));
        require(vault != address(0), "vault address is zero");
    }
}
