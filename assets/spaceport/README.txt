SPACEPORT ASSETS — GODOT
16 individual RGBA PNG sprites with transparent backgrounds.
Copy this folder into res://assets/spaceport/.
Use Sprite2D to preview sprites. For placed buildings, wrap each sprite in a
Node2D scene and add StaticBody2D/Area2D only when gameplay collision or picking is needed.
Set a consistent pivot/origin for isometric placement. Inspect alpha edges before release:
automatic background removal can leave minor halos or remove tiny low-contrast details.
See manifest.json for dimensions and filenames.
