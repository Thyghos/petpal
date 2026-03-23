# Visual Guide: New Home Screen

## 🏠 Home Screen Layout

```
┌──────────────────────────────────────────┐
│  Good Morning                    [My Pets]│
│  PawPal                                    │
│  (gradient orange→blue)                    │
├──────────────────────────────────────────┤
│                                            │
│  ┌────────────────────────────────────┐  │
│  │  [Pet Photo]    Max                │  │
│  │    Circle       Active Profile      >  │
│  │   85x85pt       Golden Retriever • Dog│  │
│  │  [Camera]       50 lbs             │  │
│  └────────────────────────────────────┘  │
│                                            │
├──────────────────────────────────────────┤
│  Features                                  │
│                                            │
│  ┌──────────┐    ┌──────────┐            │
│  │ [🧠]     │    │ [✈️]     │            │
│  │ Green    │    │ Orange   │            │
│  │          │    │          │            │
│  │ Vet AI   │    │ Travel   │            │
│  └──────────┘    └──────────┘            │
│                                            │
│  ┌──────────┐    ┌──────────┐            │
│  │ [📄]     │    │ [🔔] (2) │            │
│  │ Blue     │    │ Purple   │            │
│  │          │    │          │            │
│  │Documents │    │Reminders │            │
│  └──────────┘    └──────────┘            │
│                                            │
│  ... (more feature cards)                 │
│                                            │
│  Your pet's health, always at your        │
│  fingertips.                               │
│  Made with ❤️ for pet parents             │
└──────────────────────────────────────────┘
```

## 📸 Pet Card Detail

```
┌────────────────────────────────────────┐
│                                         │
│   ╭─────────╮                          │
│   │         │    Max                    │
│   │  🐕/📷  │    ● Active Profile       │
│   │  Photo  │    Golden Retriever • Dog│
│   ╰─────────╯    ⚖️ 50 lbs        ›    │
│    [Camera                              │
│     Badge]                              │
│                                         │
└────────────────────────────────────────┘

States:
• With Photo: Shows your pet's picture
• No Photo: Shows dog.fill or cat.fill icon
• Gradient border around circle
• Camera badge bottom-right
• Tap anywhere to edit
```

## 🎨 Feature Card Detail

```
┌────────────────┐
│                │
│  ╭──────────╮  │  ← Gradient square
│  │  Icon    │  │     with shadow
│  │  White   │  │
│  ╰──────────╯  │
│       (2)      │  ← Optional badge
│                │
│  Feature       │  ← Bold title
│  Name          │     (max 2 lines)
│                │
└────────────────┘

Gradient Colors:
• Vet AI: 🟢 Green
• Travel: 🟠 Orange  
• Documents: 🔵 Blue
• Reminders: 🟣 Purple
• Emergency: 🔴 Red
• Health: 🌸 Pink
```

## 📱 Edit Pet Sheet

```
┌──────────────────────────────────────┐
│  Cancel    Edit Pet Profile    Save  │
├──────────────────────────────────────┤
│                                       │
│          ╭───────────────╮           │
│          │               │           │
│          │   Pet Photo   │           │
│          │   or Icon     │           │
│          │               │           │
│          ╰───────────────╯           │
│         [📷 Add Photo]                │
│         [Remove Photo]                │
│                                       │
│  Pet's Name                           │
│  ┌─────────────────────────────────┐ │
│  │ Enter name                      │ │
│  └─────────────────────────────────┘ │
│                                       │
│  Species                              │
│  ┌─────────────────────────────────┐ │
│  │ Dog                          ▼  │ │
│  └─────────────────────────────────┘ │
│                                       │
│  Breed (Optional)                     │
│  ┌─────────────────────────────────┐ │
│  │ Golden Retriever                │ │
│  └─────────────────────────────────┘ │
│                                       │
│  Weight                               │
│  ┌───────────────────┐ [lbs│kg]      │
│  │ 50                │               │
│  └───────────────────┘               │
│                                       │
└──────────────────────────────────────┘
```

## 🎭 Animation Examples

### Press Animation
```
Normal:     Pressed:    Released:
┌──────┐    ┌─────┐     ┌──────┐
│      │    │     │     │      │
│ Card │ -> │Card │ ->  │ Card │
│      │    │     │     │      │
└──────┘    └─────┘     └──────┘
(100%)      (95%)       (100%)
```

### Gradient Examples
```
Orange Gradient:
████████▓▓▓▓▓▓░░░░
From: Orange → 70% Orange

Green Gradient:
████████▓▓▓▓▓▓░░░░
From: Green → 70% Green

Blue Gradient:
████████▓▓▓▓▓▓░░░░
From: Blue → 70% Blue
```

## 📐 Spacing Guide

```
Screen Edge
│ 20pt padding
├──────────────────────
│
│  Element
│  
│  20pt spacing
│
├──────────────────────
│  Another Element
│
│  20pt padding
Screen Edge
```

## 🎨 Color Palette

### Primary Colors
```
BrandOrange:   ████ #FF8C42 (primary actions)
BrandBlue:     ████ #4A90E2 (documents)
BrandGreen:    ████ #52C41A (health/AI)
BrandPurple:   ████ #722ED1 (knowledge)
BrandCream:    ████ #FFF8F0 (background)
BrandDark:     ████ #1A1A1A (text)
```

### Gradients
```
All gradients:
Start: Full color
End: 70% opacity same color
Direction: Top-Left → Bottom-Right
```

## 📏 Element Sizes

### Avatar
```
• Outer blur circle: 95pt diameter
• Photo/Icon circle: 85pt diameter
• Border: 3pt white gradient
• Camera badge: 28pt diameter
```

### Feature Cards
```
• Height: 140pt
• Icon square: 54x54pt
• Corner radius: 20pt
• Shadow: 12pt blur, 4pt offset
• Badge: 22pt min diameter
```

### Typography
```
• App Title: 36pt Bold Rounded
• Pet Name: 28pt Bold Rounded
• Greeting: ~17pt Medium
• Feature Title: 15pt Semibold
• Body: System Default
• Caption: System Caption
```

## ⭐ Feature Card Grid

```
Row 1:
┌─────────────┐  ┌─────────────┐
│  Vet AI     │  │ Travel Mode │
│  Green      │  │ Orange      │
└─────────────┘  └─────────────┘

Row 2:
┌─────────────┐  ┌─────────────┐
│ Documents   │  │ Reminders   │
│ Blue        │  │ Purple (2)  │
└─────────────┘  └─────────────┘

Row 3:
┌─────────────┐  ┌─────────────┐
│ Emergency QR│  │ Health      │
│ Red         │  │ Pink        │
└─────────────┘  └─────────────┘

Row 4:
┌─────────────┐  ┌─────────────┐
│ Food&Treats │  │ Insurance   │
│ Orange      │  │ Cyan        │
└─────────────┘  └─────────────┘

Row 5:
┌─────────────┐  ┌─────────────┐
│Encyclopedia │  │ Dashboard   │
│ Indigo      │  │ Purple      │
└─────────────┘  └─────────────┘

Each card: ~160pt wide x 140pt tall
Spacing: 14pt between cards
```

## 🎬 User Journey

### First Time User:
```
1. See default icon (dog/cat)
2. Tap pet card
3. See "Add Photo" button
4. Tap → Photo picker opens
5. Select photo
6. Photo appears in circle
7. Tap "Save"
8. Return to home with avatar
```

### Returning User:
```
1. See pet photo immediately
2. Greeting changes with time
3. Tap feature cards to access
4. Smooth animations throughout
5. Badge shows notification counts
```

## 💫 Special Effects

### Shadows
```
Card Shadow:
• Color: Black @ 6% opacity
• Blur: 12pt
• Offset: (0, 4)

Icon Shadow:
• Color: Gradient color @ 40% opacity
• Blur: 8pt
• Offset: (0, 4)
```

### Borders
```
Avatar Border:
• Width: 3pt
• Type: Gradient
• Colors: White 80% → White 40%
• Direction: Top-Left → Bottom-Right
```

## 🎯 Interactive Elements

### Tappable Areas
```
Pet Card:
├─ Entire card (edit profile)
└─ ≥ 44x44pt touch target

Feature Cards:
├─ Entire card (open feature)
└─ ≥ 140x160pt (plenty of space)

My Pets Button:
├─ Pill shape
└─ ~100x40pt
```

## 🌅 Dynamic Elements

### Time-Based Greeting
```
12:00 AM - 11:59 AM: "Good Morning"
12:00 PM - 04:59 PM: "Good Afternoon"
05:00 PM - 11:59 PM: "Good Evening"
```

### Active Status
```
• Green dot indicator
• "Active Profile" text
• Shows which pet is currently selected
```

### Notification Badges
```
• Red circle
• White text
• Number count
• Position: Top-right of card
• Example: Reminders with overdue count
```

---

## 🎨 The Result

A **beautiful, modern, professional** pet care app with:
- ✅ Personal touch (pet photos)
- ✅ Intuitive navigation (colored cards)
- ✅ Smooth interactions (animations)
- ✅ Clear hierarchy (gradients & spacing)
- ✅ Premium feel (shadows & gradients)

Enjoy your new sleek home screen! 🐾✨
