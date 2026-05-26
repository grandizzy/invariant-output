# Invariant output sample

Sample Foundry project with multiple invariant test suites used to showcase
forge invariant output (`--show-progress` spinner, JSON pulse stream, etc.).

## Setup

```bash
git clone --recurse-submodules https://github.com/grandizzy/invariant-output
cd invariant-output
forge build
```

## Test commands

Run all invariant suites with the live progress spinner (≈10s):

```bash
forge test --match-contract Invariants --show-progress
```

Run only the deliberately broken suite to see counterexample output:

```bash
forge test --match-contract BuggyBankInvariants -vv
```

Single suite, longer run so the spinner ticks visibly:

```bash
FOUNDRY_INVARIANT_RUNS=1000 FOUNDRY_INVARIANT_DEPTH=400 \
  forge test --match-contract VaultInvariants --show-progress -vv
```

Crank it (≈45s+, lots of spinner activity):

```bash
FOUNDRY_INVARIANT_RUNS=2000 FOUNDRY_INVARIANT_DEPTH=500 \
  forge test --match-contract Invariants --show-progress
```

JSON pulse stream (no spinner). Requires `show_edge_coverage = true` under
`[invariant]` in `foundry.toml` (already set):

```bash
forge test --match-contract StakingInvariants
```

Sample pulse line:

```json
{"timestamp":1779773265,"event":"pulse","invariant":"invariant_stakingSolvent",
 "metrics":{"cumulative_edges_seen":10,"cumulative_features_seen":3,
            "corpus_count":0,"favored_items":0,"failures":0,
            "unique_failures":0,"broken_handlers":0},
 "total_txs":47000,"total_gas":2998046031,
 "tx_per_sec":9396.56,"gas_per_sec":599389784.58}
```

## Layout

| Path | Description |
|---|---|
| `src/Token.sol`   | Minimal ERC20-ish token |
| `src/Vault.sol`   | 1:1 ERC4626-ish vault |
| `src/Staking.sol` | Stake/unstake with points accrual |
| `src/BuggyBank.sol` | **Has a deliberate accounting bug** (transfer doesn't debit the sender) |
| `test/Token.invariants.t.sol`     | 3 invariants, 4-selector handler |
| `test/Vault.invariants.t.sol`     | 4 invariants, deposit/withdraw flows |
| `test/Staking.invariants.t.sol`   | 3 invariants, stake/unstake/roll/claim |
| `test/BuggyBank.invariants.t.sol` | 1 invariant — **fails by design** to demo counterexample output |
