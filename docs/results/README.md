# Local verification evidence

Session 2026-09-05–06, Apple Silicon. Commands: `bash scripts/check.sh` and `python3 scripts/negative.py`. Full logs are adjacent; negative.log deliberately contains fatal failures and confirms each expected detection. Synthesis log is generic, not a physical area/timing report.

## SHA-256 of tested sources

```text
673e6c96bc1b064d564310749f91e8d2f518e4e34b4be5ac461e4f7ccbf79853  SPEC.md
1aae5d94e4e55709e07c6278aba1d55f83d24cfc8fb154b725acea4c7f4014b1  rtl/axis_cdc.sv
24a25b925cc376c68e2d5f6dadd88d516f79e6eb1cc65a834e72b291de603e09  rtl/async_fifo.sv
44f3b0b7cb1c5011d6c0358e8d8ec56914bfc828ae610e45712943637da841eb  rtl/properties.svh
75eaca524da1ff0036fc14bf505fb5ac5ab69db6d3281ed7cf494c92406bfba4  tb/tb_axis_cdc.sv
31c8f22ec9a2488cc3c243a8f114c6e29d5bbbddfd02b5477214cfbda1a08f22  scripts/check.sh
59feb8b1344b7a22587fa559713a4dd01c46defcd2bff25fd705d735893bfc43  scripts/negative.py
```

Trailing whitespace from tool formatting is normalized in the checked-in synthesis log; the raw rerunnable log is generated under build/.
