# Agentforce Panel Launcher

**Date:** 2026-06-22
**Author:** Documentation Agent
**Status:** Completed

---

## Overview

### Original Request

Build a new standalone Lightning Web Component ("launcher") that uses the Agentforce Conversation Client (ACC) API — the headless `lightning/accApi` module. The component renders a small UI that drives the native Agentforce side panel. Required behavior:

- Buttons: "Open Agentforce" and "Close".
- A few preset quick-action buttons that call `execute()` with preset utterances.
- An optional text input for a custom utterance, sent via `execute()`.
- Configurable agent/bot Id via `@api botId`, exposed in Lightning App Builder (not hardcoded).
- Graceful Promise/error handling with toast notifications on failure.
- Fire-and-forget UX: `execute()` does not return the agent's reply — the component confirms the utterance was sent, not the agent's answer.
- Exposed in Lightning App Builder for Record Pages, Home Pages, and App Pages.
- API version 65.0. Component name: `agentforcePanelLauncher`.

No Apex, no custom objects, no triggers — LWC only.

### Business Objective

Provides a configurable launcher panel that lets users interact with the native Agentforce side panel directly from any Lightning page — without navigating away or opening a separate app. Admins configure which agent to target once in Lightning App Builder; end users get one-click quick actions and a free-text input that send natural-language utterances to the Agentforce agent.

### Summary

`agentforcePanelLauncher` is a four-file LWC bundle that integrates with Salesforce's native Agentforce side panel through the headless `lightning/accApi` module. It exposes Open/Close panel controls, three configurable preset quick-action buttons, and a custom text input — all backed by async/await error handling and toast notifications. The agent/bot Id is configurable per page placement in Lightning App Builder and is never hardcoded.

---

## The ACC API: `lightning/accApi`

### What It Is

`lightning/accApi` is Salesforce's **Agentforce Conversation Client (ACC) API** — a headless JavaScript module available in Lightning Web Components. "Headless" means the module itself renders no chat UI and displays no conversation thread. It acts solely as a message router: it sends commands and utterances to the **native Agentforce side panel** that Salesforce renders independently. The component using `lightning/accApi` is responsible for its own launcher UI only.

Reference: [https://developer.salesforce.com/docs/platform/accsdk/guide/acc-api.html](https://developer.salesforce.com/docs/platform/accsdk/guide/acc-api.html)

### The Three Methods

All three functions are imported as named exports:

```js
import { open, close, execute } from 'lightning/accApi';
```

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `open` | `open(botId?: string): Promise<void>` | `Promise<void>` | Opens the native Agentforce side panel. `botId` is optional — when omitted or blank, ACC opens the last-accessed agent. |
| `close` | `close(): Promise<void>` | `Promise<void>` | Closes the native Agentforce side panel. Takes no arguments. |
| `execute` | `execute(utterance: string, botId: string): Promise<void>` | `Promise<void>` | Sends a natural-language utterance to the agent. **Fire-and-forget:** the Promise resolves when the message is delivered to the panel, not when the agent replies. The agent's response is never returned to the calling component. |

### Constraints and Prerequisites

| Constraint | Detail |
|------------|--------|
| Minimum API version | 59.0 (component uses 65.0) |
| Environment | Lightning Experience only — does not work in Salesforce Classic or the Salesforce mobile app |
| Org prerequisite | Agentforce must be enabled on the org |
| `botId` for `execute()` | Required — `execute()` does not fall back to a default agent |
| `botId` for `open()` | Optional — falls back to the last-accessed agent when blank |
| Utterance type | Natural language only — no direct Agentforce action execution |
| Agent reply | `execute()` is fire-and-forget; the agent's reply is never returned to the LWC |

---

## Component Details

### Files Created

| File | Purpose |
|------|---------|
| `agentforcePanelLauncher.js` | Component controller — all ACC calls, state management, error handling |
| `agentforcePanelLauncher.html` | Template — card layout, Open/Close buttons, preset quick-actions, custom input |
| `agentforcePanelLauncher.js-meta.xml` | Metadata — API version, targets, `botId` targetConfig property |
| `agentforcePanelLauncher.css` | Minimal styling — stretch buttons to column width, inline-block preset buttons |

All files are located at:
`force-app/main/default/lwc/agentforcePanelLauncher/`

### JavaScript Controller: Key Properties and Methods

#### Public API Property

```js
@api botId;
```

- Type: `String`
- Configured per page placement in Lightning App Builder via `targetConfigs` in `js-meta.xml`.
- Never hardcoded in the component.
- Used as the second argument to `execute()` and as an optional argument to `open()`.

#### Reactive State

| Property | Decorator | Description |
|----------|-----------|-------------|
| `isBusy` | none (reactive by default in LWC) | Set to `true` while any ACC call is in flight; disables all controls. Reset in `finally` block, so it always clears even on error. |
| `customUtterance` | `@track` | Bound to the custom text input field. Cleared after a successful `handleSend()`. |

#### Computed Getters

| Getter | Returns `true` when... | Used to... |
|--------|------------------------|-----------|
| `hasNoBotId` | `botId` is blank, `null`, or whitespace-only | Show the configuration warning banner; guard `execute()` calls |
| `isSendDisabled` | `isBusy` is `true` OR `customUtterance` is blank | Disable the Send button |
| `isExecuteDisabled` | `isBusy` is `true` | Disable all preset quick-action buttons while a call is in flight |

#### Preset Utterances

The preset buttons are driven by a module-level constant array that developers can freely edit:

```js
const PRESET_UTTERANCES = [
    { id: 'preset-summarize', label: 'Summarize this record',   utterance: 'Summarize this record' },
    { id: 'preset-cases',     label: 'Show my open cases',      utterance: 'Show my open cases' },
    { id: 'preset-email',     label: 'Draft a follow-up email', utterance: 'Draft a follow-up email' }
];
```

- `id` must be unique (used as the `for:each` iterator key in the template).
- `label` is the button text shown to the user.
- `utterance` is the exact string sent to `execute()`.
- To add, remove, or change presets, edit this array — no HTML changes are needed; the template iterates it dynamically.

#### Event Handlers

| Handler | Triggered by | ACC call made |
|---------|-------------|---------------|
| `handleOpen()` | "Open Agentforce" button click | `open(botId?)` — passes `undefined` when `botId` is blank |
| `handleClose()` | "Close" button click | `close()` |
| `handlePreset(event)` | Any preset quick-action button click | `sendUtterance(event.currentTarget.dataset.utterance)` → `execute(utterance, botId)` |
| `handleSend()` | "Send" button click | `sendUtterance(customUtterance)` → `execute(utterance, botId)` |

#### The `sendUtterance()` Private Method

All `execute()` calls are routed through the private `sendUtterance(utterance)` method, which centralises:

1. **botId guard** — if `hasNoBotId` is true, fires an error toast ("Set the Agentforce Bot Id in the component properties") and returns `false` without calling the API.
2. **Empty utterance guard** — returns `false` immediately for blank strings.
3. **isBusy flag** — set to `true` before the call, cleared in `finally`.
4. **Success toast** — on resolve, fires a `success` toast showing the utterance text that was sent ("Sent to Agentforce").
5. **Error toast** — on rejection, fires an `error` toast with the error message.
6. **Return value** — returns `true` on success, `false` on any guard or error. `handleSend()` uses this to decide whether to clear the input field.

#### Error Message Extraction

```js
reason(error) {
    return (error && (error.body?.message || error.message)) || 'Unknown error.';
}
```

Handles both wrapped Salesforce `body.message` errors and standard JavaScript `Error.message` errors.

### HTML Template

The template is wrapped in a `lightning-card` with title "Agentforce Panel Launcher" and the `utility:einstein` icon. It is divided into four sections:

| Section | Markup pattern | Notes |
|---------|---------------|-------|
| Configuration warning | `lwc:if={hasNoBotId}` warning box | Visible only when `botId` is not set; uses SLDS `slds-theme_warning` |
| Panel controls | Two-column grid with "Open Agentforce" (brand) and "Close" (neutral) buttons | Both disabled by `{isBusy}` |
| Quick actions | `for:each` loop over `presets` array | Each button passes its utterance via `data-utterance`; disabled by `{isExecuteDisabled}` |
| Custom message | `lightning-input` (label hidden) + "Send" button | Input bound to `customUtterance`; Send disabled by `{isSendDisabled}` |

A "Working..." inline indicator appears (`lwc:if={isBusy}`) at the bottom while any ACC call is in flight.

### CSS

```css
.acc-preset {
    display: inline-block;
}

.slds-button_stretch {
    width: 100%;
}
```

Minimal: ensures preset buttons wrap correctly and Open/Close buttons fill their grid columns.

---

## js-meta.xml Configuration

```xml
<LightningComponentBundle>
    <apiVersion>65.0</apiVersion>
    <isExposed>true</isExposed>
    <masterLabel>Agentforce Panel Launcher</masterLabel>
    <description>Headless launcher that opens, closes, and sends utterances to the native Agentforce side panel via the Agentforce Conversation Client (ACC) API.</description>
    <targets>
        <target>lightning__RecordPage</target>
        <target>lightning__HomePage</target>
        <target>lightning__AppPage</target>
    </targets>
    <targetConfigs>
        <!-- botId property is defined identically for each target -->
        <targetConfig targets="lightning__RecordPage"> ... </targetConfig>
        <targetConfig targets="lightning__HomePage">   ... </targetConfig>
        <targetConfig targets="lightning__AppPage">    ... </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

The `botId` property is declared in each `targetConfig` block with:

| Attribute | Value |
|-----------|-------|
| `name` | `botId` |
| `type` | `String` |
| `label` | `Agent/Bot Id` |
| `description` | Explains that it is required for quick actions and custom messages; `open()` uses the last-accessed agent when blank |

The same property block is repeated for all three targets so admins can set a different agent per page type (e.g., a different agent on RecordPage vs. HomePage).

---

## Data Flow and Architecture

### How It Works

```
1. Admin adds agentforcePanelLauncher to a Lightning page in Lightning App Builder.
2. Admin sets the Agent/Bot Id property for that page placement.
3. User views the page — the component renders its launcher card.
4. User clicks "Open Agentforce":
       Component calls open(botId) → ACC opens the native Agentforce side panel.
5. User clicks a preset button (e.g., "Summarize this record"):
       Component guards botId → calls execute('Summarize this record', botId)
       → ACC routes the utterance to the agent in the side panel
       → Agent replies IN the side panel (not returned to the component)
       → Component fires a success toast: "Sent to Agentforce"
6. User types a custom message and clicks "Send":
       Component guards botId and non-blank text → calls execute(text, botId)
       → Same fire-and-forget flow as step 5.
       → Input field is cleared on success.
7. User clicks "Close":
       Component calls close() → ACC closes the native Agentforce side panel.
```

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Lightning App Builder                                                       │
│  Admin sets: botId = "0XxXXXXXXXXXXXXXXX"                                   │
└────────────────────────────┬────────────────────────────────────────────────┘
                             │ @api botId injected at runtime
                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  agentforcePanelLauncher (LWC)                                               │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  ┌────────────┐ │
│  │ Open button  │  │ Close button │  │ Preset buttons    │  │ Send btn   │ │
│  │ handleOpen() │  │handleClose() │  │ handlePreset()    │  │handleSend()│ │
│  └──────┬───────┘  └──────┬───────┘  └────────┬──────────┘  └─────┬──────┘ │
│         │                 │                   │                     │        │
│         ▼                 ▼                   └──────────┬──────────┘        │
│   open(botId?)         close()                          ▼                   │
│                                               sendUtterance(text)           │
│                                               [botId guard]                 │
│                                               execute(text, botId)          │
└─────────┬───────────────────┬────────────────────────────┬───────────────────┘
          │ Promise           │ Promise                     │ Promise
          ▼                   ▼                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  lightning/accApi  (headless — no rendered UI)                               │
│                                                                              │
│  Routes open/close/execute calls to the NATIVE Agentforce side panel.       │
└─────────────────────────────────────────────────────────────────────────────┘
          │                   │                             │
          ▼                   ▼                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Native Agentforce Side Panel  (rendered by Salesforce platform)             │
│                                                                              │
│  Agent reply displayed HERE — never returned to the LWC component.          │
└─────────────────────────────────────────────────────────────────────────────┘

On any Promise rejection:
   ShowToastEvent (variant=error) dispatched from agentforcePanelLauncher
```

---

## File Locations

| File | Path |
|------|------|
| JavaScript controller | `force-app/main/default/lwc/agentforcePanelLauncher/agentforcePanelLauncher.js` |
| HTML template | `force-app/main/default/lwc/agentforcePanelLauncher/agentforcePanelLauncher.html` |
| Metadata | `force-app/main/default/lwc/agentforcePanelLauncher/agentforcePanelLauncher.js-meta.xml` |
| CSS | `force-app/main/default/lwc/agentforcePanelLauncher/agentforcePanelLauncher.css` |

---

## How to Use / Setup

### Prerequisites

1. **Agentforce must be enabled** on the Salesforce org. Without it, `lightning/accApi` will not function.
2. **Lightning Experience only.** The component will not work in Salesforce Classic or the mobile app.
3. **A valid Bot/Agent Id is required** for the quick-action and custom-message features. The component renders and opens the panel without one (the `open()` call passes `undefined` and ACC uses the last-accessed agent), but all `execute()` paths are blocked until a `botId` is configured.

### Adding the Component to a Page

1. Open **Lightning App Builder** (Setup > Lightning App Builder or the App Builder icon on a Record/App/Home page).
2. Select or create the page where the launcher should appear.
3. In the component palette, search for **"Agentforce Panel Launcher"**.
4. Drag the component to the desired region on the page canvas.
5. In the right-hand properties panel, set the **Agent/Bot Id** field to the Id of your Agentforce agent.
6. Save and activate the page.

### Finding the Bot/Agent Id

The Bot Id is the 18-character Salesforce Id of the Bot record. It can be found in Setup under **Einstein Bots** (or **Agentforce Agents**) — select the agent and copy the Id from the URL or record detail.

### Editing the Preset Utterances

The preset quick-action buttons are defined in the `PRESET_UTTERANCES` constant at the top of `agentforcePanelLauncher.js`. To customise them, edit that array directly — no HTML changes are needed.

```js
const PRESET_UTTERANCES = [
    { id: 'preset-summarize', label: 'Summarize this record',   utterance: 'Summarize this record' },
    { id: 'preset-cases',     label: 'Show my open cases',      utterance: 'Show my open cases' },
    { id: 'preset-email',     label: 'Draft a follow-up email', utterance: 'Draft a follow-up email' }
];
```

Rules: `id` must be unique across all entries; `label` is the button text; `utterance` is the string sent to Agentforce.

---

## Distinction from `sfAiAgent`

This project also contains an `sfAiAgent` LWC component. These two components serve entirely different purposes and use different architectures:

| Aspect | `agentforcePanelLauncher` | `sfAiAgent` |
|--------|--------------------------|-------------|
| Architecture | Headless — uses `lightning/accApi` to drive the **native** Agentforce side panel | Custom chat UI — calls **Apex** which calls an external GPT/AI API |
| Renders conversation | No — the native side panel renders all responses | Yes — displays its own conversation thread in the component |
| Apex dependency | None | Yes (AuraEnabled Apex controller) |
| Agent reply accessible in LWC | No — fire-and-forget | Yes — response returned from Apex and displayed in the UI |
| Configuration | `botId` set in Lightning App Builder | Configured via Apex/Named Credentials |

Do not conflate these two components. `agentforcePanelLauncher` is the correct component for integrating with Salesforce's native Agentforce side panel. `sfAiAgent` is a custom-built chat interface with its own AI backend.

---

## Limitations

1. **Fire-and-forget execution.** `execute()` resolves when the utterance is delivered to the panel, not when the agent has processed it or responded. The agent's reply is never accessible in the LWC. The component cannot display, log, or act on the agent's answer.

2. **Lightning Experience only.** `lightning/accApi` does not function in Salesforce Classic or the Salesforce mobile app. If the component is placed on a page accessed from Classic or mobile, the buttons will appear but ACC calls will fail or be silently unavailable.

3. **`botId` required for execute paths.** If the admin forgets to configure the Bot Id in Lightning App Builder, the warning banner will appear and all preset/custom-message buttons will be blocked with an error toast. The "Open Agentforce" button still works (falls back to last-accessed agent), but no utterances can be sent.

4. **No agent reply feedback.** Because execute is fire-and-forget, the component can only confirm that the utterance was dispatched — not that the agent understood, responded, or completed any action. Users must look at the Agentforce side panel for responses.

5. **Utterances are natural language only.** The ACC API does not support direct invocation of Agentforce actions or topics by API name. All instructions to the agent must be phrased as natural-language utterances.

6. **No LWC Jest tests.** This component does not have Jest unit tests. `lightning/accApi` would need to be mocked in a Jest test environment. Jest tests should be added before this component goes to a production org.

7. **Race condition on rapid button clicks.** The `isBusy` flag prevents concurrent in-flight calls but it is client-side only. If `isBusy` somehow fails to prevent a second click (e.g., programmatic invocation), two concurrent `execute()` calls to the same `botId` could occur.

---

## Notes and Considerations

### Future Enhancements

- Make `PRESET_UTTERANCES` configurable through a Custom Metadata Type or Custom Setting so admins can manage presets without deploying code.
- Add a `@api panelLabel` property to customise the card title per placement.
- Add keyboard shortcut support (e.g., Enter to send the custom utterance).
- Add Jest unit tests mocking `lightning/accApi`.

### Dependencies

| Dependency | Type | Required |
|------------|------|----------|
| `lightning/accApi` | Platform module | Yes — core integration |
| `lightning/platformShowToastEvent` | Platform module | Yes — error/success feedback |
| Agentforce enabled on org | Org configuration | Yes |
| Valid Bot/Agent Id | Admin configuration | Yes (for execute paths) |

---

## Change History

| Date | Author | Change Description |
|------|--------|-------------------|
| 2026-06-22 | Documentation Agent | Initial creation |
