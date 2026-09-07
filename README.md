# FindJob Career Explorer

A small branded campaign for an existing Roblox game. Players meet a Career Agent, answer two questions,
and try either classroom support or a route-programming puzzle. The missions make the career match playable:
teaching focuses on helping people understand, while software engineering focuses on planning and debugging.

## Player Flow

1. Load the campaign with the on-screen button, then approach the FindJob booth.
2. Answer two questions about a satisfying challenge and a preferred outcome.
3. Enter the matched mission: help ten students in the classroom, or solve three increasingly large route puzzles.
4. Receive feedback after each answer or route. Students with unresolved questions return after a short delay.
5. Complete the mission, return to the host game, see the FindJob message, and receive a reward.

Both career answers must be valid. Matching answers select that profession; when answers disagree, the
second answer takes priority because it describes the outcome the player wants. With two binary questions,
this deliberately makes the second answer decisive. This is a simple conversation prompt, not a career assessment.

## Installation

This project contains a self-installing Roblox package. At runtime, the package moves server code into
`ServerScriptService.Campaign` and publishes assets, client code, and shared modules under
`ReplicatedStorage.Campaign`.

For guaranteed server-code privacy, place `Campaign` beneath `ServerScriptService`. The installer also
supports `Workspace` and `ReplicatedStorage`, including while a server is running, but server modules can briefly
replicate when the unopened model starts in a replicated location. Scripts do not execute from `ServerStorage`, so
the model cannot install itself from there.

## Getting Started
Install the tools listed in `rokit.toml`, install the Wally dependencies, and build the place:

```bash
rokit install
wally install
rojo build -o "homework-assignment.rbxlx"
```

Open the place in Roblox Studio and start the Rojo server.

```bash
rojo serve
```

To build a standalone drop-in model with its dependencies included:

```bash
rojo build model.project.json --output Campaign.rbxm
```

The binary model contains one `Campaign` folder with `assets`, `server`, `client`, and `shared`
(including `shared.Packages`). Insert `Campaign.rbxm` into your existing Studio place and move
`Campaign` beneath `ServerScriptService` before running the game.

After pushing these files, publish a GitHub release whose tag includes the workflow and model project.
The release workflow installs the tools and Wally dependencies, builds `Campaign.rbxm` from that tag,
and attaches it to the release's downloadable assets. Published prereleases also trigger the build;
saving a draft does not. Rerunning the workflow replaces the existing `Campaign.rbxm` asset.

For more help, check out [the Rojo documentation](https://rojo.space/docs).

## Rewards and Host Integration

The default server reward adds one to the player's `FindJobCareerTokens` attribute. The demo UI displays
the balance. Tokens survive character respawns and campaign toggles during the same player session;
they are not saved between server visits. Each new completed mission earns one token.

A host game can replace this behavior with `CampaignService.setRewardHandler(handler)` from its server
integration. The handler receives `(player, context)` and returns `(granted: boolean, receipt: string)`.
The context contains `sessionGuid`, `missionId`, and `profession`. Return success only after the host's
currency, inventory, or badge system has actually granted the reward. Registering a handler before
campaign initialization is supported; initialization does not overwrite it.

Use `context.sessionGuid` as the host reward transaction key when grants involve yielding or persistent
storage. The campaign caches successful receipts for five minutes and prevents repeat completion of an
active mission; a host reward system owns durable idempotency and persistence. Failed grants are logged
and the completion message tells the player that the reward was unavailable.

## Measurement

Tracking prints to the server console, as requested by the brief. No external endpoint is contacted.
Every event includes campaign, campaign-session, host universe/place/server, timestamp, and demo identifiers;
mission events also include the mission-session identifier and profession.

| Measurement | Purpose |
| --- | --- |
| Booth impression and engagement | Compare awareness with willingness to interact. |
| Career completion and displayed classification | Find drop-off in the two-question flow and inspect the profession split. |
| Mission start, progress, completion, and abandonment | Measure participation, completion rate, and where players leave. |
| Teaching answers, retries, and response time | Identify confusing questions and observe engagement with teaching. |
| Software route attempts, failures, rounds, and duration | Identify puzzle difficulty and debugging behavior. |
| Reward success/failure | Check whether completed experiences deliver their promised outcome. |

Booth and career funnel milestones count once per player visit. Replaying a mission creates a new mission
session, so mission events can occur several times within one campaign session. Client visibility receipts
are best-effort signals with server validation and rate limits; they are not proof that a player read the UI.

## Assumptions and Cross-Game Constraints

- UK players load automatically. `DEMO_MODE = true` in `src/shared/constants/campaign.luau` lets the manual
  load button work in any region for evaluation. Demo sessions are labeled in tracking. Set it to `false`
  for region-restricted deployment; Studio still allows manual testing.
- The 18+ audience is a targeting assumption for the host campaign. The prototype does not verify age;
  audience eligibility must be supplied by the host before a real campaign launch.
- Booth placement comes from the supplied model. Mission spaces use reserved positions above the demo
  map. A host must select suitable positions and coordinate these moves with its own teleport/anti-cheat logic.
- Environments and student appearances are built locally. The server owns mission tokens, progress,
  success conditions, reward grants, and student placement used for proximity checks.
- Unloading removes the local booth and active mission assets and abandons the mission. The small loader,
  reward display, shared templates, and network handlers remain available for reloading.
- A host supplies its own reward adapter and persistence. Names, placement, audience eligibility, and
  analytics export need explicit integration decisions when moving this prototype to another game.

## Validation and Further Work

Before publishing, play both missions in Studio, try an incorrect answer and blocked route, leave during a
mission, reset the character, and toggle the campaign off and on. Check that the button survives respawn,
the token count increases once per completion, and both endings show the FindJob message. Repeat in a
two-player session and with simulated network latency. Build from a fresh checkout to verify packaging.

With more time, prioritize published-game and mobile testing, host-configurable placement and audience
eligibility, persistent reward adapters with recovery, and exporting the existing event schema to a backend.
The classification could be expanded with additional questions and a richer scoring model.

## AI Assistance

OpenAI Codex was used to review the implementation against the assignment brief, investigate edge cases,
implement fixes, and run build and isolated regression checks. Roblox Studio playtesting is still required
to verify the final gameplay, animation assets, and UI layout in the target host game.
