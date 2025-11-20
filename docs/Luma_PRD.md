# Luma – Product Requirement Document (PRD)

## 1. Overview

**Luma** is a cross-platform assistant (macOS, iOS, Windows in the future) that turns voice into polished text using AI.

The core flow:

1. User selects a **prompt preset** (e.g. *Professional*, *Casual*, *CN → EN*).
2. User optionally speaks a **temporary prompt** for this capture.
3. User speaks the **main content**.
4. Luma:
   - Transcribes audio to text using a speech-to-text model (e.g. Whisper via OpenAI).
   - Combines:
     - System-level prompt
     - User-selected preset prompt
     - Temporary prompt
     - Optional **context from clipboard**
   - Sends the composed prompt and content to an LLM (OpenAI, Gemini, etc.).
   - Returns a rewritten text result.

The backend runs locally at first (single-user, local database), but should be designed with future cloud deployment in mind.

---

## 2. Goals

1. Let users **speak instead of type**, and get high-quality rewritten text.
2. Support **multiple tone/style presets** per user (professional, casual, translation, etc.).
3. Support a **temporary prompt** per capture (spoken by voice).
4. Support **multiple LLM providers and models** (e.g. OpenAI, Gemini).
5. Allow users to configure and store **provider API keys** locally.
6. Support a **clipboard context toggle**:
   - When enabled, the frontend reads text from the clipboard and sends it as “context” to Luma.
   - Luma uses this context to improve the rewrite (e.g. reply to an email, translate in the same style).
7. Provide a lightweight local **transcription history** so users can review or copy previous captures.

---

## 3. Non-Goals (Phase 1)

- Multi-tenant cloud deployment.
- Realtime streaming subtitles / live transcription.
- Collaboration features or shared workspaces.
- Advanced authentication / SSO.
- Offline LLM or on-device models (we assume remote APIs for LLM and STT).
- Complex analytics dashboards.

---

## 4. User Personas

### Persona 1 – Knowledge Worker
Wants to quickly write professional emails or messages from rough spoken input.

### Persona 2 – Multilingual User
Speaks Chinese but often needs to communicate in English or vice versa.

### Persona 3 – Developer / Power User
Wants to integrate Luma into their daily workflow (editor, email client) and use clipboard context to rewrite or translate selected text.

---

## 5. Key User Scenarios

### Scenario A – Professional Email from Voice
1. User selects the **“Professional”** preset.
2. User enables **clipboard context toggle** and copies an email thread.
3. User speaks a temporary prompt: “Reply to this email politely and concisely.”
4. User speaks content: “basically I cannot make it next week…”
5. Luma:
   - Uses clipboard content as context.
   - Transcribes and rewrites into a polished reply.
6. User pastes the final result into their email client.

### Scenario B – Chinese to English Translation
1. User selects **“CN → EN Translation”** preset.
2. Clipboard toggle is off (no context).
3. User skips temporary prompt.
4. User speaks Chinese content.
5. Luma returns fluent English text.

### Scenario C – Casual Chat Message with Context
1. User selects **“Casual”** preset.
2. User copies a friend’s message to clipboard and keeps clipboard toggle on.
3. User speaks temporary prompt: “Reply in a playful tone.”
4. User speaks content.
5. Luma returns a casual reply that fits the context of the copied message.

---

## 6. Functional Requirements

### FR1 – Prompt Presets

- Users can create, update, and delete multiple **prompt presets**.
- Each preset has:
  - A user-friendly name (e.g. “Professional”, “Casual”).
  - A `prompt_text` describing how Luma should rewrite (tone, style, language).
- Luma must list a user’s presets so the frontend can display them.
- User selects one preset for each capture; its `id` is passed to the backend.

### FR2 – System Prompt

- There is a configurable **system prompt** that defines global behavior.
- Exactly one system prompt is active at a time.
- The system prompt is editable (for power users or future admin UI).
- It is combined with the selected preset and temporary prompt during LLM calls.

### FR3 – Prompt Templates & Library

- App ships with a few built-in templates (Default, Professional, Literal) exposed as quick chips.
- Users can save, rename, and delete their own prompts (stored per account via the backend preset APIs).
- Selecting a template/preset shows its text before applying it to a capture.

### FR4 – Temporary Prompt (Per Capture)

- Users may speak a one-off prompt (e.g., “Reply politely”) before the main audio.
- Temporary prompts are captured client-side and attached to the transcription request but are not persisted in the database.

### FR5 – Voice Input and Transcription

- Frontend records audio for:
  - Temporary prompt (optional).
  - Main content.
- Audio is sent to backend as `multipart/form-data`.
- Backend uses a speech-to-text service (e.g. Whisper via OpenAI API).
- Backend returns transcribed text to frontend.

### FR6 – LLM Integration with Multiple Providers

- System supports multiple LLM providers (e.g. OpenAI, Gemini, Anthropic).
- Each provider can have multiple model names.
- The user can select:
  - Provider
  - Model name
- Backend must be able to:
  - Look up the correct API key for the selected provider.
  - Route the request to the appropriate provider-specific implementation.
- LLM call uses:
  - System prompt
  - User preset prompt
  - Temporary prompt
  - Optional **clipboard context**
  - User’s content

### FR7 – API Key Management (Local)

- Backend stores **encrypted API keys** for each provider.
- For MVP, assume single local user, but DB schema should support multiple keys.
- Backend APIs:
  - List saved keys (provider names, last updated; not full keys).
  - Add or update a key for a provider.
  - Delete a key.

### FR8 – Clipboard Context Toggle

- Frontend has a **toggle** “Use clipboard context”.
- When enabled:
  - Frontend reads current clipboard content.
  - Sends it in the request as a `context_text` field (text).
- Backend:
  - Does **NOT** read the clipboard directly (clipboard access is frontend concern).
  - Receives `context_text` as a text string.
  - Includes `context_text` in the composed prompt for the LLM, e.g.:

    > “Here is the context from the user’s clipboard: ... Please write the reply based on this context and the new content.”

- Context is optional. If not provided, rewrite is only based on content + prompts.

### FR9 – Configuration

- Backend reads config from a file (e.g. `config.yaml`) and/or environment variables:
  - Server port
  - Database path
  - Enabled providers
  - Logging level

### FR10 – macOS Onboarding & Permissions

- When the macOS client launches for the first time it must:
  - Request microphone access via the system prompt (`AVAudioSession` / `AVCaptureDevice` APIs).
  - Explain why audio input is required before presenting the system dialog.
  - Provide a way to re-check permission status and deep-link to System Settings if the user previously denied access.
- Future shortcuts that listen globally may require Accessibility permission; the UI should surface instructions if/when that becomes necessary.

### FR11 – Authentication & Session Persistence

- Users authenticate with their Luma account (email + password) via the backend.
- Backend issues a long-lived session cookie stored on the device; it is used instead of passing `user_id` in every request.
- Frontend shows a lightweight login view (email/password fields) until the session is valid, then hides credentials and simply shows the signed-in account info.
- On launch the app silently checks `/api/v1/session`; if the cookie is still valid the user stays logged in without re-entering credentials.
- Logging out clears local caches (API keys, selected provider, hotkey state that depends on the user) and revokes the session on the server.

### FR12 – Frontend Tips & Configuration Hub

- The home view shows a checklist/tips column describing:
  1. Adding an API key.
  2. Writing/customizing a prompt.
  3. Reviewing the capture flow (temporary prompt vs. main content) and ensuring permissions are granted.
- Users must be able to paste their provider API key, label it, and send it to the backend.
- Prefill safe defaults and warn if the backend is unreachable.

### FR13 – Prompt Management UI

- Surface a **prompt library** made of default chips (Default/Professional/Literal) plus user-saved prompts.
- Selecting a chip shows a preview sheet (name + text + copy/apply actions) so the UI stays compact.
- Provide “Add Prompt” flow where the user names a prompt, edits the text, and saves it to the preset API.
- Clipboard-context toggle and manual context field live in the same card for quick adjustments.

### FR14 – Keyboard Shortcuts

- Users can configure two shortcuts:
  - One to capture the **temporary prompt**.
  - One to capture the **main content**.
- Defaults: `⌥` (Option) for main content, `⌘⌥` (Right Command + Option) for temporary prompt—users can customize and even set them to the same combo (press once for prompt, twice for content).
- UI must record the desired key combination and store it locally; future releases will hook this into a background recorder that starts/stops capture based on the shortcut.
- The shortcut recorder must capture full modifier combinations (e.g., `⌘L`, `⌥⇧S`) rather than plain characters so power users can tailor their workflow.

### FR15 – Voice Capture States

- When the prompt shortcut fires:
  - Show a banner indicating “Listening for temporary prompt… tap shortcut again to finish”.
  - Once stopped, preview the transcript before sending it to the backend.
- When the main-content shortcut fires:
  - Similar UI but routed to the main transcription flow (no notion of server-side sessions).
- If the user never records a temporary prompt, the backend relies solely on the system/preset prompts.

---

## 7. Non-Functional Requirements

### NFR1 – Performance

- Typical transcription + rewrite roundtrip latency < 3 seconds (excluding extreme provider delays).
- API endpoints should respond within 100ms for operations that do not call LLM/STT.

### NFR2 – Portability

- Backend must run on macOS, Windows, and Linux.
- No OS-specific dependencies beyond standard Go libraries and SQLite/Postgres drivers.

### NFR3 – Security

- API keys stored **encrypted at rest**.
- No logging of full API keys or user content by default in production mode.
- Since MVP is local and single-user, auth can be skipped initially, but design should allow adding auth later.

### NFR4 – Extensibility

- Clear separation between:
  - HTTP layer
  - Service layer
  - Repository layer
  - Provider-specific LLM adapters
- It should be easy to:
  - Add a new provider.
  - Add new fields to prompts or authentication.
  - Swap SQLite for Postgres.

---

## 8. Success Metrics

- Users can complete the “speak → rewrite → paste” flow within **30 seconds**.
- >90% of attempts to call a selected LLM succeed (no misconfigured keys, provider errors handled gracefully).
- At least 3 distinct presets actively used by a typical power user.
