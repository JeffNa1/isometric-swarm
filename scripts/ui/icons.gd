class_name Icons
## Procedural vector icons for every weapon and system, drawn into any CanvasItem.

static func draw(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.09)
	match id:
		"pulse":
			for k in 3:
				var x := c.x - s * 0.35 + k * s * 0.3
				ci.draw_line(Vector2(x, c.y + s * 0.18), Vector2(x + s * 0.22, c.y - s * 0.18), col, w * 1.3, true)
			ci.draw_circle(c + Vector2(s * 0.38, -s * 0.28), s * 0.1, Color.WHITE)
		"orbit":
			ci.draw_arc(c, s * 0.34, 0, TAU, 32, Color(col, 0.5), w * 0.7, true)
			for k in 3:
				var a := TAU * k / 3.0 - 0.4
				var p := c + Vector2.from_angle(a) * s * 0.34
				var f := Vector2.from_angle(a + PI * 0.5)
				ci.draw_colored_polygon(PackedVector2Array([p + f * s * 0.18, p + Vector2.from_angle(a) * s * 0.07, p - f * s * 0.1, p - Vector2.from_angle(a) * s * 0.07]), col)
			ci.draw_circle(c, s * 0.08, Color.WHITE)
		"arc":
			var pts := PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.42), c + Vector2(-s * 0.22, s * 0.02), c + Vector2(s * 0.06, s * 0.0), c + Vector2(-s * 0.06, s * 0.42), c + Vector2(s * 0.24, -s * 0.08), c + Vector2(-s * 0.02, -s * 0.06), c + Vector2(s * 0.12, -s * 0.42)])
			ci.draw_colored_polygon(pts, col)
		"nova":
			ci.draw_circle(c, s * 0.12, Color.WHITE)
			ci.draw_arc(c, s * 0.24, 0, TAU, 32, col, w, true)
			ci.draw_arc(c, s * 0.4, 0, TAU, 40, Color(col, 0.55), w * 0.8, true)
		"lance":
			ci.draw_line(c + Vector2(-s * 0.4, s * 0.4), c + Vector2(s * 0.4, -s * 0.4), Color(col, 0.4), w * 3.0, true)
			ci.draw_line(c + Vector2(-s * 0.4, s * 0.4), c + Vector2(s * 0.4, -s * 0.4), Color.WHITE, w, true)
			ci.draw_circle(c + Vector2(-s * 0.4, s * 0.4), s * 0.1, col)
		"mortar":
			ci.draw_arc(c + Vector2(0, s * 0.18), s * 0.38, PI * 1.1, PI * 1.9, 20, Color(col, 0.6), w * 0.7, true)
			ci.draw_circle(c + Vector2(s * 0.24, s * 0.1), s * 0.12, col)
			ci.draw_arc(c + Vector2(s * 0.24, s * 0.1), s * 0.22, 0, TAU, 20, Color(col, 0.5), w * 0.6, true)
			ci.draw_circle(c + Vector2(-s * 0.3, s * 0.2), s * 0.07, Color.WHITE)
		"power":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.3, s * 0.05), c + Vector2(s * 0.08, s * 0.05), c + Vector2(s * 0.12, s * 0.42), c + Vector2(-s * 0.3, -s * 0.06), c + Vector2(-s * 0.06, -s * 0.06)]), col)
		"rapid":
			for k in 3:
				var y := c.y - s * 0.25 + k * s * 0.25
				ci.draw_line(Vector2(c.x - s * 0.35 + k * s * 0.08, y), Vector2(c.x + s * 0.35, y), Color(col, 1.0 - k * 0.25), w * 1.2, true)
		"reach":
			ci.draw_arc(c, s * 0.18, 0, TAU, 20, col, w, true)
			for k in 4:
				var d := Vector2.from_angle(TAU * k / 4.0 + PI * 0.25)
				ci.draw_line(c + d * s * 0.26, c + d * s * 0.42, col, w, true)
		"swift":
			for k in 2:
				var x := c.x - s * 0.2 + k * s * 0.25
				ci.draw_polyline(PackedVector2Array([Vector2(x - s * 0.1, c.y - s * 0.3), Vector2(x + s * 0.15, c.y), Vector2(x - s * 0.1, c.y + s * 0.3)]), col, w * 1.3, true)
		"vital":
			var r := s * 0.15
			ci.draw_rect(Rect2(c.x - r, c.y - s * 0.38, r * 2, s * 0.76), col)
			ci.draw_rect(Rect2(c.x - s * 0.38, c.y - r, s * 0.76, r * 2), col)
		"magnet":
			ci.draw_arc(c + Vector2(0, -s * 0.02), s * 0.28, 0, PI, 20, col, w * 2.0, true)
			ci.draw_line(c + Vector2(-s * 0.28, -s * 0.02), c + Vector2(-s * 0.28, -s * 0.32), col, w * 2.0, true)
			ci.draw_line(c + Vector2(s * 0.28, -s * 0.02), c + Vector2(s * 0.28, -s * 0.32), col, w * 2.0, true)
			ci.draw_line(c + Vector2(-s * 0.28, -s * 0.24), c + Vector2(-s * 0.28, -s * 0.34), Color.WHITE, w * 2.0, true)
			ci.draw_line(c + Vector2(s * 0.28, -s * 0.24), c + Vector2(s * 0.28, -s * 0.34), Color.WHITE, w * 2.0, true)
		"heal":
			ci.draw_circle(c, s * 0.38, Color(col, 0.25))
			ci.draw_rect(Rect2(c.x - s * 0.08, c.y - s * 0.26, s * 0.16, s * 0.52), Color.WHITE)
			ci.draw_rect(Rect2(c.x - s * 0.26, c.y - s * 0.08, s * 0.52, s * 0.16), Color.WHITE)
		_:
			var pts := PackedVector2Array()
			for k in 5:
				var a := -PI * 0.5 + TAU * k / 5.0
				pts.append(c + Vector2.from_angle(a) * s * 0.4)
				pts.append(c + Vector2.from_angle(a + TAU / 10.0) * s * 0.17)
			ci.draw_colored_polygon(pts, col)
