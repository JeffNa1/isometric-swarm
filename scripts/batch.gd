class_name Batch
extends MultiMeshInstance2D
## Thin wrapper over a MultiMesh that is rebuilt from a flat float buffer every
## frame. One draw call per batch no matter how many instances.

const STRIDE := 16  # 8 transform + 4 color + 4 custom

var mm: MultiMesh
var buf := PackedFloat32Array()
var cap := 0
var n := 0

static func _quad() -> ArrayMesh:
	# A unit quad with UV (0,0) at the top-left in canvas space.
	var verts := PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func setup(capacity: int, shader: Shader) -> Batch:
	cap = capacity
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	mm.instance_count = cap
	mm.visible_instance_count = 0
	buf.resize(cap * STRIDE)
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = shader
	material = mat
	return self

func begin() -> void:
	n = 0

## Adds one instance. sx/sy are the quad's full width/height in pixels.
func add(px: float, py: float, sx: float, sy: float, rot: float, c: Color, c0: float = 0.0, c1: float = 0.0, c2: float = 0.0, c3: float = 0.0) -> void:
	if n >= cap:
		return
	var o := n * STRIDE
	if rot == 0.0:
		buf[o] = sx; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = px
		buf[o + 4] = 0.0; buf[o + 5] = sy; buf[o + 6] = 0.0; buf[o + 7] = py
	else:
		var cs := cos(rot)
		var sn := sin(rot)
		buf[o] = cs * sx; buf[o + 1] = -sn * sy; buf[o + 2] = 0.0; buf[o + 3] = px
		buf[o + 4] = sn * sx; buf[o + 5] = cs * sy; buf[o + 6] = 0.0; buf[o + 7] = py
	buf[o + 8] = c.r; buf[o + 9] = c.g; buf[o + 10] = c.b; buf[o + 11] = c.a
	buf[o + 12] = c0; buf[o + 13] = c1; buf[o + 14] = c2; buf[o + 15] = c3
	n += 1

func commit() -> void:
	mm.buffer = buf
	mm.visible_instance_count = n
