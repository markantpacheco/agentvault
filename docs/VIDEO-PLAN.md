# Demo Video Plan

**Target:** ~90 seconds
**Recorded:** terminal screen capture with voiceover, one cut to the explorer

**Check first:** the Buildathon submission page may specify a maximum length,
a required format, or a hosting requirement. Confirm before recording rather
than after.

---

## The one thing this video has to do

Make a viewer understand that **the holder has a switch the agent cannot
reach** — and that this is unusual.

Everything else is context for that moment. Most submissions in the AI-agent
category will be "an AI that trades." Yours is "the code that stops it." If a
judge remembers one thing, it should be beats 4 and 6 showing the identical
proposal with opposite verdicts.

So: get to that moment fast, then let it breathe.

---

## Shot list

| Time | On screen | What you say |
|---|---|---|
| 0:00–0:10 | Terminal, clean, prompt visible | Hook — the gap nobody's filling |
| 0:10–0:20 | Command typed, Enter pressed | What AgentVault is, one sentence |
| 0:20–0:32 | Header + beats 1–2 scrolling | Live on Robinhood Chain testnet |
| 0:32–0:45 | Beat 3, mandate limits | Who sets risk, and who doesn't |
| 0:45–0:58 | Beats 4 and 5 | Approved, then rejected by name |
| 0:58–1:18 | Beat 6 — **hold here** | The kill switch. Slow down. |
| 1:18–1:28 | Cut to Blockscout, verified contract | It's real and the source is public |
| 1:28–1:35 | Back to terminal, closing lines | Where the code is |

---

## Script

Write it, read it, don't improvise. Ninety seconds is less time than it
sounds and rambling is the most common failure in these.

> **[0:00]** Everyone's building AI agents that can trade. Almost nobody's
> building the part that stops them.
>
> **[0:10]** This is AgentVault. An NFT that owns an isolated account, and a
> deterministic risk engine the agent cannot override. The AI proposes. Code
> decides.
>
> **[0:20]** Everything you're about to see is running on Robinhood Chain
> testnet. Five contracts, all verified, no admin key anywhere in the system.
>
> **[0:32]** The NFT carries a permanent archetype — Guardian here. That's
> collectible identity, and it never sets a risk limit. The holder chooses
> the mandate separately. Preservation caps any single position at ten
> percent of the account.
>
> **[0:45]** A proposal inside every limit: approved.
>
> **[0:50]** A proposal twice the cap: rejected — and it says why.
> MaxPositionExceeded. Not a generic failure. The specific rule that stopped
> it.
>
> **[0:58]** Now the holder flips the kill switch. One transaction.
>
> **[1:05]** *(pause)* And this is the same proposal from beat four.
> Byte for byte. Five hundred units, twenty-five basis points.
>
> **[1:12]** Rejected. AutomationPaused.
>
> **[1:16]** Nothing about the trade changed. Only the holder's instruction
> did — and the agent has no path to that switch.
>
> **[1:22]** Contracts are verified on the explorer, the repo is public, a
> hundred and twenty-six tests pass from a clean clone.
>
> **[1:30]** AgentVault. The proving ground for onchain agents.

Roughly 190 words, which is about right for 90 seconds at an unhurried pace.

### The pause at 1:05

Actually stop talking. Two full seconds of silence with beat 6 on screen.

It's the only rhetorical device in the whole video and it's doing real work —
the viewer needs a beat to notice the numbers match before you tell them why
it matters. Talking through it wastes the moment.

---

## Technical setup

### Terminal

**Font size is the thing people get wrong.** Default terminal text is
illegible in a compressed video played in a browser window. Go to at least
18pt, ideally 20–24pt. Test by recording ten seconds and watching it at half
size.

- Clear scrollback first (`Cmd+K`) so nothing above the demo is visible
- Maximize the window, or close to it
- Light background reads better than dark in compressed video, but either
  works if the contrast is strong
- Nothing else on screen — no other windows, no notifications. Turn on Do
  Not Disturb.

### Recording

macOS has what you need built in:

- **QuickTime Player** → File → New Screen Recording. Free, already installed.
- Or `Cmd+Shift+5` for the built-in capture toolbar, which also lets you
  select a region.

Record the screen silently first, then add voiceover over the top in
**iMovie** (also free). Trying to narrate live while typing usually produces
both worse narration and worse typing.

### The password prompt

The script pauses for your keystore password, which is a dead few seconds of
nothing happening. Two options:

1. Record it and trim that section in iMovie — cleanest result
2. Leave it in as a two-second beat before the kill switch — honest, and
   arguably reinforces that a human authorised it

Either is fine. Don't let it become a reason not to record.

### Re-running

`LiveDemo` unpauses first if automation is already paused, so the arc repeats
cleanly. Take as many attempts as you need; it costs 0.00000044 ETH a time.

---

## The explorer cut

Ten seconds, around 1:18. Have the tab already open:

```
explorer.testnet.chain.robinhood.com/address/0x158A97c9b56043b5F3b841B3435D249326F43777
```

Show the **Contract** tab with verified source visible. That's the proof this
isn't a local simulation — readable code, on a public explorer, on the chain
the Buildathon is about.

If you want one more beat, the `setAutomationPaused` transaction from this run
is at:

```
0x4e1037f7647d2d27bc26beb511331efaa253d32faf7511be111315ae2731b890
```

A real transaction hash for the kill switch is a nice touch, but skip it if
time is tight — the verified source matters more.

---

## Optional: the test suite

If you end up under time, three seconds of `forge test` showing **126 passed,
0 failed** is a strong credibility signal for a solo submission.

Don't force it in. A rushed 95-second video is worse than a clean 85-second
one.

---

## What to avoid

**Don't explain the architecture.** No component diagrams, no "first the
proposal goes to the sizing engine." Judges who care will read the repo. The
video shows one thing working.

**Don't apologise for scope.** No "this is just a prototype," no "we haven't
built X yet." The README and docs are scrupulously honest about what's
unfinished — that's where it belongs. The video shows what works.

**Don't claim returns, performance, or safety.** Nothing about profit,
nothing implying the system can't lose money. This is the one place where a
throwaway line could contradict six weeks of careful positioning.

**Don't say "simply" or "just."** It reads as minimising your own work.

**Don't rush the last ten seconds.** People trail off at the end and the
closing line is what a judge carries into their notes.

---

## Checklist

- [ ] Submission requirements checked — length, format, hosting
- [ ] Terminal font ≥18pt, scrollback cleared, window maximised
- [ ] Do Not Disturb on, other windows closed
- [ ] Explorer tab pre-loaded on the RiskEngine contract page
- [ ] Script read aloud twice before recording
- [ ] Silent screen recording captured
- [ ] Beats 4 and 6 both clearly show **499**
- [ ] Voiceover added, with the two-second pause at 1:05 intact
- [ ] Watched back at half size to confirm text is legible
- [ ] Under the length limit
- [ ] No claim about returns, performance, or safety anywhere in it
