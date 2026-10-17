# Roadmap

How we get from the current single-player prototype to the online game described in `GAME_DESIGN.md`.
Sizes are rough effort, not dates: **S** = a session or two, **M** = several sessions, **L** = many sessions, **XL** = ongoing.

Nothing here is a promise. Phases can be reordered, and **each phase should leave the game playable**.

---

## The big idea: build it server-authoritative

For online play, one program (the **server**) decides what really happens: where players are, who got hit, who captured a point.
Every player's game (a **client**) sends what the player *wants* to do ("move forward", "shoot") and displays what the server says happened.

This one decision gives us everything the design document asks for:

| You want | How it falls out of the design |
|---|---|
| Player-hosted games | One player's game also runs the server |
| Dedicated servers | The same project, exported headless as a server (Godot supports this natively) |
| Bots that are "fully optional" | Bots are simply server-side players |
| Offline practice and tutorial | The game runs as a server with one local client, using the same code |
| Some cheat resistance | Clients can't just *say* they hit someone; the server checks |

**Status: Leaning.** It's worth confirming before we build on it.

---

## Phase 0: Lock the foundations (S)

Mostly decisions, almost no code.

- [ ] Confirm the server-authoritative model above.
- [ ] Choose the transport plan: **start with Godot's built-in network (ENet)**, and swap in Steam networking later. The Steam add-ons for Godot are changing quickly (two community ones were archived or paused in December 2025), so we should re-check the options when we get to Phase 4, not commit now.
- [ ] Settle open design questions that affect the build (see "Questions to settle" at the bottom).
- [ ] Add the architecture rules (below) to the design document.

**Proposed architecture rules** (to be added to section 8 of the design doc):

1. **One place decides damage.** Nothing but the server applies damage or changes health.
2. **Input is an intent.** Gameplay reads "move", "shoot", "ability 1", never raw keys or the mouse.
3. **Gameplay never calls the HUD, audio, or effects directly.** It announces an event ("player hit", "point captured"), and the client's HUD, audio, and effects react to it.
4. **Never assume one player.** No code that looks for "the" player.

---

## Phase 1: A throwaway networking spike (S to M)

Before reorganizing the real game, build a tiny separate test project to learn Godot's networking in practice:

- Two game windows, one hosting and one joining by IP address.
- Players that move and shoot, with the server deciding hits.
- See what lag actually feels like, and how to hide it for your own movement.
- Try it with a friend over the internet (this tests port forwarding or relay).

**Why:** this is the biggest unknown in the project. Learning it in a small sandbox is cheap; discovering it halfway through refactoring the real game is not. The spike is meant to be thrown away.

**Done when:** two people can run around, shoot, and kill each other in a blank room, and we understand why it works.

---

## Phase 2: Make the game network-ready (L)

Reorganize the existing game so it *could* be networked, while keeping it playable offline the whole time.
Each step is independently testable, and the first one is useful on its own.

1. **Input abstraction (M).** Move all controls onto Godot's input actions, so `Tab` and mouse-look are no longer hard-coded. This also unlocks **key rebinding and controller support**, both in your design doc.
2. **Split the player (L).** `player.gd` currently mixes input, movement, shooting, abilities, camera, HUD, audio, and effects. Separate it into the part that *decides* (the server's job) and the part that *shows* (camera, HUD, effects, sound: each client's job).
3. **Route all damage through one function (M).** Kills, assists, and stats all depend on it.
4. **Split `GameManager` (M).** Today one object holds match state, spawning, and stats. Separate the *state* (the server owns it) from how it's *displayed* (each client's HUD reads it).
5. **Make bots server-side only and support any number of players (M).** Remove the "there is exactly one player" assumptions.
6. **Run offline play through the server path (S).** Single-player becomes "host a match with one local player and some bots".

**Done when:** the game plays exactly as it does today, but gameplay code doesn't depend on a single local player, and nothing in it calls the HUD directly.

---

## Phase 3: Networked prototype (L)

Your first milestone: *friends can play together online.*

- Join by IP, then a simple lobby (pick faction and class, ready up).
- Players, shooting, abilities, health, death and respawn, capture points, scoreboard, kill feed, and death screen all working across the network.
- Bots fill empty slots when the host wants them.
- Basic text chat.
- Test with friends in different places.

**Done when:** you and a friend can play a full attack/defend round against each other over the internet.

---

## Phase 4: Steam integration (L)

- Steamworks setup, using Valve's test app ID while developing.
- Friend invites and lobbies through Steam, which also takes care of connecting players through firewalls.
- Re-evaluate the networking add-ons at this point and choose one.
- Steam progression and stats (your decision: Steam services), plus Steam Cloud for settings.
- Windows and Linux cross-play test (already **Decided**).
- Automate Steam builds from the existing GitHub workflow.

**Done when:** you can invite a friend on Steam, and you both end up in a match.

---

## Phase 5: Gameplay depth from the design doc (XL)

Roughly in this order, because each builds on the one before:

1. **Weapons.** An open question, so a design session comes first. The new class roster depends on it.
2. **Healer class.** It adds new systems (healing others), so do it before the other classes.
3. **Four classes per faction.** Healer, Tank, Long Range, Short Range, with three abilities each.
4. **New modes.** King of the Hill, then Team Deathmatch, then the rest.
5. **Series and round structure** for the online setting.
6. **Balance tooling.** The stats system we built is the start of this.

---

## Phase 6: Levels, art, and audio (XL, runs in parallel)

This is probably the largest *work* in the project, and you have no art pipeline yet.

- **Level design study** (a prerequisite for the "level design principles" in your doc).
- **First real map**, built as a simple grey-box first and decorated later.
- **Art direction:** a short style guide (palette, proportions, reference images in the TF2 spirit).
- **A character pipeline:** who makes models and animations, and with what tools.
- **Audio plan,** including a log of every outside asset and its license.

Because this blocks "final quality feel", it's worth starting the learning and style decisions early, **in parallel** with Phases 2 to 4.

---

## Phase 7: Player-facing features (L)

Tutorial and practice range, spectator mode, replays (your "would be incredible" one), rebinding and accessibility options, matchmaking, and dedicated servers.

---

## Phase 8: Playtests, alpha, beta, release (XL)

Alpha and beta definitions, a Steam store page, and the Early Access decision.

---

## Biggest risks (honest list)

| Risk | Why it matters | What reduces it |
|---|---|---|
| Retrofitting networking onto a single-player design | The most common way multiplayer projects stall | Phase 1 spike, then Phase 2 before any big new content |
| Art volume | Solo developer, no art pipeline, up to 16 classes and 8 to 10 maps eventually | Start the pipeline early; set a small first-release scope |
| Server hosting and matchmaking cost | Matchmaking over dedicated servers costs money every month | Launch with player-hosted games over Steam; add dedicated servers later |
| Cheating | Player-hosted servers can't be fully trusted | Be honest that ranked-style play needs dedicated servers |
| Steam networking add-ons are in flux | A dependency could be abandoned | Build on Godot's standard network first; the Steam part stays swappable |
| Solo time and motivation | A long project with no deadline can drift | Keep every phase small and playable; the vertical slice is the real goal |

---

## Questions to settle

1. **Are the four classes per faction unique to each faction** (eight different classes) **or the same four roles with different looks and abilities?** This changes the art and balance work a lot.
2. **Should offline play against bots remain a lasting mode** (for practice and the tutorial)? If so, Phase 2's "offline uses the server path" step is essential.
3. **How will weapons work?** (This is your "let's figure that out.") It affects classes, balance, and animation.
4. **Hardware target.** We can measure first: pick a low-end machine you can test on, then decide.
