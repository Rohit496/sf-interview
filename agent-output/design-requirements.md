═══════════════════════════════════════════════════════════════════════════════
                    📋 DESIGN REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════════

🎯 WHAT USER REQUESTED:
Build a NEW standalone Lightning Web Component ("launcher") that uses the
Agentforce Conversation Client (ACC) API — the headless `lightning/accApi`
module. The component renders a small UI that drives the NATIVE Agentforce side
panel (the module itself renders no chat UI). Required behavior:

- Buttons: "Open Agentforce", "Close".
- A few preset quick-action buttons that call execute() with preset utterances.
- An optional text input for a custom utterance, sent via execute().
- Configurable agent/bot Id via a clean approach (@api property exposed in
  Lightning App Builder), not hardcoded.
- Graceful Promise/error handling (toast on failure). execute() is
  fire-and-forget (does not return the agent reply) — design the UX around that.
- Exposed in Lightning App Builder for record pages, home pages, and app pages
  (targets + exposed=true in js-meta.xml).
- API version 65.0. Suggested component name: agentforcePanelLauncher.

Constraints from ACC API (informational, not implementation tasks):
- Org must be API 59.0+, Agentforce enabled, Lightning Experience only.
- Module: `lightning/accApi` (headless). Functions: `open(botId?)`,
  `close()`, `execute(utterance, botId)` — all return Promises.
- Only natural-language utterances supported; no direct action execution.

EXPLICITLY OUT OF SCOPE (per user): NO Apex, NO custom objects, NO triggers.

───────────────────────────────────────────────────────────────────────────────
                    🔵 ADMIN WORK (salesforce-admin)
───────────────────────────────────────────────────────────────────────────────

No admin work required for this request.

(No custom objects, fields, validation rules, permission sets, or flows were
requested. The org-level prerequisites — Agentforce enabled, Lightning
Experience, API 59.0+ — are environment configuration, not deliverables of this
request, and are NOT to be created as part of this work.)

───────────────────────────────────────────────────────────────────────────────
                    🟢 DEVELOPMENT WORK (salesforce-developer)
───────────────────────────────────────────────────────────────────────────────

All work for this request is Development (LWC-only).

• Lightning Web Component: `agentforcePanelLauncher`
  - Headless integration via the `lightning/accApi` module (import `open`,
    `close`, `execute`).
  - UI: "Open Agentforce" button → calls `open(botId)`.
  - UI: "Close" button → calls `close()`.
  - UI: a set of preset quick-action buttons, each calling
    `execute(presetUtterance, botId)` with a hardcoded preset utterance string.
    (Note: the SET of preset utterances is not specified by the user — see
    OPEN ITEM below before finalizing the preset list.)
  - UI: optional text input + a "Send" button → calls
    `execute(typedUtterance, botId)` with the user-entered text.
  - All three ACC calls are async/Promise-returning → use async/await or
    `.then()/.catch()`; on rejection, surface a toast via
    `lightning/platformShowToastEvent` (ShowToastEvent).
  - Fire-and-forget UX: because `execute()` does NOT return the agent's reply,
    the component must NOT attempt to display/await an agent response. Success
    feedback should be limited to confirming the utterance was sent (e.g., a
    brief sent/queued indication) — not the agent's answer.

  Configuration property:
  • `@api botId` (String) — the target agent/bot Id, exposed in Lightning App
    Builder via the js-meta.xml `targetConfigs` so admins set it per-placement
    rather than hardcoding. `open()` may be called with or without it; `execute()`
    requires it, so the component should guard against an empty `botId` before
    calling `execute()` (e.g., disable execute buttons / show a toast if unset).

  Files to create (LWC bundle under force-app/main/default/lwc/agentforcePanelLauncher/):
  • agentforcePanelLauncher.js
  • agentforcePanelLauncher.html
  • agentforcePanelLauncher.js-meta.xml
  • agentforcePanelLauncher.css (optional — only if styling is needed for the
    small launcher UI)

  js-meta.xml specification:
  • apiVersion: 65.0
  • isExposed: true
  • masterLabel: "Agentforce Panel Launcher" (label/description as desired)
  • targets:
      - lightning__RecordPage
      - lightning__HomePage
      - lightning__AppPage
  • targetConfigs: expose the `botId` @api property (type="String",
    label="Agent/Bot Id") for the three targets above so it is configurable in
    Lightning App Builder.

───────────────────────────────────────────────────────────────────────────────
                    🔗 EXECUTION ORDER
───────────────────────────────────────────────────────────────────────────────

Single deliverable — no internal dependencies. Per project workflow, since this
is LWC-only (no Apex):
1. salesforce-developer — build the component.
2. salesforce-code-review — review the component.
3. salesforce-devops + salesforce-documentation — deploy and document (parallel).
(Skip salesforce-admin: no admin work. Skip salesforce-unit-testing: no Apex.)

───────────────────────────────────────────────────────────────────────────────
                    ❓ OPEN ITEM (confirm before/with build)
───────────────────────────────────────────────────────────────────────────────

The user asked for "a few preset quick-action buttons" but did NOT specify the
exact preset utterances or how many. The developer needs concrete strings to
build them. Either:
  (a) the user provides the specific preset button labels + utterances, OR
  (b) the developer uses clearly-marked placeholder presets that an admin/dev
      can edit (no business meaning assumed).
This is the one detail not fully specified; everything else is unambiguous.

───────────────────────────────────────────────────────────────────────────────
                    📝 PROMPTS FOR SPECIALIST AGENTS
───────────────────────────────────────────────────────────────────────────────

🟢 PROMPT FOR salesforce-developer:
"""
Create a new headless-integration Lightning Web Component named
`agentforcePanelLauncher` at
force-app/main/default/lwc/agentforcePanelLauncher/.

Use the Agentforce Conversation Client (ACC) API headless module
`lightning/accApi`, importing its three Promise-returning functions:
  - open(botId?: string): Promise<void>
  - close(): Promise<void>
  - execute(utterance: string, botId: string): Promise<void>
This module routes messages to the NATIVE Agentforce side panel; it renders no
chat UI of its own, so this component must NOT try to render a conversation or
display the agent's reply.

UI to build:
  - "Open Agentforce" button → open(this.botId) (botId optional; if empty, ACC
    uses the last-accessed agent).
  - "Close" button → close().
  - A few preset quick-action buttons, each calling execute(presetUtterance,
    this.botId). NOTE: the exact preset utterances were NOT specified by the
    user. Use clearly-labeled placeholder presets (e.g., utterance constants the
    admin can edit) unless the user provides specific ones; do not invent
    business-specific logic.
  - An optional text input plus a "Send" button → execute(typedUtterance,
    this.botId) with the user-entered text.

Configuration:
  - Expose `@api botId` (String) and surface it in Lightning App Builder via
    targetConfigs. Do NOT hardcode the bot Id.
  - execute() requires a botId — guard against an empty botId before calling
    execute() (disable the execute/preset/send buttons or show a toast when
    botId is unset).

Async / error handling:
  - All three ACC calls are async. Use async/await (or .then/.catch).
  - On any rejected Promise, show an error toast using ShowToastEvent from
    `lightning/platformShowToastEvent`.
  - Because execute() is fire-and-forget (it does NOT return the agent reply),
    limit success feedback to confirming the utterance was sent/queued — do NOT
    await or display an agent response.

js-meta.xml requirements:
  - apiVersion 65.0
  - isExposed true
  - targets: lightning__RecordPage, lightning__HomePage, lightning__AppPage
  - targetConfigs exposing the `botId` property (type String, friendly label)
    for those three targets.

Constraints / scope:
  - LWC ONLY. Do NOT create any Apex, triggers, custom objects, fields, or
    permission sets.
  - Follow project conventions (API 65.0, force-app/main/default).
  - Use ShowToastEvent for user-facing errors (no Apex/AuraHandledException here).
  - Create the bundle files (.js, .html, .js-meta.xml; .css only if needed). Do
    NOT deploy — leave deployment to the devops agent.
"""

═══════════════════════════════════════════════════════════════════════════════
