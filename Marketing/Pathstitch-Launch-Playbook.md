# Pathstitch — Launch Playbook

*Everything you need to take Pathstitch v1.0 from "it's done" to "people are using it." Strategy up top, then copy-paste posts you can fire off, then notes on which clip goes where.*

Download link to use everywhere: **https://github.com/Mason363/pathstitch/releases/latest**

---

## The one thing to remember

You didn't build "a minimalist CAD/CAM app using OpenCASCADE and a Python runner." You built **the tool that does the tedious part of leatherwork and pattern-making for you** — laying out saddle-stitch holes along an edge, drafting a pattern with real dimensions, and unfolding a 3D shape into flat panels you can actually cut and sew. The tech is how; the maker's saved afternoon is *why*. Lead with the why, every time.

> **Accuracy update (from Mason):** Pathstitch also **imports STL and OBJ** (not just STEP), and includes **raster→vector tracing** (trace a photo/logo into clean vectors, no Illustrator). Fold these into any post where they help.

Three sentences you can recombine forever:

- **The hook:** "I got tired of marking stitch holes by hand, so I built a free Mac app that lays them out along any edge automatically."
- **The wow:** "It can also take a 3D model and unfold it into flat panels you can cut and sew — the thing most pattern tools just can't do."
- **The trust:** "It's completely free and fully open-source. No account, no upsell, no catch — I made it because I wanted it to exist."

---

## The origin story (your canonical launch narrative)

*This is the most valuable single asset in this doc. It's in your voice, it's true, and it does what no feature list can: it makes a stranger care. Use it as the HN first comment, the spine of a launch blog post, the long-form caption for a YouTube/IG launch video, and lift its opening for the Reddit posts. Pair it with the demo clips — the story tells them why each tool exists, the clips show it working.*

> It started with a hole. A lot of holes, actually.
>
> I do leatherwork, and I just wanted an easy way to add evenly-spaced stitching holes to a `.dxf` file. But every tool I found was either locked behind a subscription, buried in a CAD program with a three-week learning curve, or just... didn't exist. So I built a little thing for myself. Give it an offset and a spacing, and it laid the stitch holes down the edge of my pattern. That was it.
>
> Then the friction crept in. I needed to round a corner — where's the free, no-nonsense fillet tool? I wanted to drop in a quick rectangle, trace a logo from a photo, or pull a flat face off a 3D model so I could cut it. Every single one of those was its own rabbit hole of clunky software, paywalls, or tutorials nobody should have to watch. None of them were free, intuitive, and quick all at once.
>
> So I stopped building a hole-puncher and started building the tool I actually wished existed — and made it for everyone, not just me. The rule was simple: it has to be free and open-source, it has to be intuitive enough to use without a manual, and it has to be fast — the kind of fast where you forget you're using software at all.
>
> And it grew.
>
> Today, Pathstitch opens just about anything you throw at it — DXF, SVG, STEP, STL, OBJ, PDF, even raster images — and gives you one clean, native Mac workspace to work in. You can:
>
> - Add saddle or single-row stitching holes with a live, draggable preview — the thing that started it all, now better than what I first dreamed of.
> - Sketch and edit 2D geometry — rectangles, circles, polygons, pen paths, text — with real fillets, chamfers, offsets, trims, and mirrors.
> - Pull a face right off a 3D STEP model, even curved non-planar ones, and unfold it into a flat, cuttable pattern.
> - Trace a raster image into clean vectors, no Illustrator required.
> - Organize with layers, measure and dimension precisely, then export to DXF, SVG, PDF, or high-res PNG — ready for your laser, your plotter, or your stitching pony.
>
> It's the tool I needed at every step of making real things, and because it's open and free, it's the tool that's there for you at your every step too. No subscription. No gatekeeping. No fighting the software instead of making the thing.
>
> **Pathstitch is for makers who'd rather be making.**

---

## Who you're actually talking to

Pathstitch sits at the intersection of three communities, and each one cares about a *different* feature. Don't send the same post to all of them — re-aim it.

| Audience | Their daily pain | Your lead feature | What NOT to lead with |
|---|---|---|---|
| **Leathercraft** (r/Leathercraft, Leatherworker.net) | Marking stitch holes by hand; spacing pricking-iron punches evenly around curves and corners | **Stitch-hole / saddle-stitch generation** + keep-out around hardware | 3D STEP import (most don't care) |
| **MYOG — Make Your Own Gear** (r/myog, BackpackingLight) | Drafting & scaling sewing patterns; adding seam allowance; laying out panels | **Parametric pattern drafting + offset for seam allowance + 3D→flat unfold** | "CAD kernel," saddle stitch |
| **Laser cutting** (r/lasercutting, Glowforge/forums) | Getting clean, cut-ready vectors; parametric boxes; score vs. cut layers | **Cut-ready DXF/SVG export, parametric fillets, perforated/dashed convert-lines, 3D box unfold** | Saddle stitch, sewing |
| **Mac / dev crowd** (HN, r/macapps) | Wanting native, fast, non-subscription tools | **Native SwiftUI, free, open-source, real geometry kernel** | This is the ONE place "OpenCASCADE + Python worker" actually helps you |

The pattern: **same app, four front doors.** Walk people in through the door they already use.

---

## Priorities & sequencing

You picked **r/Leathercraft + r/MYOG** as the focus, with **r/lasercutting** as the baseline you named first. Here's the order I'd ship in — it front-loads the communities most likely to *love* it and give you good first comments (social proof you'll reuse later).

**Week 1 — your home turf (highest fit, warmest crowd)**
1. **r/Leathercraft** — the saddle-stitch post. This is your strongest single fit.
2. **r/myog** — the pattern-drafting + unfold post, ~2–3 days later (don't post everywhere the same day; you want to be present in comments).

**Week 2 — adjacent makers**
3. **r/lasercutting** — the cut-ready / box-unfold post.
4. **Leatherworker.net** forum thread (the saddle-stitch crowd lives here too, older-school, very loyal).

**Week 3 — the broad-reach swing**
5. **Show HN** on Hacker News — this is the one that can send a real traffic spike. Save it for when your GitHub page is polished and you have a day free to answer comments.
6. **r/macapps** + **r/SwiftUI** the same week.

**Ongoing**
7. Short-form video (Instagram Reels / TikTok / YouTube Shorts) — drip one clip per week; this is evergreen and compounds.
8. **Hackaday tip line** (tips@hackaday.com) — a one-paragraph email; if they bite, it's a huge, durable backlink.

Why staggered: posting the same link to five places in one afternoon reads as spam and means you can't be in the comments anywhere. One channel at a time, fully present, is what turns a launch into users.

---

## The Reddit reality check (read before posting)

Maker subreddits are *allergic* to marketing, but they *love* a person who made a cool thing and gave it away. You are the second kind — make sure you read like it.

- **Check each sub's rules + post flair first.** Many have a "self-promo" flair or a weekly showcase thread, or require a ratio of community participation to self-posts. Use the right flair; if unsure, a one-line modmail ("I made a free open-source tool for the community, is a Show-and-Tell post okay?") buys enormous goodwill.
- **Be a person, not a press release.** First-person, lowercase-friendly, a little self-deprecating. Mention the *itch you scratched*. Show the leather/gear, not just the UI.
- **Free + open-source is your golden ticket** — say it early and plainly. It disarms the "is this an ad" reflex instantly.
- **Get ahead of the two objections:** (1) "Mac only?" — yes, Apple-Silicon Mac, be upfront. (2) "Why the scary security warning?" — because it's not notarized (that's a $99/yr Apple tax this free project hasn't paid), it's open-source and auditable, here's the 15-second one-time bypass.
- **Reply to every comment for the first 24h.** The algorithm and the humans both reward it. Your replies *are* the marketing.
- **Don't drop the link in the title.** Put the app name in the title, the link in the post body or first comment, and let the work earn the click.

---

## Pre-launch checklist (do these first)

A launch sends people to your GitHub page and your first launch — make both flawless before you post.

- [ ] **GitHub release notes** for v1.0.0 read like a human wrote them (short "what's new," a screenshot or GIF, the install steps).
- [ ] **README top is skimmable** — the hero screenshot + one-line pitch are the first thing a stranger sees. (Yours already is. ✅)
- [ ] **A 10–20s GIF in the README** (convert the Sewing Holes or 3D clip) — autoplays inline, dramatically lifts engagement vs. a static image.
- [ ] **Issues templates work** and Discussions is enabled (✅ per README) so feedback has a home.
- [ ] **Pin a "v1.0 is out" Discussion** so first-time visitors land somewhere welcoming.
- [ ] **Decide your link strategy:** always the `/releases/latest` URL so it never goes stale.
- [ ] Have the **demo clips uploaded somewhere linkable** (the GitHub release, a YouTube unlisted/public upload, or imgur) so you can drop them in comments.

---

# Paste-ready posts

> Swap anything that doesn't sound like you — these are drafts in *your* voice, not handcuffs. Reddit accepts Markdown, so formatting carries over on paste.

---

## 1) r/Leathercraft  ⭐ your strongest fit

**Suggested flair:** Show & Tell / Tools (whatever the sub uses for "I made something")

**Title options (pick one):**
- `I got tired of marking saddle-stitch holes by hand, so I spent a year building a free app that does it for you`
- `Made a free, open-source Mac app for leather patterns + automatic saddle-stitch hole layout — finally hit v1.0`
- `After too many uneven stitch lines, I built a (free) tool to lay out the holes for me`

**Body:**

```
Like a lot of you, the part of a build I dreaded was marking out stitch holes — getting even spacing down a strap, keeping the pitch consistent around a curve, and not having the last hole land in a weird spot at the corner. Pricking irons help, but laying it all out beforehand was always fiddly.

So I built a thing. It's called Pathstitch — a free, open-source Mac app for drawing leather patterns and generating the stitch holes automatically.

What it does for leatherwork specifically:
- Draw your pattern with real dimensions (type a width, tab, type a length — no guessing in pixels).
- Round corners parametrically and keep them editable — drag a corner radius and the whole pattern updates.
- Drop saddle-stitch holes along any edge with spacing + corner controls, and tell it to "keep out" around hardware (snaps, rivets, D-rings) so the stitch line gaps cleanly around them.
- Export cut-ready DXF / SVG / PDF — print a 1:1 template, send it to a laser, or trace it onto leather.

It can also do pattern-making stuff like offsets (great for adding an edge margin), mirroring, and even unfolding a 3D model into flat panels if you ever want to design a box or a curved piece and flatten it for cutting.

It's 100% free and fully open-source — no account, no trial, no upsell. I made it because I wanted it to exist. The only catch: it's Mac-only right now (Apple-Silicon, macOS 14+), and because I haven't paid Apple's $99/yr notarization fee, the first launch needs a one-time "Open Anyway" click — instructions are in the README.

Download + screenshots: https://github.com/Mason363/pathstitch/releases/latest

I'd genuinely love feedback from people who stitch more than I do — what would make the hole-spacing tools actually match how you work? Happy to answer anything.
```

**Media:** Lead with **`3 - Sewing Holes.mp4`** (this is the money clip for this sub). If the sub allows one media item, that's it. If you can do a gallery, add the README stitch-holes screenshot.

---

## 2) r/myog (Make Your Own Gear)

**Title options:**
- `I built a free, open-source pattern-drafting app for Mac — parametric panels, seam-allowance offsets, and 3D→flat unfolding`
- `Made a free tool for drafting MYOG patterns (and unfolding 3D shapes into flat panels) — v1.0 is out`

**Body:**

```
MYOG drafting has always meant a stack of tools for me — something to draw in, something to add seam allowance, something to scale, and a lot of measuring twice. I wanted one fast app that just did the geometry, so I built one and finally got it to a stable 1.0.

It's called Pathstitch (free, open-source, Mac). For pattern work:

- Draw panels with live dimensions and snapping — exact widths/lengths as you go, not eyeballing.
- Offset any edge to add a seam allowance (with a live preview, and you can flip which side).
- Parametric fillets so you can round a corner and tweak the radius forever without redrawing.
- Mirror / duplicate / array panels, and organize them on layers.
- Export to DXF / SVG / PDF — tile-print a 1:1 pattern or send straight to a cutter.

The party trick: import a 3D model (.step) and unfold its surfaces into flat nets — handy if you model a pack body or a curved piece in CAD and want it flattened into sewable panels. It handles developable surfaces and does a conformal flatten (LSCM) for gently doubly-curved faces.

Totally free, no account, no catch — it's open-source because I'd rather it outlive me than make a buck. Caveat: Apple-Silicon Mac, macOS 14+, and a one-time Gatekeeper bypass on first launch (it's not notarized — open-source instead of paying Apple's $99/yr; steps in the README).

https://github.com/Mason363/pathstitch/releases/latest

Would love to hear what gear you'd draft with it, and what's missing for real MYOG workflows (notches? grainline marks? seam-allowance presets?). Feedback shapes where this goes next.
```

**Media:** Lead with **`4 - 3D.mp4`** (the unfold is the jaw-dropper for this crowd) *or* **`1 - Shapes & snapping.mp4`** if you'd rather emphasize everyday drafting. Ideal: a short clip + the export screenshot.

---

## 3) r/lasercutting (your named baseline)

**Title options:**
- `Built a free, open-source Mac CAD app with cut-ready DXF/SVG export, parametric fillets, and 3D→flat box unfolding`
- `Free native Mac app for designing cut files — parametric, real geometry kernel, exports clean DXF/SVG (v1.0)`

**Body:**

```
I wanted a fast, native Mac app for drawing cut files — parametric, precise, and exporting clean vectors without a subscription or a browser tab. Couldn't find quite the right one, so I built it. It just hit a stable v1.0 and it's free + open-source.

It's called Pathstitch. For laser folks:

- Draw with snapping + live dimensions, plus an Illustrator-style pen tool.
- Parametric fillet / chamfer on every corner — draggable, stays editable, great for clean radii on enclosures.
- Trim (hover to preview exactly what gets cut), boolean union/subtract/intersect, offset for kerf/margins.
- "Convert Lines" to dashed / perforated / decorative styles — handy when you want a score or perf path distinct from your cut path.
- Fill / hatch closed regions, and pattern parts in grids / circles / along a path.
- Export DXF, SVG, PDF, PNG. It's backed by a real geometry kernel (shapely / OpenCASCADE via ezdxf), not an SVG-pusher, so curves stay curves.

The fun one: import a 3D .step model and unfold it into flat panels + add fold creases and glue tabs — i.e. design a box or enclosure in 3D and flatten it into a cut-ready net. There's also Finder QuickLook for DXF/STEP so you can spacebar-preview real geometry instead of a generic icon.

Free, open-source, no account. Caveats up front: Apple-Silicon Mac + macOS 14+, and a one-time "Open Anyway" on first launch because it's not notarized (open-source instead of paying Apple's $99/yr — fully auditable; steps in the README).

https://github.com/Mason363/pathstitch/releases/latest

Curious what would make it fit your workflow — kerf-offset presets? Living-hinge generators? Material/test-cut templates? Tell me what you'd actually use.
```

**Media:** Lead with **`5 - Export.mp4`** (cut-ready files) or **`2 - Fillet.mp4`** (parametric precision). The **`4 - 3D.mp4`** unfold clip also kills here as a gallery second.

---

## 4) Show HN (Hacker News)

This is the one place where the engineering *is* the pitch. Be plain and technical; HN smells marketing instantly. Title format is strict.

**Title:**
`Show HN: Pathstitch – a native macOS CAD/CAM app for leather, patterns and sewing`

**First comment (post immediately after submitting — this is where you tell the story).** Use your own origin story (above) — it's better than anything generic. Paste it, then add the short technical paragraph below so the HN crowd gets the architecture they'll inevitably ask for:

```
[Paste your origin story here — "It started with a hole..." through "...makers who'd rather be making."]

A bit of architecture, since this crowd will ask: it's a thin SwiftUI front-end over a long-lived Python geometry worker — every operation is framed JSON over stdin/stdout, so the UI never blocks on geometry. 2D is ezdxf + shapely; STEP/3D is pythonOCC (OpenCASCADE); raster/PDF export is matplotlib; the STEP unfold handles developable surfaces and does a conformal flatten (LSCM) for gently doubly-curved faces. A trimmed copy of the Python env is bundled into the .app, so there are no external deps for end users. It also ships QuickLook + Thumbnail extensions (the STEP one tessellates the B-rep via a small Rust lib).

It's GPLv3 and free. Apple-Silicon, macOS 14+. Ad-hoc signed but not notarized yet (no paid Apple Developer ID), so first launch needs a one-time Gatekeeper bypass. Happy to go deep on the unfolding math or the Swift↔Python bridge.
```

**Timing:** weekday morning US Eastern (roughly 8–10am ET) tends to do best. Be at your desk for the next 4–6 hours to answer.

**Media:** HN is text-first, but the README's hero screenshot and the 3D/Sewing GIFs are what people click through to. Make sure the README is GIF-rich before you post.

---

## 5) r/macapps  (and cross-post to r/SwiftUI)

**Title:**
`Pathstitch — a free, open-source native CAD/CAM app for leather, patterns & laser cutting (Apple Silicon)`

**Body:**

```
Sharing a free, open-source Mac app I just shipped to v1.0: Pathstitch, a native SwiftUI CAD/CAM studio for makers — leatherwork, sewing patterns, and laser cutting.

Why it might interest this sub:
- Properly native — SwiftUI, fast, not an Electron/web wrapper. Light/dark themes, ⌘K command palette, customizable keybinds, rearrangeable toolbar.
- Real geometry under the hood (OpenCASCADE / shapely), so it does grown-up CAD things: parametric fillets, booleans, trim, offsets, and even unfolding 3D STEP models into flat panels.
- Finder QuickLook + thumbnails for DXF and STEP files — spacebar-preview real geometry.
- Exports DXF / SVG / PDF / PNG; native .stch project files; auto-updates via Sparkle.
- Free and GPLv3. No account, no subscription.

Apple-Silicon + macOS 14+. Not notarized (it's open-source rather than paying the $99/yr Apple tax), so there's a one-time first-launch bypass.

https://github.com/Mason363/pathstitch/releases/latest
```

**Media:** **`1 - Shapes & snapping.mp4`** or the hero screenshot — this crowd appreciates a clean native UI on display.

---

## 6) Short-form video captions (Reels / TikTok / Shorts / YouTube)

Post one clip a week. Same caption skeleton, different clip. Keep the first line a hook, not a description.

**Sewing Holes clip:**
```
Marking saddle-stitch holes by hand is over. 🧵
Free Mac app I built — draw your pattern, drop the stitch line, done.
Pathstitch (free + open-source, link in bio)
#leathercraft #leatherwork #saddlestitch #maker #macapp
```

**3D unfold clip:**
```
Watch a 3D model unfold into flat panels you can actually cut and sew. ✂️
This is the part most pattern tools just can't do.
Pathstitch — free + open-source for Mac.
#myog #patternmaking #cad #lasercutting #maker
```

**Fillet / editing clip:**
```
Every corner stays editable, forever. Drag the radius, the pattern updates.
Free parametric CAD for makers — Pathstitch.
#cad #design #lasercutting #maker #macapp
```

**YouTube:** a single 2–4 min "Pathstitch v1.0 — what it does" walkthrough stitched from clips 1→5 becomes your evergreen anchor; link it everywhere.

---

## 7) Hackaday tip-line email (tips@hackaday.com)

```
Subject: Free open-source Mac CAD app that unfolds 3D models into cut-and-sew patterns

Hi Hackaday team,

I just released Pathstitch v1.0 — a free, open-source (GPLv3) native macOS CAD/CAM app for makers. The headline feature: it imports STEP models and unfolds their surfaces into flat panels you can cut and sew, alongside automatic saddle-stitch hole generation for leatherwork and clean DXF/SVG export for laser cutting.

Architecture might interest your readers: a SwiftUI front-end over a long-lived Python geometry worker (OpenCASCADE / shapely), with a Rust-backed QuickLook previewer for STEP files.

Repo + demo videos: https://github.com/Mason363/pathstitch

Happy to provide more media or details. Thanks for considering it!
Mason Chen
```

---

## Reusable snippets (grab-bag)

**One-liner (bio / tagline):**
> Pathstitch — free, open-source Mac CAD/CAM for leather, patterns & laser cutting. Draw it, stitch it, unfold it, cut it.

**Elevator pitch (2 sentences):**
> Pathstitch is a free, native Mac app for makers: draw precise patterns, auto-generate saddle-stitch holes, and even unfold 3D models into flat panels you can cut and sew. It's open-source, backed by a real geometry kernel, and built by one person who got tired of doing this by hand.

**Canned reply — "Mac only? 😢"**
> Yep, Apple-Silicon Mac + macOS 14 for now — it's a native SwiftUI app, so a Windows/Linux port isn't a quick recompile. Intel Mac support is feasible by repackaging the backend. If there's enough interest I'll seriously look at it — upvote/comment so I can gauge demand.

**Canned reply — "Why the security warning / is it safe?"**
> Totally safe, and I get why it looks scary. The app is ad-hoc signed but not Apple-*notarized* — notarization needs a paid $99/yr Apple Developer ID this free project doesn't have yet. It's fully open-source, so the entire codebase is public and auditable. First launch needs a one-time "Open Anyway" in System Settings ▸ Privacy & Security (15 seconds, two clicks); after that it opens normally forever. Steps are in the README.

**Canned reply — "Is it really free? What's the catch?"**
> Genuinely free, GPLv3, no account or trial. No catch. If it saves you time there's an optional "buy me a coffee" link, but nothing's gated. I built it because I wanted it to exist.

**Canned reply — "Feature request: X"**
> Love this — drop it as a feature request on GitHub (link in the README) so it doesn't get lost? Tell me what you're trying to *do* and I'll figure out the how. Stuff like this is exactly what shapes the roadmap.

---

## Media map — which clip goes where

You have five demo clips in `Other Pathstitch Files/Demo/` (with smaller, compressed versions of 3/4/5 in `Demo/compressed/` — use those for upload size limits), plus the screenshots already hosted in your README.

| Clip | Best for | Why |
|---|---|---|
| `1 - Shapes & snapping.mp4` | r/macapps, HN, general intro | Shows the precise, native drawing feel — broad appeal |
| `2 - Fillet.mp4` | r/lasercutting, HN | Parametric editing reads as "real CAD" |
| `3 - Sewing Holes.mp4` ⭐ | **r/Leathercraft**, leather IG/TikTok | THE money clip for the stitch crowd |
| `4 - 3D.mp4` ⭐ | **r/myog**, r/lasercutting, HN, Hackaday | The "wow, it unfolds" moment — most shareable single clip |
| `Demo5 / Video 5 - Export.mp4` | r/lasercutting | Proves cut-ready files actually come out |

**Practical tips:**
- Reddit caps video uploads (and quality drops). For best results, upload the **compressed** versions, or post a still + link a YouTube clip in the first comment.
- Turn `3 - Sewing Holes` and `4 - 3D` into short **GIFs/looping MP4s** for the README and for Twitter/X — autoplay beats a click-to-play thumbnail.
- For each platform's native algorithm (TikTok/Reels/Shorts), **upload the file directly** rather than linking out — they throttle posts with external links.

---

## A realistic picture of what "success" looks like

A solo, free, Mac-only niche tool won't go viral on day one, and that's fine — that's not the game. The game is **seeding the right communities** so the people who'll actually use it find it, leave a comment, file a bug, and tell one friend. Ten engaged leatherworkers who star the repo and report issues are worth more than 10,000 idle upvotes. Post where the fit is tight (you're starting there), be genuinely present in the comments, and let it compound. The 3D-unfold clip is your one shot at a broader spike — spend it when your GitHub page is ready to receive the traffic.

Go get 'em. 🧵
