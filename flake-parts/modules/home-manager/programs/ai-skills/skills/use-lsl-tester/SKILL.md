---
name: use-lsl-tester
description: Load this skill when Codex is asked to create, run, review, or debug automated tests for Linden Scripting Language (.lsl) scripts with the public lsl-tester harness, or to integrate that harness into another flake as compile checks or external-language test suites. This includes function invocation, event or state scenarios, built-in or user-function mocks, virtual time, call inspection, coverage, and peak-memory assertions from Python, TypeScript, Rust, or another language. Do not load it for general LSL authoring, unrelated Rust or Nix work, or development of the lsl-tester framework itself unless the task is specifically about using its test harness.
---

# Use LSL Tester

Use the emulator as a deterministic test process. Prefer focused tests of observable LSL behavior over tests of bytecode implementation details.

## Access the framework

Use the published Nix flake at `github:LisaScheers/lsl-tester`. Treat the working directory as the user's LSL project; do not search for or assume a local checkout of the framework.

Read only the material needed for the task:

- Read [README.md](https://github.com/LisaScheers/lsl-tester/blob/main/README.md) for installation, supported systems, and CLI examples.
- Read [docs/protocol.md](https://github.com/LisaScheers/lsl-tester/blob/main/docs/protocol.md) before implementing or changing a JSON-RPC client, mocks, callbacks, or less common protocol operations.
- Inspect [protocol/schema.json](https://github.com/LisaScheers/lsl-tester/blob/main/protocol/schema.json), or run `lsl-tester schema`, when exact request or response shapes matter.
- Adapt the standard-library [Python example](https://github.com/LisaScheers/lsl-tester/blob/main/examples/python/test_counter.py) or [TypeScript example](https://github.com/LisaScheers/lsl-tester/blob/main/examples/typescript/counter.test.ts) instead of inventing another transport wrapper.
- Read [docs/memory.md](https://github.com/LisaScheers/lsl-tester/blob/main/docs/memory.md) before interpreting Mono estimates or changing memory assertions.
- Read [docs/compatibility.md](https://github.com/LisaScheers/lsl-tester/blob/main/docs/compatibility.md) before claiming compatibility or treating an unmodeled built-in as an emulator defect.
- Read [docs/nix-modules.md](https://github.com/LisaScheers/lsl-tester/blob/main/docs/nix-modules.md) when integrating LSL checks into another flake.

When the LSL project already uses flake-parts, prefer the reusable Nix module over ad hoc `nix run` commands so compilation and language-level suites become native flake checks.

Run the current public version directly:

```console
nix run github:LisaScheers/lsl-tester -- --help
```

For a persistent test process, resolve the package once and use its executable path:

```console
nix build --no-link --print-out-paths github:LisaScheers/lsl-tester#lsl-tester
```

Append `/bin/lsl-tester` to the returned Nix store path. Pass that exact path to the test client, preferably through `LSL_TESTER_BIN`.

Use `github:LisaScheers/lsl-tester` for exploration outside a flake. In a consumer flake, commit `flake.lock` to pin the module and emulator package. For reproducible raw `nix run` commands, use `github:LisaScheers/lsl-tester/<commit>`.

## Integrate another flake

Use the published flake-parts module when the LSL project is a flake-parts flake. Add `lsl-tester` as an input and make its `nixpkgs` and `flake-parts` inputs follow the consumer's inputs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  flake-parts.url = "github:hercules-ci/flake-parts";

  lsl-tester = {
    url = "github:LisaScheers/lsl-tester";
    inputs.flake-parts.follows = "flake-parts";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

Import the default module and declare compile checks and external-language suites under `perSystem.lsl-tests`:

```nix
outputs =
  inputs@{ flake-parts, lsl-tester, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [ lsl-tester.flakeModules.default ];
    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];

    perSystem =
      { pkgs, ... }:
      {
        lsl-tests = {
          scripts.counter = ./scripts/counter.lsl;

          suites.python = {
            command = "python3 ${./tests/test_counter.py}";
            runtimeInputs = [ pkgs.python3 ];
          };
        };
      };
  };
```

This generates `checks.<system>.lsl-compile-counter` and `checks.<system>.lsl-suite-python`. A compile check retains typed bytecode JSON as its output. A suite receives the exact packaged executable through `LSL_TESTER_BIN`; test clients must use that variable instead of assuming a checkout, build directory, or executable location. Packages in `runtimeInputs` are placed on `PATH`.

Use these suite fields only when needed:

- `command`: required shell commands that run the test harness.
- `runtimeInputs`: interpreters and other packages added to `PATH`.
- `environment`: string-valued environment variables exported for the suite.
- `workingDirectory`: an optional read-only source directory. Prefer Nix store paths such as `${./tests/test_counter.py}` when possible, and do not write into the working directory.

Import `lsl-tester.flakeModules.compile` when only source compilation is needed, or `lsl-tester.flakeModules.suites` when only external-language suites are needed. The default module provides both. Override `lsl-tests.package` to use a fork or compatible local emulator package, and set `lsl-tests.checkPrefix` to change the default `lsl` check-name prefix.

The published package supports `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`; do not add `x86_64-darwin`. On another system, omit that system or provide a compatible `lsl-tests.package` override.

Commit the consumer's `flake.lock`, then run all generated checks:

```console
nix flake check
```

Use the complete [consumer-flake example](https://github.com/LisaScheers/lsl-tester/blob/main/examples/nix/flake.nix) and [module reference](https://github.com/LisaScheers/lsl-tester/blob/main/docs/nix-modules.md) when adapting an existing flake.

## Choose the interface

Use the smallest interface that supports the test:

- Use `compile` to validate source or inspect the span-aware AST or typed bytecode.
- Use `run` for one state-entry scenario with optional mocks, event injection, clock advancement, and a final report.
- Use `invoke` for one direct user-function call.
- Use a persistent `serve` process for multi-step unit tests, stateful event sequences, dynamic mocks, reset/reuse, or a test written in another language.

Start with a one-off compile when diagnosing a script:

```console
nix run github:LisaScheers/lsl-tester -- \
  compile path/to/script.lsl --emit bytecode
```

Run a simple scenario:

```console
nix run github:LisaScheers/lsl-tester -- \
  run path/to/script.lsl --compact
```

Invoke a user function directly with tagged values:

```console
nix run github:LisaScheers/lsl-tester -- \
  invoke path/to/script.lsl calculate \
  --arguments '[{"type":"integer","value":21}]' \
  --compact
```

## Write a stateful test

Follow this order for each independent scenario:

1. Resolve the packaged executable as described above, then spawn `<store-path>/bin/lsl-tester serve` with piped stdin and stdout.
2. Send `protocol.version` when the client depends on a particular protocol or compatibility profile.
3. Send `script.load` with the complete LSL source and any configuration, world fixture, or Mono memory model.
4. Install mocks before the first `vm.run_until_idle`. Loading queues `state_entry` but does not run it, which lets tests mock calls made during initialization.
5. Send `vm.run_until_idle` and require `result.status.status == "idle"`, unless deliberately handling a dynamic mock boundary.
6. Inject events with `event.enqueue`, advance time with `clock.advance`, or invoke a function with `function.invoke`.
7. Run until idle after each action that should execute queued work.
8. Fetch `report.get` and assert behavior, calls, errors, memory, mock verification, and focused coverage.
9. Close the child's stdin and require a successful process exit.

Create a new process or call `script.load` for isolation between tests. Prefer independent scenarios over tests that depend on a previous test's globals, clock, mocks, calls, or coverage.

## Implement an NDJSON client correctly

Write one JSON-RPC 2.0 object followed by `\n`, then flush. Read exactly one JSON object per line. Keep stdout exclusively for protocol messages.

Assign a unique numeric request ID and continue reading until the matching response arrives. While waiting, retain notifications such as `mock.call`; do not mistake them for the request response. Convert a response containing `error` into a test failure that includes its structured `data`.

Represent every LSL value explicitly:

```json
{"type":"void"}
{"type":"integer","value":42}
{"type":"float","value":1.5}
{"type":"string","value":"hello"}
{"type":"key","value":"11111111-1111-1111-1111-111111111111"}
{"type":"vector","value":[1.0,2.0,3.0]}
{"type":"rotation","value":[0.0,0.0,0.0,1.0]}
{"type":"list","value":[{"type":"integer","value":1}]}
```

Use `"nan"`, `"infinity"`, and `"-infinity"` for non-finite floats. Do not send untagged primitives where the protocol expects an LSL value.

Use the project's existing testing stack. If the surrounding project has no preference, use Python's `unittest` and standard library for the thinnest portable harness.

## Configure deterministic dependencies

Use a world fixture for stable host identity or epoch data:

```json
{
  "owner_key": "11111111-1111-1111-1111-111111111111",
  "object_key": "22222222-2222-2222-2222-222222222222",
  "unix_epoch_seconds": 1786492800
}
```

Prefer static mocks for specific behavior. Mock built-ins and user functions by the same target-name mechanism:

```json
{
  "target": "calculatePrice",
  "arguments": [
    { "match": "exact", "value": { "type": "integer", "value": 3 } }
  ],
  "outcomes": [
    { "kind": "return", "value": { "type": "integer", "value": 99 } }
  ],
  "repeat_last": false,
  "expected_calls": 1
}
```

Apply these mock rules:

- Leave `arguments` empty to match any argument list.
- Use `any`, `exact`, or `type` matchers when argument behavior matters.
- Use ordered outcomes for deterministic successive calls.
- Set `repeat_last` only when repeated behavior is intended.
- Set `expected_calls` and assert `all_mock_expectations_satisfied` in the final report.
- Use `call_through` to observe a matched call while executing its real implementation.
- Use `return_and_schedule` to model asynchronous operations by returning a value and queuing typed events.
- Use `error` to exercise script failure paths.
- Use `dynamic` only when the controlling test must compute a result from the live call.

For a dynamic mock, retain the `mock.call` notification, consume the response whose status is `awaiting_mock`, and then send `mock.respond`. Repeat if resumption reaches another dynamic boundary.

Treat runtime error `R0100` as an explicit request for a fixture or mock when the call requires simulator-world behavior. Do not add nondeterministic network, grid, physics, asset, inventory, or wall-clock behavior to make such a test pass.

## Drive events and virtual time

Inject event arguments using tagged LSL values and exact catalog signatures. Call `vm.run_until_idle` after enqueueing an event.

Use `clock.advance` for time-dependent behavior. Never sleep the host test process to wait for an LSL timer or delayed event. Advance to the required virtual time and run until idle. Timer state, sleeps, delayed mock events, deterministic random values, and generated keys all belong to the emulator session.

Test state changes through observable ordering and state:

- Assert `state_exit` effects occur before the next state's `state_entry` effects.
- Assert `report.state.current_state` and relevant globals.
- Assert timer behavior explicitly when a transition should preserve or replace it.
- Avoid asserting internal bytecode positions unless testing the compiler itself.

## Assert the report

Always check the failure surfaces before domain-specific assertions:

```text
execution status is idle
report.runtime_errors is empty
report.all_mock_expectations_satisfied is true
```

Then assert only relevant observations:

- `state.globals` and `state.current_state` for script state.
- `last_return_value` for direct function invocation.
- `calls` for target, arguments, order, mocked/call-through flags, and outcome.
- `host_effects` for chat and owner-say output.
- `coverage.functions` for the functions or event handlers the scenario intends to exercise.
- `memory.peak_emulated_bytes`, `peak_breakdown`, and `peak_location` for memory constraints.

Treat `peak_emulated_bytes` as exact under the emulator's logical accounting model, not as Rust process RSS or certified Second Life Mono memory. Use `memory.reset_peak` immediately before the measured action when setup should be excluded from the high-water interval. Assert a Mono estimate only after supplying a versioned calibration model with real provenance, and label it as an estimate.

Prefer a useful upper bound for memory and targeted coverage assertions over snapshots of the entire report. Full-report snapshots are brittle and obscure which behavior matters.

## Validate the test

For a project that imports the reusable module, run its generated flake checks:

```console
nix flake check
```

For a project that does not import the module, run the script through the published compiler, then run the new test with the LSL project's focused test command:

```console
nix run github:LisaScheers/lsl-tester -- \
  compile path/to/script.lsl --emit bytecode
<project-test-command>
```

Do not run the framework's Rust, Clippy, or flake checks when only an external LSL script or its tests changed.
