# CLAUDE.md - order-service (fixture)

Plain-text "procedure card" host, ported from a fictional donor for the SW-40 `port-parity`
fixture. No toolchain: `.txt` files under `src/`, one `member <Name>` block per procedure, numbered
steps, `end member` terminator.

## Conventions

- Validation members are named `Check<Noun>`.
- Failure-handling members are named `Handle<Noun>`.
