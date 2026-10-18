# Apes vs Aliens: Game Design

A living document. It records what the game is meant to become, so we build toward the same target.
Keep it short. Write **decisions**, not wishes, and mark each as:

- **Decided**: settled; build to it.
- **Leaning**: probably this, but open to change.
- **Open**: not decided; ask before assuming.

*Last updated: (10/17/26)*

---

## 1. The pitch

**One sentence:** *(Test the waters for class based warfare (since its so early, I don't have much of a pitch))*

**Pillars** (3 to 5 things every decision should serve, e.g. "whimsical but competitive", "readable at a glance"):

1. Whimsical and competitive class based shooter
2. Reward strategy rather than blind gunplay
3. The game is firstly fun, then competitive

**Inspirations:** *(Games, shows, or art that capture the feel. Say what you take from each.)*

1. Garden Warfare 2 (Absurd and goofy class based shooter that has incredibly fun modes, gunplay, and a wealth of content.)
2. Team Fortress 2 (Longstanding community, incredible strategy, and instantly recognizable charm)

---

## 2. Audience and release goals

- **Who is it for?** *(Casual friends? Competitive players? Both?)*
    - Both casual players and competitive players.
- **Platforms:** *(Windows, Linux, Steam Deck, controller support, others?)*
    - Windows and Linux, with controller support.
- **Release path:** *(Steam. Early Access first, or a full 1.0? Any rough timeline?)*
    - Steam, I have no timeline, no need to rush. 
- **Monetization:** *(Paid, free-to-play, cosmetics-only? "Open" is fine.)*
    - I do not know yet. 
- **Scope reality:** *(Solo or team? Hours per week? What does a realistic first release look like?)*
    - Solo developer, do not know how much time I can dedicate.

---

## 3. Multiplayer (decide these first: they shape the code)

| Question | Answer | Status |
|---|---|---|
| Players per match (e.g. 5v5, 8v8)? | 8v8 | Open |
| Hosting: dedicated servers, player-hosted, or both? | Both | Leaning |
| Bots online: fill empty slots? Fully optional? | Fully optional | Open |
| Lobbies, matchmaking, private matches, friends invites? | Matchmaking, private matches, friend invites | Leaning |
| Account and progression: Steam services, own backend, or local-only? | Steam services | Leaning |
| Cheating: how much do we defend against? (This decides who is "in charge" of the game state.) | Unknown | Open |
| Voice or text chat? | Text Chat | Leaning |
| Target latency and regions? | Unknown | Open |
| Cross-play between Windows and Linux? | Yes | Decided |

**Notes:** *(Anything else that matters, like ranked play, spectators, or private tournaments.)*

---

## 4. Core gameplay

- **Modes:** *(Attack/defend is in. What else, and in what order? King of the Hill? Team deathmatch?)*
 - Attack/defend, King of the Hill, Team Deathmatch, any modes we come up with.
- **Round structure:** *(Length, overtime, swapping sides, series format.)*
 - Undecided length, certainly overtime, certainly swapping sides, and some kind of series format.
- **Classes:** *(How many at release? What roles? Can multiple players pick the same class?)*
 - Probably 4 per side to start. Healer, Tank, Long Range, Short Range, Multiple players can pick the same class.
- **Abilities:** *(Roughly how many per class? Any ones you refuse to ship?)*
 - 3 abilities per class. Unknown about refused abilities.
- **Weapons:** *(Class-locked weapons only? Unlocks? Attachments?)*
 - TF2 sort of system, with fast or low damage weapons being hitscan, and high impact weapons usually being projectiles. Start with each character having one weapon. We can add variants later on. Class locked weapons.
- **Balance philosophy:** *(Target time-to-kill, how much skill vs. ability vs. luck, what counts as "too strong".)*
 - No target time to kill yet. Rock paper scissors type matchups, with skill being prioritized a little more than luck. Undecided on what is too strong.
- **Movement:** *(Jump, slide, climb? Speed and how forgiving it is.)*
 - Jump, no slide, possible climb for certain characters. I don't want characters to be incredibly fast. Characters have speeds similar to TF2. 

---

## 5. Content plan

| Content                                   | At first release                                  | Later                          |
| ----------------------------------------- | ------------------------------------------------- | ------------------------------ |
| Classes                                   | 4 classes per side                                | Up to 6 or more per side later |
| Maps (and their themes)                   | At least 3 maps to start                          | Want at least 8-10 later       |
| Game modes                                | Undecided                                         | At least 5                     |
| Cosmetics (hats, skins, emotes)           | Undecided, although receptive                     | Undecided as well              |
| Progression (levels, unlocks, challenges) | Levels, unlocks, challenges, although unsure what | More of each of them           |

**Level design principles:** *(Lanes? Verticality? Cover density? How long should a capture push take?)*
 - I have to look into level design before writing here.

---

## 6. Art and audio

- **Style:** *(Stylized? Realistic? Color palette? A few reference images help a lot.)*
 - Think something like Team Fortress 2. Not realistic, but you can tell what everything is even through the fun style. 
- **Character and asset pipeline:** *(Who makes the models and animations: you, a commissioned artist, purchased packs? Which tools?)*
 - No one right now. 
- **Level assets:** *(Modular kit, a bought pack, hand-built?)*
 - Hand built right now. 
- **Audio:** *(Music, voice lines, sound effects. Where do they come from, and what licenses do you have?)*
 - Free files with licenses. 
- **Licenses:** *(Keep a list of every outside asset and its license. Steam will ask.)*
 - Just the license in the sound files, written in the README for now.

---

## 7. Player-facing features

- **Menus and flow:** *(What should the path from launch to a match feel like?)*
 - Undecided, but not complicated.
- **Settings:** *(Controls rebinding, FOV, graphics options, accessibility.)*
 - Controls rebinding, graphics options, FOV, crosshair, frame rate, probablyy accessibility.
- **Social and meta:** *(Friends list, party system, stats, match history, leaderboards.)*
 - I like all the recommended ideas. 
- **Spectating and replays:** *(Wanted? For whom: players, casters?)*
 - Spectating for players. Replays would be incredible to get working. 
- **Onboarding:** *(Tutorial, practice range, training against bots.)*
 - Definitely some sort of tutorial, practice range
- **Languages:** *(English only at first? Localize later?)*
 - English first.

---

## 8. Technical decisions

- **Engine:** Godot (version: ), renderer: *(Forward+ now. Confirm for the target hardware.)*
 - I have no clue what the hardware target should be.
- **Minimum spec and performance target:** *(e.g. 60 fps on what GPU at what resolution?)*
 - Leaning: Compatibility, but focus on good mid tier play.
- **Networking approach:** *(Godot's built-in multiplayer, a plugin, Steam networking? Authority model?)*
 - No idea.
- **Code architecture rules:** *(e.g. "gameplay logic must not read input directly", "one place decides damage".)*
 - No decisions made. 
- **Testing and builds:** *(Automated checks? How are builds made and shared?)*
 - No idea, probably all manual.

---

## 9. Milestones

| Milestone | What "done" means | Rough target |
|---|---|---|
| Prototype | *(Playable single-player loop. This is where we are.)* | Playable multiplayer loop |
| Networked prototype | *(Friends can play together online.)* | Players from far away can play together |
| Vertical slice | *(One polished map, a few classes, final-quality feel.)* | Multiple maps, multiple classes for each team, with clean feeling gameplay. |
| Alpha | idk | idk |
| Beta / playtests | idk | idk |
| Release | idk | idk |

---

## 10. Non-goals

*(Things we are deliberately NOT doing. This prevents scope creep and is just as useful as the goals.)*

- No battlepass monetization

---

## 11. Open questions and decision log

| Date     | Question or decision                   | Outcome                                                                          |
| -------- | -------------------------------------- | -------------------------------------------------------------------------------- |
| 10/17/26 | Offline play against bots              | Remains a mode                                                                   |
| 10/17/26 | Weapon behaviors                       | Hitscan for fast weapons, projectiles for slow, with explicit exceptions allowed |
| 10/17/26 | Accuracy, damage, and weapon structure | TF2-style spread, falloff curves, one weapon per class at launch                 |
| 10/17/26 | Hardware target                        | Leaning: 8 GB RAM, low-end GPU. Decide the renderer by testing                   |
| 10/18/26 | Classes per faction                    | Four as a baseline: healer, tank, long-range, short/mid-range                    |
| 10/18/26 | Weapon exceptions                      | Allowed                                                                          |
| 10/18/26 | Explosion knockback and self-damage    | Allowed; per weapon, and case by case for abilities                              |
| 10/18/26 | Spread and movement                    | Moving does not widen spread                                                     |
| 10/18/26 | Reloads                                | Different for each weapon                                                        |
