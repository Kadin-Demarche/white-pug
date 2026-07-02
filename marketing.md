# Keel — Go-to-Market Kit

Positioning, channels, and ready-to-post copy. Everything here is **drafted, not sent** —
which is the whole point of Keel: nothing outward-facing ships without a human tap.

---

## Positioning

- **One-liner:** AI that runs your company — and proves the work actually shipped.
- **Category:** Trustworthy autonomous agents / AI company operator.
- **Wedge:** "Point Keel at *your* repo. It only says 'done' when the preview deploys and
  the test passes — with the URL to prove it."
- **Enemy (the narrative hook):** the last generation of "autonomous AI" that marked tasks
  done that never shipped, emailed customers the wrong price, and burned your credits on
  failures. Keel is the correction.
- **Proof pillars:** independent Verify · blast-radius Gates · honest billing · glass-box ·
  own-your-stack.

### Who to sell to first (ICP)
Technical solo founders and indie hackers already shipping with AI who got burned by
"it said done but nothing deployed." They feel the pain acutely and can evaluate the
verify loop in one night on a repo they already have.

---

## Channel plan (first 30 days)

| Channel | Play | Why |
|---|---|---|
| **X / Twitter** | Founder launch thread + a "watch it self-reject a broken deploy" demo clip | The Polsia critique lives here; ride the exact audience that watched it fail |
| **Show HN** | "Show HN: Keel — agents that must prove the deploy works before saying done" | HN rewards the anti-hype, verification-first angle |
| **Product Hunt** | Launch with the honest terminal report as the hero gif | PH loves a crisp before/after |
| **Indie Hackers / r/SaaS** | Build-in-public post on the verify loop architecture | Credibility with the ICP |
| **Cold email** | To founders who publicly complained about autonomous-AI failures | Warm, specific, timely |
| **SEO** | "AI that actually deploys," "[competitor] alternative that verifies work" | Capture disillusioned searchers |

Launch sequence: build-in-public teaser → HN + PH same morning → founder thread → follow the
comments live (gated replies, not spam).

---

## Ready-to-post copy

### 1) X / Twitter — launch thread

**1/**
Every "autonomous AI company builder" has the same dirty secret:

it marks tasks "done" that never actually shipped.

One audit found 41 of 47 tasks "done" — ~21% actually worked.

We built Keel so "done" can't be a lie. 🧵

**2/**
The problem was never the agents. It's that they grade their own homework.

The agent that writes the code also decides if it worked. Of course it says yes.

Keel splits those apart.

**3/**
The loop: Plan → Act → **Verify** → Gate → Report.

A *separate* harness proves the work against reality:
• code builds, tests pass, deploys to a preview URL, passes a live smoke test
• "done" ships with the URL as evidence — or it isn't done

**4/**
And nothing irreversible reaches the world un-gated.

🟢 reversible → auto
🟡 external + capped → auto with an undo window
🔴 mass outreach / prod / money → one-tap human approval

Autonomy is a dial, not a switch. Agents *earn* more of it.

**5/**
The part founders actually feel:

failed work is auto-rolled-back and **never billed.**

The verifier — not the agent — writes your bill. No more paying for credits burned on tasks that never worked.

**6/**
It runs on *your* stack. BYO GitHub, email, Stripe, ad accounts over OAuth.
One-click eject with everything you built. No walled garden.

**7/**
Point Keel at one repo tonight. Wake up to a PR that actually deploys — with the URL to prove it.

Free to start, no card 👉 [link]

---

### 2) Show HN

**Title:** Show HN: Keel – AI agents that must prove the deploy works before saying "done"

**Body:**
Hi HN. I got tired of "autonomous AI company" tools that mark work complete when nothing
actually shipped — PRs that don't build, outreach sent with the wrong price, credits burned
on failures.

Keel is my take on fixing the two steps those tools skip: **verification** and **accountability.**

The core loop is Plan → Act → Verify → Gate → Report:
- A *separate* harness from the one that did the work verifies it against reality — for code
  that means it must build, pass tests, deploy to a preview URL, and pass a Playwright smoke
  test before it's called shipped. "Done" carries evidence or it isn't done.
- Actions are gated by blast radius: reversible work auto-ships, capped external work gets an
  undo window, irreversible/money actions need a one-tap human approval. Agents earn
  auto-approval per capability over time.
- The verifier writes the bill, so failed tasks are never charged.
- It runs on your own GitHub/email/Stripe over OAuth and you can eject anytime.

I'd genuinely love feedback on the verification design — especially where a smoke test is a
weak proxy for "it works," and how you'd harden the independent-verifier boundary.

[link]

---

### 3) Product Hunt

**Tagline:** AI that runs your company — and proves the work actually shipped.

**First comment:**
Hey PH 👋 Keel is what "autonomous AI" should have been: agents that *prove* their work
instead of grading their own homework. Every task runs Plan → Act → **Verify** → Gate →
Report — code has to build, deploy to a preview URL, and pass a smoke test before it's
"done," and anything irreversible waits for your one-tap approval. Failed work is never
billed. It runs on your own accounts and you can eject anytime. Point it at a repo tonight
and wake up to a PR that actually deploys 🚀

---

### 4) LinkedIn — founder post

The most expensive lie in AI right now is one word: **"done."**

A wave of "autonomous company" tools shipped agents that mark work complete when nothing
actually deployed. Founders paid for it — in burned credits, wrong-price emails to real
customers, and ad budgets spent on failures.

The fix isn't smarter agents. It's not letting an agent grade its own homework.

We built Keel around an independent verifier: a separate check proves every result against
reality before it's called done — and before anything irreversible reaches a customer. You
only pay for work that verifiably shipped.

Autonomy people can actually trust. Point it at a repo and see.

[link]

---

### 5) Cold email (to a founder who was burned by autonomous AI)

**Subject:** the "done" that never deployed

Hi {First},

Saw your note about {tool} marking tasks done that never shipped — that exact failure is why
we built Keel.

Same idea (agents that run your company on your own stack), but nothing is "done" until a
*separate* verifier proves it: the PR has to build, deploy to a preview URL, and pass a smoke
test — you get the URL as proof. Anything irreversible waits for your one tap, and failed
tasks are never billed.

Worth pointing it at one of your repos for a night? Free, no card, eject anytime.

— {Name}

---

### 6) One-liners / ad variants (A/B pool)

- "Your agents shouldn't grade their own homework."
- "It's not done until it deploys. We prove it."
- "Autonomy is a dial, not a switch."
- "Stop paying for 'done.' Start paying for done right."
- "The AI co-founder that can't lie to you."
- "Point it at your repo. Wake up to a PR that actually works."

---

## What I did NOT do

I have **not** published any of this anywhere or contacted anyone — that's an outward-facing
action that needs your accounts and your go-ahead. Fittingly, this is exactly the 🔴 gate Keel
itself would hold for a human tap. Tell me where you actually want to launch and I'll tailor
and (with your approval) help you ship it.
