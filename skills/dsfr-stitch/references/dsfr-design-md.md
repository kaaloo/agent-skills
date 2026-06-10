# DSFR DESIGN.md starter for Stitch

Use this as a starting point for Stitch exploration. Verify values against the official DSFR and the project’s existing implementation before production use.

```markdown
---
version: "alpha"
name: "Design System de l'État Français - DSFR"
description: "French government design system constraints for Stitch exploration. Production implementation must use DSFR or react-dsfr and RGAA review."
colors:
  primary: "#000091"
  secondary: "#6A6AF4"
  tertiary: "#E1000F"
  neutral: "#F6F6F6"
  on-primary: "#FFFFFF"
  on-tertiary: "#FFFFFF"
  info: "#0063CB"
  success: "#18753C"
  warning: "#B34000"
  error: "#CE0500"
  text-title: "#161616"
  text-default: "#3A3A3A"
  text-mention: "#666666"
  border-default: "#DDDDDD"
  background-default: "#FFFFFF"
  background-alt: "#F6F6F6"
typography:
  headline-lg:
    fontFamily: Marianne
    fontSize: 40px
    fontWeight: 700
    lineHeight: 1.3
  headline-md:
    fontFamily: Marianne
    fontSize: 32px
    fontWeight: 700
    lineHeight: 1.3
  body-md:
    fontFamily: Marianne
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
  label-md:
    fontFamily: Marianne
    fontSize: 14px
    fontWeight: 500
    lineHeight: 1.4
rounded:
  none: 0px
  sm: 4px
  md: 8px
spacing:
  xs: 8px
  sm: 16px
  md: 24px
  lg: 32px
  xl: 48px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.none}"
    padding: 12px
  card:
    backgroundColor: "{colors.background-default}"
    textColor: "{colors.text-default}"
    rounded: "{rounded.sm}"
  alert-error:
    backgroundColor: "#FFE9E9"
    textColor: "{colors.error}"
---

# Design System

## Overview
Institutional, accessible, restrained interface for a French public service. The design should feel clear, trustworthy, and operational, not startup-like or decorative.

## Colors
Use DSFR identity and functional colors. Do not invent custom palettes. Blue France is the primary interaction color; Red Marianne is reserved for identity and critical or error contexts.

## Typography
Use Marianne for UI text. Do not substitute generic Google Fonts in production-oriented concepts.

## Layout
Use a 12-column DSFR-style grid, clear hierarchy, generous readable spacing, and responsive behavior from mobile to desktop.

## Elevation & Depth
Prefer flat surfaces, borders, and spacing over heavy shadows.

## Shapes
Avoid pill-shaped SaaS UI. Buttons are square or DSFR-like; cards may be lightly rounded only if appropriate.

## Components
Conceptual output must map to react-dsfr components: Header, Footer, Breadcrumb, Card, Button, Input, Select, Alert, Notice, Table, Tabs, Accordion, Modal, Pagination, SideMenu.

## Do's and Don'ts
- Do include République Française and service framing when appropriate.
- Do use clear French institutional copy.
- Do preserve focus, contrast, labels, and keyboard navigation expectations.
- Don't use Tailwind output as production DSFR code.
- Don't use shadcn/ui or custom components when DSFR provides a component.
```
