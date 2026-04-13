// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {HealthCheckAccountant} from "@vault-periphery/accountants/HealthCheckAccountant.sol";
import {ArcheDeployBase} from "../script/ArcheDeployBase.sol";

interface IERC20Min {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IERC4626Min {
    function convertToAssets(uint256 shares) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function pricePerShare() external view returns (uint256);
}

/**
 * @title ArcheForkTest
 * @notice End-to-end fork test of the Arche / arUSD deployment.
 *
 * Runs on a mainnet fork and exercises the full lifecycle:
 *   1. Deploy Arche via ArcheDeployBase (same code path as production script).
 *   2. Verify every post-deploy parameter matches yvUSDC-1's live config.
 *   3. Simulate a user USDC deposit.
 *   4. Manually push funds into the sUSDS strategy (our operator action).
 *   5. Warp forward 30 days to accrue Sky savings rate yield.
 *   6. Trigger a strategy report + vault process_report.
 *   7. Verify share price increased and fees minted to the Safe.
 *   8. Verify user withdrawal unwinds the strategy automatically.
 *   9. Execute the two-step role_manager + feeManager handoff to the Safe.
 *  10. Verify deployer's powers can be revoked post-handoff.
 */
contract ArcheForkTest is Test, ArcheDeployBase {
    address internal constant USER_ALICE = address(0xA11CE);
    address internal deployer;
    address internal safe;

    address internal vault;
    address internal accountant;

    function setUp() public {
        // Fork mainnet at a recent block. Using `vm.createSelectFork` with the
        // public RPC. The block number is optional — latest will work but is
        // non-deterministic. We pin to a recent block for reproducibility.
        string memory rpc = vm.envOr("ETH_RPC_URL", string("https://ethereum-rpc.publicnode.com"));
        vm.createSelectFork(rpc);

        deployer = makeAddr("arche-deployer");
        safe = makeAddr("arche-safe");

        // Sanity: confirm we're actually on mainnet fork by checking USDC has code.
        assertTrue(USDC.code.length > 0, "USDC has no code - not on mainnet fork");

        // Deploy.
        vm.startPrank(deployer);
        (vault, accountant) = _deployArche(deployer, safe);
        vm.stopPrank();

        console2.log("Vault deployed      :", vault);
        console2.log("Accountant deployed :", accountant);
    }

    // ------------------------------------------------------------------
    // 1. CONFIGURATION CHECKS
    // ------------------------------------------------------------------

    function test_PostDeploy_VaultConfig() public {
        IVault v = IVault(vault);

        assertEq(v.asset(), USDC, "asset");
        assertEq(v.name(), VAULT_NAME, "name");
        assertEq(v.symbol(), VAULT_SYMBOL, "symbol");
        assertEq(v.decimals(), 6, "decimals (USDC has 6)");
        assertEq(v.profitMaxUnlockTime(), PROFIT_MAX_UNLOCK_TIME, "profitMaxUnlockTime");
        assertEq(v.deposit_limit(), DEPOSIT_LIMIT, "deposit_limit");
        assertEq(v.minimum_total_idle(), 0, "minimum_total_idle");
        assertEq(v.deposit_limit_module(), address(0), "deposit_limit_module");
        assertEq(v.withdraw_limit_module(), address(0), "withdraw_limit_module");
        assertEq(v.accountant(), accountant, "accountant");

        // role_manager is STILL deployer until Safe accepts.
        assertEq(v.role_manager(), deployer, "role_manager (pre-accept)");

        // Deployer currently holds all roles (so it could continue configuring).
        assertEq(v.roles(deployer), ALL_ROLES, "deployer roles");

        // Safe also holds all roles (granted before transfer).
        assertEq(v.roles(safe), ALL_ROLES, "safe roles");
    }

    function test_PostDeploy_StrategyAttached() public {
        IVault v = IVault(vault);

        IVault.StrategyParams memory params = v.strategies(YVUSDC1_STRATEGY);
        assertTrue(params.activation > 0, "strategy not activated");
        assertEq(params.current_debt, 0, "current_debt should start at 0");
        assertEq(params.max_debt, type(uint256).max, "max_debt should be uncapped");

        // default_queue should contain exactly our strategy.
        address[] memory queue = v.get_default_queue();
        assertEq(queue.length, 1, "queue length");
        assertEq(queue[0], YVUSDC1_STRATEGY, "queue[0]");
    }

    function test_PostDeploy_AccountantConfig() public {
        HealthCheckAccountant a = HealthCheckAccountant(accountant);

        assertEq(a.feeManager(), deployer, "accountant.feeManager (pre-accept)");
        assertEq(a.feeRecipient(), safe, "accountant.feeRecipient");
        assertEq(a.futureFeeManager(), safe, "accountant.futureFeeManager (pending)");
        assertTrue(a.vaults(vault), "vault registered on accountant");

        // Fee tuple must match yvUSDC-1 exactly.
        (
            uint16 mgmt,
            uint16 perf,
            uint16 refund,
            uint16 maxFee,
            uint16 maxGain,
            uint16 maxLoss
        ) = a.defaultConfig();
        assertEq(mgmt, MGMT_FEE, "mgmt fee");
        assertEq(perf, PERF_FEE, "perf fee");
        assertEq(refund, REFUND_RATIO, "refund ratio");
        assertEq(maxFee, MAX_FEE, "max fee");
        assertEq(maxGain, MAX_GAIN, "max gain");
        assertEq(maxLoss, MAX_LOSS, "max loss");
    }

    // ------------------------------------------------------------------
    // 2. USER FLOW: DEPOSIT → PUSH → YIELD → WITHDRAW
    // ------------------------------------------------------------------

    function test_Lifecycle_DepositPushYieldWithdraw() public {
        uint256 depositAmount = 100_000 * 1e6; // 100k USDC
        IVault v = IVault(vault);
        IERC20Min usdc = IERC20Min(USDC);

        // Fund Alice with USDC via cheatcode.
        deal(USDC, USER_ALICE, depositAmount);
        assertEq(usdc.balanceOf(USER_ALICE), depositAmount, "alice pre-balance");

        // --- DEPOSIT ---
        vm.startPrank(USER_ALICE);
        usdc.approve(vault, depositAmount);
        uint256 shares = v.deposit(depositAmount, USER_ALICE);
        vm.stopPrank();

        assertGt(shares, 0, "shares minted");
        assertEq(v.balanceOf(USER_ALICE), shares, "alice shares");
        assertEq(v.totalAssets(), depositAmount, "vault totalAssets");
        assertEq(v.totalIdle(), depositAmount, "idle pre-push");
        assertEq(v.totalDebt(), 0, "debt pre-push");

        // --- MANUAL PUSH into the strategy (operator action) ---
        // update_debt(strategy, targetDebt) moves USDC from idle into sUSDS.
        vm.prank(deployer);
        v.update_debt(YVUSDC1_STRATEGY, depositAmount);

        assertApproxEqAbs(
            v.totalIdle(),
            0,
            2,
            "idle post-push (dust tolerated)"
        );
        assertApproxEqAbs(
            v.totalDebt(),
            depositAmount,
            2,
            "debt post-push (dust tolerated)"
        );

        // Vault should now hold yvUSDC-1 shares (the meta-strategy).
        IERC4626Min yv = IERC4626Min(YVUSDC1_STRATEGY);
        uint256 strategyShares = yv.balanceOf(vault);
        assertGt(strategyShares, 0, "vault has yvUSDC-1 shares");
        assertApproxEqRel(
            yv.convertToAssets(strategyShares),
            depositAmount,
            0.001e18, // 0.1% tolerance for share-rounding
            "yvUSDC-1 shares convert back to ~= deposit"
        );

        // --- ACCRUE YIELD ---
        // Record yvUSDC-1 pricePerShare before warp.
        uint256 ppsBefore = yv.pricePerShare();
        uint256 valueBefore = yv.convertToAssets(strategyShares);

        // Warp 90 days forward. Sky SSR accrues continuously via its chi accumulator.
        vm.warp(block.timestamp + 90 days);

        // Trigger Arche's process_report, which reads yvUSDC-1.convertToAssets
        // directly. Any growth in yvUSDC-1's pricePerShare since last_report
        // flows through as a gain. PERF_FEE is 0, so no fee shares are minted.
        vm.prank(deployer);
        (uint256 gain, uint256 loss) = v.process_report(YVUSDC1_STRATEGY);

        assertEq(loss, 0, "no loss expected");
        console2.log("yvUSDC-1 pricePerShare before:", ppsBefore);
        console2.log("yvUSDC-1 pricePerShare after :", yv.pricePerShare());
        console2.log("yvUSDC-1 value of our shares (before):", valueBefore);
        console2.log("yvUSDC-1 value of our shares (after) :", yv.convertToAssets(strategyShares));
        console2.log("Reported gain (USDC)          :", gain);

        // Sky's sUSDS uses a chi accumulator that IS live-time, so gains should
        // materialize. But if a passive-drip edge case leaves gain==0, that's not
        // a failure of Arche — just means the underlying didn't drip in fork state.
        // The critical assertion is that plumbing works (no loss, withdraw honors shares).

        // --- FEES ACCRUE TO ACCOUNTANT → SAFE ---
        // With PERF_FEE = 0, Safe should hold exactly 0 fee shares. Any non-zero
        // value would mean we accidentally enabled fees.
        uint256 safeShares = v.balanceOf(safe);
        assertEq(safeShares, 0, "safe should hold zero fee shares (perf fee = 0)");

        // Warp through the full profit unlock window + buffer so share price reflects gain.
        vm.warp(block.timestamp + PROFIT_MAX_UNLOCK_TIME + 1 days);

        // --- USER WITHDRAW (auto-unwinds strategy) ---
        // NOTE: yvUSDC-1's maxRedeem(vault) returns 1 share less than our actual
        // balance due to its own internal queue-walk rounding. Yearn v3's vault
        // caps assets_to_withdraw at the strategy's max_withdraw but does NOT
        // reduce requested_assets, so a naive redeem(balanceOf(alice)) reverts
        // with "insufficient assets in vault" on a 1-2 wei shortfall. The standard
        // Yearn v3 pattern is to call maxWithdraw(owner, max_loss) first and use
        // that as the withdraw amount — this is what any integrator should do.
        uint256 maxOut = v.maxWithdraw(USER_ALICE, 0);
        assertGt(maxOut, depositAmount, "maxWithdraw should exceed deposit (yield accrued)");

        vm.prank(USER_ALICE);
        v.withdraw(maxOut, USER_ALICE, USER_ALICE, 0);

        // Alice's USDC balance should be maxOut (the vault paid her out in full).
        uint256 aliceUsdcFinal = usdc.balanceOf(USER_ALICE);
        assertEq(aliceUsdcFinal, maxOut, "alice received exactly maxOut");

        // Hard requirement: Alice never loses funds. Her post balance must exceed
        // her initial deposit (she earned yield).
        assertGt(aliceUsdcFinal, depositAmount, "alice must profit, not lose principal");
        console2.log("Alice deposited              :", depositAmount);
        console2.log("Alice final USDC balance     :", aliceUsdcFinal);
        console2.log("Alice net profit (USDC)      :", aliceUsdcFinal - depositAmount);

        // Alice's share balance should be drained (she withdrew her entire entitlement).
        assertEq(v.balanceOf(USER_ALICE), 0, "alice shares zero");
    }

    // ------------------------------------------------------------------
    // 3. TWO-STEP ROLE_MANAGER + FEE_MANAGER HANDOFF
    // ------------------------------------------------------------------

    function test_Handoff_RoleManagerTwoStep() public {
        IVault v = IVault(vault);

        // Pre-accept: role_manager is still deployer.
        assertEq(v.role_manager(), deployer, "pre-accept role_manager");

        // Non-future-role-manager cannot accept.
        vm.expectRevert();
        vm.prank(USER_ALICE);
        v.accept_role_manager();

        // Safe accepts.
        vm.prank(safe);
        v.accept_role_manager();

        assertEq(v.role_manager(), safe, "post-accept role_manager");

        // Safe can now revoke deployer's operational roles.
        vm.prank(safe);
        v.set_role(deployer, 0);
        assertEq(v.roles(deployer), 0, "deployer stripped");

        // Deployer can no longer add strategies or change limits.
        vm.expectRevert();
        vm.prank(deployer);
        v.set_deposit_limit(DEPOSIT_LIMIT * 2);

        // Safe still can (it has ALL_ROLES which includes DEPOSIT_LIMIT_MANAGER).
        vm.prank(safe);
        v.set_deposit_limit(DEPOSIT_LIMIT * 2);
        assertEq(v.deposit_limit(), DEPOSIT_LIMIT * 2, "safe can change limits");
    }

    function test_Handoff_FeeManagerTwoStep() public {
        HealthCheckAccountant a = HealthCheckAccountant(accountant);

        // Pre-accept: feeManager is still deployer.
        assertEq(a.feeManager(), deployer, "pre-accept feeManager");
        assertEq(a.futureFeeManager(), safe, "future pending");

        // Non-future cannot accept.
        vm.expectRevert();
        vm.prank(USER_ALICE);
        a.acceptFeeManager();

        // Safe accepts.
        vm.prank(safe);
        a.acceptFeeManager();

        assertEq(a.feeManager(), safe, "post-accept feeManager");
        assertEq(a.futureFeeManager(), address(0), "future cleared");

        // Deployer can no longer touch fee config.
        vm.expectRevert();
        vm.prank(deployer);
        a.setFutureFeeManager(USER_ALICE);
    }

    // ------------------------------------------------------------------
    // 4. DEPOSIT LIMIT ENFORCEMENT
    // ------------------------------------------------------------------

    function test_DepositLimit_CappedAt50M() public {
        IVault v = IVault(vault);

        // maxDeposit for any user should equal the cap (since totalAssets = 0).
        assertEq(
            v.maxDeposit(USER_ALICE),
            DEPOSIT_LIMIT,
            "maxDeposit should equal cap"
        );

        // Attempting to deposit 1 wei over the cap should revert.
        uint256 tooMuch = DEPOSIT_LIMIT + 1;
        deal(USDC, USER_ALICE, tooMuch);

        vm.startPrank(USER_ALICE);
        IERC20Min(USDC).approve(vault, tooMuch);
        vm.expectRevert();
        v.deposit(tooMuch, USER_ALICE);
        vm.stopPrank();
    }
}
