# Handling a Report That Isn't DONE

Part of superpowers-extended-cc:subagent-driven-development.

**DONE_WITH_CONCERNS:** The implementer completed the work but flagged doubts. Read the concerns before proceeding. If the concerns are about correctness or scope, address them before review. If they're observations (e.g., "this file is getting large"), note them and proceed to review.

**NEEDS_CONTEXT:** The implementer needs information that wasn't provided. Provide the missing context and re-dispatch.

**BLOCKED:** The implementer cannot complete the task. Assess the blocker:
1. If it's a context problem, provide more context and re-dispatch with the same model
2. If the task requires more reasoning, re-dispatch with a more capable model
3. If the task is too large, split it into parts. Ledger
   `Task <id>: Ruling: split into <id>a (<what>) and <id>b (<what>) — <why>`,
   one lowercase letter per part, skipping i, l and o; a part that splits
   again alternates to a number (K3.4 → K3.4a, K3.4b; K3.4a → K3.4a1,
   K3.4a2, never K3.4aa). Do not edit the plan: each part becomes a full work task
   instead. `TaskCreate` it in writing-plans' format, titled
   `<part id>: <what>`, with its own Goal, Files, Acceptance Criteria and
   Verify and a `json:metadata` block (with a tier when routing is on),
   and add it to `.tasks.json`. The first part takes the parent's
   blockers; each later part is blocked by the one before. The parent task
   stays: add every part to its blockers. It is never dispatched, and it
   completes when its last part does.
   Dispatch each part from its own task (TaskGet), with the parent's brief
   (`task-brief` with the parent id) for context. Each part gets its own
   report file (`task-<part id>-report.md`), its review gate against its
   own Acceptance Criteria, and its completion line. Use the part ids from
   then on, in commits and the final message too.
4. If the plan itself is wrong, rule on the correction, ledger it, and re-dispatch with the ruling carried in the dispatch

**Never** ignore an escalation or force the same model to retry without changes. If the implementer said it's stuck, something needs to change.
