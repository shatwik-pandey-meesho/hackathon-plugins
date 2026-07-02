# The No-Jargon Guide to Building and Shipping Your Hackathon App

Welcome! You do **not** need to know how to code to use these skills. Think of each skill as a
helper you can talk to in plain English. You say what you want ("add a page where people can sign
up"), and the helper does the technical part for you.

There are only **7 skills you really need**. Six of them help you **build** your app. The seventh,
`hackathon-deploy`, puts it **online** for the judges. Learn these seven and you can go from an
empty laptop to a live app.

> **How to use a skill:** just type what you want in plain language. The right helper picks itself.
> The skill names below (like `hackathon-bootstrap`) are only there so you know which helper is
> doing the work — you never have to memorize them.

---

## The 7 skills at a glance

**Building (you'll use these over and over):**

| # | Helper | In one line |
|---|--------|-------------|
| 1 | 🧰 `hackathon-bootstrap` | Sets up your laptop and makes an empty starter app. |
| 2 | 👀 `hackathon-preview` | Shows your app in the browser with a link. |
| 3 | ✨ `hackathon-feature-builder` | Adds pages, buttons, and features you describe. |
| 4 | 💾 `hackathon-db-helper` | Makes your app *remember* things (saved data). |
| 5 | 🩹 `hackathon-bugfix` | Fixes anything that looks broken. |
| 6 | 🗣️ `hackathon-explainer` | Explains what's happening, in plain words. |

**Deploying (you'll use this once, at the end):**

| # | Helper | In one line |
|---|--------|-------------|
| 7 | 🚀 `hackathon-deploy` | Packages, checks, uploads, and puts your app online. |

---

## Part 1 — The building skills

This is where your idea becomes a real, clickable app running on your computer. We'll use one
running example throughout: a small app called **Recipe Box**, where people can post recipes and
rate them.

### 1. 🧰 Getting set up — `hackathon-bootstrap`

**What it does:** Prepares your laptop and creates a fresh, empty starter app — like setting up an
empty kitchen with all the pots and pans before you start cooking.

**Say this:** *"I'm starting from scratch. Set up my laptop and make me a starter app called Recipe
Box."*

**What you get:** It installs the tools it needs and hands you a plain but working app you can build
on. This is always the very first step, on day one.

### 2. 👀 Looking at your app — `hackathon-preview`

**What it does:** Starts your app and gives you a web link so you can open it in your browser and
click around, just like a real website.

**Say this:** *"Show me my app."*

**What you get:** A link like `http://localhost:9080`. You open it and there's your Recipe Box, live
on your screen. Use this often — it's your "take a look" button after every change.

### 3. ✨ Adding features — `hackathon-feature-builder`

**What it does:** Adds new things to your app when you describe them — pages, buttons, forms, lists,
sign-in screens, and so on.

**Say this:** *"Add a page where people can post a recipe with a title, a photo, and a star rating."*

**What you get:** A new page that does exactly that. No code talk required. This is the helper you'll
use the most, because it's how your app actually grows.

### 4. 💾 Saving and changing data — `hackathon-db-helper`

**What it does:** Handles the part of your app that *remembers* things — the recipes people add,
their ratings, sign-up details. If your app needs to keep information, this is the helper.

**Say this:** *"Make sure recipes are still there after I close and reopen the app, and add a field
for cooking time."*

**What you get:** Your Recipe Box now remembers every recipe and tracks cooking time, even after a
restart.

### 5. 🩹 Fixing things that break — `hackathon-bugfix`

**What it does:** Figures out why something isn't working and fixes it. Your "help, it broke!"
helper.

**Say this:** *"The page is completely blank"* or *"I click Save and nothing happens."*

**What you get:** It investigates, fixes the problem, and explains what went wrong in plain words.
Use it the moment anything looks broken or stuck — no need to panic, just describe what you see.

### 6. 🗣️ Understanding what's going on — `hackathon-explainer`

**What it does:** Explains anything — an error message, what just changed, what a technical word
means — in everyday language, like a patient friend.

**Say this:** *"What did that last change actually do?"* or *"What does this red message mean?"*

**What you get:** A calm, simple explanation with no jargon. It's also great for preparing what
you'll say to the judges.

---

## Part 2 — The deploy skill (described in full)

### 7. 🚀 Putting your app online — `hackathon-deploy`

"Deploying" just means: take the finished app off your laptop and put it online so anyone —
especially the judges — can open it with a link. Think of it like mailing a finished cake to the
judging table instead of making them come to your kitchen.

`hackathon-deploy` is the **one skill that does the entire finish line for you**. You don't have to
run several separate steps — it handles all of them in order.

#### Before you start: your deploy token

The **support team will give you a token**. A token is like a one-time password that proves your app
is allowed to go online.

- You get the token **from the support team** — ask them if you don't have it yet.
- Keep it private, like a password. The helper is careful never to show it on screen.
- You'll also be asked for your **Meesho email** — that's only used to label your app so it doesn't
  get mixed up with another team's.

#### What happens when you say *"Deploy my app"*

The helper walks you through these steps and stops to ask only when it needs something from you:

1. **Switch to the best setting.** It first asks you to switch to the strongest AI mode (it tells
   you exactly which buttons to press). Deploying is the most important step, so you want the best
   help.
2. **Package the app.** It bundles your whole app into one neat, shippable box.
3. **Double-check it works.** It runs your app one more time on its own to make sure it starts
   cleanly and nothing private (like a password) was left inside.
4. **Save a copy of your code.** It makes one tidy file of your code for you to hand in.
5. **Ask for two things:** your **Meesho email**, and the **token from the support team**. Paste the
   token when asked.
6. **Upload everything** using your token.
7. **Send you to go live.** It tells you to open **https://buildathon.ltl.sh**, log in, click the
   **Deploy Live** button, and **wait for your live link to appear**.

#### The final click

After the upload finishes:

1. Open **https://buildathon.ltl.sh** and log in.
2. Click the **Deploy Live** button.
3. **Wait** — in a moment, a live link appears. That link is your app, online.
4. Open the link to check it looks right, then share it with the judges. 🎉

If the live link doesn't show up after a couple of minutes, make sure you're logged in and that the
upload said it succeeded, then click **Deploy Live** again.

> **Works on any laptop** — Mac or Windows. And this one skill replaces doing the packaging,
> checking, code-saving, and uploading separately. Most teams only ever need `hackathon-deploy`.

---

## A full example: building and shipping "Recipe Box"

Here's a complete day, start to finish, using only plain English. This is exactly what you'd type.

**Morning — get set up and see something on screen**

1. *"Set up my laptop and make a starter app called Recipe Box."* → 🧰 `hackathon-bootstrap`
2. *"Show me my app."* → 👀 `hackathon-preview` — you open the link and see a plain page. It's alive!

**Midday — build the real features**

3. *"Add a home page that lists all recipes with their name and star rating."* → ✨ `feature-builder`
4. *"Add a form where someone can add a new recipe with a title, ingredients, and a rating from 1 to
   5."* → ✨ `feature-builder`
5. *"Make sure recipes people add are saved and still there after I restart the app."* → 💾
   `db-helper`
6. *"Show me my app."* → 👀 `preview` — you add a recipe, refresh, and it's still there. 

**Afternoon — something breaks, then you understand it**

7. *"When I click Add Recipe, nothing happens."* → 🩹 `bugfix` — it finds the problem and fixes it.
8. *"Explain what was wrong, in simple terms, so I can mention it to the judges."* → 🗣️ `explainer`
9. *"Show me my app."* → 👀 `preview` — adding a recipe works now. Your app is done!

**End of day — put it online for judging**

10. Get your **token from the support team**. 🎫
11. *"Deploy my app."* → 🚀 `hackathon-deploy`
    - It switches to the best mode, packages and tests Recipe Box, and saves your code.
    - It asks for your **Meesho email** and your **token** — you paste them in.
    - It uploads everything.
12. Open **https://buildathon.ltl.sh**, log in, click **Deploy Live**, and **wait for the live
    link**.
13. Open the live link — there's Recipe Box, online for the whole world. Share it with the judges. 🎉

---

## The short version

**Building (repeat as needed):**

1. *"Set me up and make a starter app."* → 🧰
2. *"Show me my app."* → 👀
3. *"Add a page that does ___."* → ✨
4. *"Remember ___ in the app."* → 💾
5. *"This looks broken: ___"* → 🩹
6. *"Explain what just happened."* → 🗣️

**Deploying (once, at the end):**

1. Get your **token from the support team**. 🎫
2. Say *"Deploy my app."* → 🚀
3. Give your **Meesho email** and paste the **token** when asked.
4. Open **https://buildathon.ltl.sh**, log in, click **Deploy Live**.
5. **Wait for the live link** — then share it with the judges. 🎉

You've got this. Describe what you want in plain words, and let the helpers handle the technical
parts.
