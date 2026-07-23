# Plan - FEAT-example

## Phased overview

- Foundation: T01
- Behavior: T02

## Sequencing rationale

T01 lands the type before T02 wires the behavior onto it. Critical path is T01 -> T02.

## Risks

- The upstream interface T02 assumes may differ from the sample. Mitigation: verify at implementation.

<!-- SL070: T02 in 02-tasks.md carries `Revised-by: R1`, but this plan has no `## Revisions`
     section and therefore no `R1` entry. The marker is dangling. -->
