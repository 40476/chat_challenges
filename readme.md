# 💬 Chat Challenges for Minetest

Welcome to **Chat Challenges**, the mod that turns your server chat into a chaotic game show where players compete for glory, random items, and the fleeting satisfaction of typing faster than someone else.

If you've ever wanted your players to feel like they're trapped in a game show hosted by a caffeinated squirrel, you're in the right place.

---

## 🧠 What Is This?

This mod throws random challenges into the chat like confetti at a parade. Players must solve them to win rewards. Challenges include:

- 🔀 **Descramble**: Unscramble item names. It's like solving a word puzzle while someone yells at you.
- 🧩 **Missing Letter**: Guess the missing character. Because who needs complete words anyway?
- ⌨️ **Typing**: Just type the word. Seriously. That’s it.
- 🚨 **Reaction**: Type “go” faster than your friends. It's like a reflex test, but with peer pressure.
- 🧮 **Math**: Basic arithmetic. If you fail this one, we won’t judge... much.

---

## 🏆 Rewards

Winners get random items like:

- 🍎 `default:apple` — Nature’s participation trophy.
- ⛏️ `default:pick_steel` — For when you want to dig your way out of embarrassment.
- 💎 `default:mese_crystal` — Because shiny things make everything better.

---

## ⚙️ Configuration

Customize your chaos in `minetest.conf` by tweaking these settings:

| Setting                                | Default Value | Description                                                                 |
|----------------------------------------|---------------|-----------------------------------------------------------------------------|
| `chat_challenges_interval`             | `300`         | Time between challenges (in seconds). Enough time to forget how to spell.  |
| `chat_challenges_timeout`              | `16`          | Time before the challenge gives up on humanity.                            |
| `chat_challenges_disallow_symbols`     | `true`        | No weird characters. Keep it vanilla.                                      |
| `chat_challenges_disallow_numbers`     | `true`        | Numbers? In my item names? Not on my watch.                                |
| `chat_challenges_rewards`              | `default:apple,default:pick_steel,default:mese_crystal` | Items players win for surviving the chaos. |
| `chat_challenges_enabled`              | `descramble,missing_letter,typing,reaction,math` | Choose your flavor of suffering.         |

> 💡 Pro tip: If you disable all challenges, the mod will sit quietly in the corner and judge you.

---

## 📡 Matrix Integration

If you have `matrix_bridge`, challenges will be announced in your Matrix room too. Because your players deserve to be confused across multiple platforms.

---

## 🧙‍♂️ Commands

Use `/challenge` to manually start a challenge. Requires `server` privilege and a mild disregard for player sanity.

---

## 🐛 Bugs?

Probably. If you find one, just pretend it’s a feature.

---

## 🧼 Clean Code?

Define “clean.” This mod is held together by duct tape, Lua, and the sheer willpower of whoever wrote it.

---

Made with ❤️, sarcasm, and a questionable understanding of game design.
