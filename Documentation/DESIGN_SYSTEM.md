# Terminal Design System States

NEXUS uses one restrained phosphor family with semantic exceptions. Color is never the only signal.

| State | Visual and non-color signal |
|---|---|
| Default | green text, thin border, dark green-black surface |
| Hover | subtle 7% phosphor surface lift |
| Keyboard focus | native macOS focus ring retained |
| Selected | 3 pt leading bar plus 14% surface fill |
| Disabled | muted gray-green text/border and native disabled semantics |
| Loading | hourglass/progress indicator plus “Yükleniyor” text |
| Success | checkmark-circle plus success text |
| Warning | warning triangle plus warning text |
| Error | xmark-octagon plus error text |

The scanline and glow layers are decorative, subtle, independently switchable, and hidden from accessibility. System Reduce Transparency and Reduce Motion are respected. Text scale changes Dynamic Type size across the terminal surface; VoiceOver labels are added where an icon or state would otherwise be ambiguous.

Phase 10 adds only native vector/typographic motion. The boot core uses thin Canvas geometry in existing phosphor tokens; it is not a dashboard, gaming HUD, raster computer chassis or photorealistic CRT. Generated headings/status may use `TerminalRevealText`, but editable/user-authored content never does. Reduce Motion and VoiceOver receive the complete static string, the animation is skippable, and no typewriter sound exists.
