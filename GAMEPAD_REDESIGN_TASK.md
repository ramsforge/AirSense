# Task: Virtual Gamepad Ergonomics & Visual Redesign (Vertical Stacking, Vertical Triggers & Vector Iconography)

You are tasked with redesigning the UI layout, control ergonomics, and visual presentation of **AirSense.Client** (Flutter) to resolve horizontal thumb crowding, replace awkward flat top triggers with vertical mobile-edge pedals, and fix deformed face button glyphs.

---

## 1. Ergonomic Reorganization: Vertical Control Stacking

### Problem
Currently, the D-Pad and Left Stick are placed horizontally side-by-side along the bottom edge, and the Right Stick and Face Buttons are horizontally side-by-side. This arrangement forces thumbs to pinch unnaturally toward the bottom bezel and leaves a large empty void in the upper halves of the screen.

### Implementation Requirements (`lib/screens/controller_screen.dart`)
Re-architect the left and right wings into two-tier vertical stacks matching authentic PlayStation DualSense geometry:

* **Left Wing (Vertical Stack):**
  * **Top Tier:** D-Pad (positioned in the upper-left thumb quadrant).
  * **Bottom Tier:** Left Analog Stick (`LS`) with the dedicated holdable `L3` button positioned above or integrated with the stick.
* **Right Wing (Vertical Stack):**
  * **Top Tier:** Action Face Buttons (positioned in the upper-right thumb quadrant).
  * **Bottom Tier:** Right Analog Stick (`RS`) with the dedicated holdable `R3` button.
* **Benefits:** Matches standard controller muscle memory, eliminates thumb collision, balances the screen layout, and follows the natural up-and-down pivot of human thumbs.

---

## 2. Vertical Edge Triggers & Bumpers (L1/L2, R1/R2)

### Problem
The current horizontal trigger bars (`L2: 0%` and `L1`) at the very top edge require awkward inward finger reaches when holding a smartphone in landscape.

### Implementation Requirements (`lib/screens/controller_screen.dart`)
Convert the shoulder controls into **vertical flank assemblies** positioned along the outer left and right borders of the screen:

* **`L2` / `R2` Triggers (Upper Flanks):**
  * Vertical pedal shape (approx. 42px wide × 76px tall).
  * Positioned on the upper-outer edges where index fingers naturally rest when gripping a phone.
  * Maintain instant digital tap (full pull = 255) with horizontal drag modulation after crossing a 12px deadzone.
* **`L1` / `R1` Bumpers (Below Triggers):**
  * Sleek vertical or rounded rectangular buttons (approx. 42px wide × 36px tall) located directly below the trigger pedals.
* **Visual Differentiation:** Distinct color accents, tactile borders, and active press scale animations.

---

## 3. De-condensed, Full-Sized 8-Way D-Pad

### Problem
In `lib/widgets/dpad.dart`, the D-Pad was previously constrained to ~122px to fit next to the stick, making it cramped and easy to miss directions.

### Implementation Requirements (`lib/widgets/dpad.dart`)
* With the stick moved to the lower tier, expand the D-Pad diameter to **150–160px**.
* Increase cross-arm length and width to give generous touch targets.
* Preserve the continuous 8-way radial angle math (`atan2`), ensuring seamless rolling transitions between directions and simultaneous diagonal chords (Up+Right, Down+Right, Down+Left, Up+Left).

---

## 4. Vector Iconography & Dynamic Mode Adaptation

### Problem
In `lib/widgets/action_buttons.dart`, face buttons currently render system Unicode text (`'△', '○', '✕', '□'`), resulting in thin lines, uneven margins, and font scaling artifacts. Furthermore, buttons display PlayStation symbols even when Xbox 360 mode is selected.

### Implementation Requirements (`lib/widgets/action_buttons.dart`)

### A. Vector Drawing
Replace text glyphs with clean vector rendering (using Flutter `CustomPainter` or clean inline vector paths):
* Uniform 2.5–3.0px stroke weight.
* Strict geometric centering inside the circular button.

### B. Dynamic Controller Mode Switching
Accept the current `ControllerMode` and dynamically adjust symbols and color themes:

#### 1. In PS5 DualSense Mode:
* **North (Top):** Triangle `△` — Color: `#00FF85` (Green)
* **East (Right):** Circle `○` — Color: `#FF3366` (Red)
* **South (Bottom):** Cross `✕` — Color: `#38BDF8` (Blue)
* **West (Left):** Square `□` — Color: `#FF66CC` (Pink)

#### 2. In Xbox 360 Mode:
* **North (Top):** `Y` — Color: `#FFC700` (Yellow)
* **East (Right):** `B` — Color: `#E81123` (Red)
* **South (Bottom):** `A` — Color: `#107C10` (Green)
* **West (Left):** `X` — Color: `#0078D7` (Blue)

---

## 5. Visual Wireframe Layout Reference

```
┌────────────────────────────────────────────────────────────────────────┐
│ [AirSense] [Mode Pill]      [LAN 120Hz • RTT ms • Bat %]       [Power] │
├────────────────────────────────────────────────────────────────────────┤
│ ┌────┐                                                          ┌────┐ │
│ │ L2 │       ┌──────────────┐   ┌─────────┐   ┌──────────────┐  │ R2 │ │
│ │TRIG│       │   D - P A D  │   │  SHARE  │   │ ACTION (△/Y) │  │TRIG│ │
│ ├────┤       │  (Expanded   │   ├─────────┤   │ (□/X)  (○/B) │  ├────┤ │
│ │ L1 │       │   155 px)    │   │TOUCHPAD │   │    (✕/A)     │  │ R1 │ │
│ │BUMP│       └──────────────┘   │ & MOUSE │   └──────────────┘  │BUMP│ │
│ └────┘       ┌──────────────┐   ├─────────┤   ┌──────────────┐  └────┘ │
│              │   L3 STICK   │   │ PS HOME │   │   R3 STICK   │         │
│              │  + Hold L3   │   └─────────┘   │  + Hold R3   │         │
│              └──────────────┘                 └──────────────┘         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Acceptance Criteria
1. **Vertical Stacking:** The D-Pad is vertically above the Left Stick; Action Buttons are vertically above the Right Stick.
2. **De-condensed D-Pad:** D-Pad operates at 150–160px diameter with responsive 8-way directional tracking.
3. **Vertical Flank Triggers:** `L1/L2` and `R1/R2` are vertically oriented along the outer borders for natural index-finger reach.
4. **Vector Iconography:** Action buttons use crisp vector geometry with zero system font misalignment.
5. **Mode-Aware Buttons:** Toggling to Xbox 360 mode updates the face buttons to authentic `Y, B, A, X` labels and colors; DualSense mode displays `△, ○, ✕, □`.
6. **No Dead Space:** The layout eliminates central dead space while preserving comfortable thumb travel distances.
