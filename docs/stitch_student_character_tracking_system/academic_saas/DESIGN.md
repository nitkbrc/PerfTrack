---
name: Academic SaaS
colors:
  surface: '#f7faf9'
  surface-dim: '#d7dbda'
  surface-bright: '#f7faf9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f4f3'
  surface-container: '#ebeeed'
  surface-container-high: '#e6e9e8'
  surface-container-highest: '#e0e3e2'
  on-surface: '#181c1c'
  on-surface-variant: '#454652'
  inverse-surface: '#2d3131'
  inverse-on-surface: '#eef1f0'
  outline: '#767683'
  outline-variant: '#c6c5d4'
  surface-tint: '#4c56af'
  primary: '#000666'
  on-primary: '#ffffff'
  primary-container: '#1a237e'
  on-primary-container: '#8690ee'
  inverse-primary: '#bdc2ff'
  secondary: '#2857c4'
  on-secondary: '#ffffff'
  secondary-container: '#668efe'
  on-secondary-container: '#00266e'
  tertiary: '#380b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#5c1800'
  on-tertiary-container: '#e17c5a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e0e0ff'
  primary-fixed-dim: '#bdc2ff'
  on-primary-fixed: '#000767'
  on-primary-fixed-variant: '#343d96'
  secondary-fixed: '#dbe1ff'
  secondary-fixed-dim: '#b4c5ff'
  on-secondary-fixed: '#00174b'
  on-secondary-fixed-variant: '#003ea7'
  tertiary-fixed: '#ffdbd0'
  tertiary-fixed-dim: '#ffb59d'
  on-tertiary-fixed: '#390c00'
  on-tertiary-fixed-variant: '#7b2e12'
  background: '#f7faf9'
  on-background: '#181c1c'
  surface-variant: '#e0e3e2'
  text-main: '#212529'
  text-muted: '#6C757D'
  surface-white: '#FFFFFF'
  border-subtle: '#DEE2E6'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  baseline: 4px
  container-max: 1440px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 32px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
---

## Brand & Style

This design system is built for high-utility academic environments, prioritizing efficiency, clarity, and institutional trust. The design style follows a **Corporate / Modern** aesthetic with a strong emphasis on dashboard-centric functionality. 

The visual language is restrained and professional, utilizing a structured layout to manage complex data hierarchies (Divisions, Sub-divisions, and Categories). The interface evokes a sense of reliability and precision, minimizing cognitive load for students and faculty through high-contrast legibility and a systematic application of whitespace.

## Colors

The palette is anchored by a **Deep Navy Blue** primary color, signaling authority and stability. The background uses a high-contrast **Off-White/Light Gray** to reduce eye strain during prolonged use while maintaining a clean, modern "SaaS" feel. 

- **Primary:** Used for key actions, active states, and primary navigation headers.
- **Secondary:** Employed for accent elements and secondary interactive components to provide visual variety without breaking the professional tone.
- **Neutral:** The foundation for the background, ensuring that content cards and data tables remain the focal point.
- **Named Colors:** Used for precise control over typography hierarchy and subtle UI borders that define the grid.

## Typography

This design system utilizes **Inter** across all levels to ensure maximum legibility and a clean, systematic feel. The type scale is optimized for data-dense environments.

Headlines use a tighter letter-spacing and heavier weights to provide clear entry points into different Divisions. Body text is set with generous line-height to maintain readability in long-form academic content or lists. Labels use a slightly heavier weight and occasional uppercase styling to distinguish metadata from primary content.

## Layout & Spacing

The layout follows a **Fixed Grid** philosophy for desktop to maintain a professional dashboard feel, centered within a 1440px container. 

A 12-column system is used to organize the core structural concepts:
- **Divisions:** Top-level navigation or major page sections (spanning 12 columns).
- **Sub-divisions:** Columnar groupings or sidebar-content splits (e.g., 3-column sidebar, 9-column main).
- **Categories:** Content cards or list items nested within Sub-divisions.

Spacing follows a 4px baseline. Gutters are kept at a consistent 24px to provide clear separation between data cards without wasting excessive screen real estate.

## Elevation & Depth

Hierarchy is conveyed through **Tonal Layers** and **Low-Contrast Outlines**. 

- **Surface Level 0:** The off-white background (#F4F7F6).
- **Surface Level 1:** White cards (#FFFFFF) representing Categories or Sub-divisions. These use a 1px border (#DEE2E6) and a very subtle ambient shadow (0px 2px 4px rgba(0,0,0,0.05)) to lift them slightly from the background.
- **Surface Level 2:** Overlays or active dropdowns, which use a more pronounced diffused shadow to indicate temporary focus.

This approach ensures the UI feels tactile and organized without the "heaviness" of traditional skeuomorphism.

## Shapes

The shape language is **Soft**, utilizing a 0.25rem (4px) base radius. This provides a clean, disciplined look that feels modern but remains grounded and professional. Larger containers like main content cards may use the `rounded-lg` (8px) setting to create a clear visual container for complex data.

## Components

- **Cards:** The primary container for "Categories." They must have a white background, a subtle gray border, and a consistent 4px corner radius. Padding inside cards should be 24px for desktop.
- **Buttons:** Primary buttons use the Deep Navy Blue with white text. Secondary buttons should use the "border-subtle" outline with "text-main." Interaction states (hover) should involve a slight darkening of the background color.
- **Chips/Badges:** Used for status indicators (e.g., "Active," "Pending"). They use low-saturation background tints derived from the primary or secondary colors with high-contrast text.
- **Input Fields:** Minimalist design with a 1px border. On focus, the border color shifts to the primary navy blue with a subtle glow (2px spread).
- **Lists:** Clean, horizontal rows with 1px dividers. Each row should have a subtle hover state change (#F8F9FA) to assist in row-tracking across data-heavy tables.
- **Navigation:** The "Division" level navigation should be persistent, either as a top bar or a high-contrast sidebar, utilizing the primary navy blue for the background to establish clear structural hierarchy.