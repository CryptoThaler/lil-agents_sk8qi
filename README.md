# lil_sk8ers

![Lil Sk8ers](LilSk8ers-hero.png)

`lil_sk8ers` is a customized dockside AI companion app built around two streetwear skaters cruising on transparent skateboard loops above your macOS dock.

Thank you to the `lil agents` creator for the inspiration to flow.

Get your agents into flow skate. Make them `lil_sk8ers`.

This fork keeps the original interaction model intact while reshaping the visual identity around two new characters, a dual-provider AI path, and a stronger direction for a future control surface.

## what changed in this fork

- Replaced Bruce and Jazz with two new skaters: `AXO` and `Mudbug`
- Swapped the original walking loops for realistic skateboard motion in transparent video
- Added a provider switch so the app can route chats to `Claude Code` or `OpenAI (Codex)`
- Added a live session meter with reset controls so the popover shows active usage while you chat
- Updated onboarding, menu labels, and README copy to match the new `lil_sk8ers` world
- Added packaged preview renders and a downloadable macOS app archive to the repo

## meet the lil_sk8ers

### AXO

![AXO](generated-axo.png)

`AXO` is an axolotl in teal streetwear with a gold-accent board, built as the softer and more playful skater in the pair. AXO sets the tone for the dock: friendly, relaxed, expressive, and always ready to spin up a conversation with Claude or Codex.

### Mudbug

![Mudbug](generated-mudbug.png)

`Mudbug` is a lobster in warm orange streetwear with a darker board and cooler accent linework. Mudbug plays as the heavier, punchier counterpart to AXO: same vibe, same gear, more edge.

## current experience

- Animated skaters rendered from transparent `.mov` loops
- Click a skater to open a dockside terminal chat
- Watch live session stats for `Codex` or `Claude Code` while the chat is open
- Switch providers from the menu bar: `Claude Code` or `OpenAI (Codex)`
- Four visual themes: Peach, Midnight, Cloud, Moss
- Thinking bubbles and completion sounds
- First-run onboarding
- Auto-updates via Sparkle

## build and run

### requirements

- macOS Sonoma (14.0+)
- [Claude Code CLI](https://claude.ai/download) and/or a local `codex` CLI install

### local build

Open the included Xcode project in Xcode and hit Run.

### packaged download

A downloadable archive is included at:

`dist/lil_sk8ers-1.0-axo-mudbug-macos.zip`

## interface direction

The next obvious step for `lil_sk8ers` is a proper graphical control panel instead of treating the menu bar as the only switchboard.

### a strong next UI pass could include

- A compact floating dashboard with a clear `Claude / Codex` segmented toggle
- Live skater cards showing `idle`, `thinking`, and `responding` states
- Clickable character portraits so users choose which skater opens the chat
- A visual session rail showing recent prompts, completions, and active provider
- A richer token/usage dashboard with provider-specific telemetry beyond the compact live strip
- Theme, sound, and display controls grouped into a single skater console
- Future deck, outfit, and motion-pack swaps without changing the underlying app logic

### the product idea

Instead of a hidden utility, `lil_sk8ers` can evolve into a small character-driven AI surface on the desktop:

- part assistant switcher
- part dock toy
- part ambient chat UI

The core interaction is already there. The next layer is making provider choice and skater identity feel intentional, visual, and fun.

## privacy

`lil_sk8ers` runs entirely on your Mac and sends no personal data anywhere on its own.

- **Your data stays local.** The app plays bundled animations and calculates dock geometry to position the skaters. No project data, file paths, or personal information is collected by the app itself.
- **AI providers.** Conversations are handed to the local CLI you select. Any upstream processing is governed by the provider you choose.
- **No accounts.** No login, no analytics, no in-app user database.
- **Updates.** Sparkle checks for updates using your app version and macOS version.

## license

MIT License. See [LICENSE](LICENSE) for details.
