"""Shared helpers for weapon models: a face list with texture coordinates, the game's
model format (DirectX .X text) written and read, and Blender previews.

A weapon is built as plain Python data in the game's own model space, so the same
numbers go to Blender (to look at) and to the .X file (to play with):

  +Y  along the weapon, away from the hand; the grip is at the origin and the butt a
      little behind it (vanilla: the ice hockey stick runs y -0.09 .. 0.67)
  -Z  the cutting edge (vanilla's fire axe and meat cleaver both cut towards -Z)
   X  the thin way

Units are the game's: about half a metre each for long weapons (vanilla's 1.5 m ice
hockey stick is 0.77 long), with small things drawn a bit big (the meat cleaver is 0.24).

Faces are wound counter-clockwise seen from outside, as vanilla's are, and written
flat-shaded: every face corner is its own vertex with the face's normal. Texture
coordinates are (u, v) with v measured from the top of the image, as the game reads them;
Blender's are flipped on the way in.

Only the Blender functions need bpy, so a texture painter can import this file (and a
weapon's build script, for its layout) from ordinary Python.
"""
import math
import os
import re


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def unit(a):
    n = math.sqrt(dot(a, a))
    return (a[0] / n, a[1] / n, a[2] / n) if n > 1e-12 else (0.0, 0.0, 0.0)


def face_normal(points):
    n = cross(sub(points[1], points[0]), sub(points[2], points[0]))
    if dot(n, n) < 1e-18 and len(points) > 3:
        n = cross(sub(points[2], points[0]), sub(points[3], points[0]))
    return unit(n)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def scale(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def centre(points):
    n = float(len(points))
    return (sum(p[0] for p in points) / n, sum(p[1] for p in points) / n, sum(p[2] for p in points) / n)


def ring(mid, u, v, ru, rv, n, turn=0.0):
    """n points round an ellipse: mid + ru cos(t) u + rv sin(t) v, t starting at `turn`
    of a full circle. A round shaft is a row of these skinned with Mesh.loft."""
    out = []
    for k in range(n):
        t = 2.0 * math.pi * (k / float(n) + turn)
        out.append(add(mid, add(scale(u, ru * math.cos(t)), scale(v, rv * math.sin(t)))))
    return out


def placer(origin, ex, ey, ez):
    """f(a, b, c) -> origin + a ex + b ey + c ez: a part drawn in its own axes, put in place."""
    def f(a, b, c):
        return add(origin, add(scale(ex, a), add(scale(ey, b), scale(ez, c))))
    return f


class Atlas:
    """A square texture and where things sit on it. Rectangles are (x0, y0, x1, y1) in
    pixels from the top left; coordinates stop half a pixel short of a rectangle's edge so
    a neighbour never bleeds in."""

    def __init__(self, size):
        self.size = size

    def uv(self, rect, a, b):
        x0, y0, x1, y1 = rect
        px = x0 + 0.5 + a * (x1 - x0 - 1.0)
        py = y0 + 0.5 + b * (y1 - y0 - 1.0)
        return (px / self.size, py / self.size)

    def mapper(self, rect, along="v", a_range=(0.0, 1.0), b_range=(0.0, 1.0)):
        """f(a, b) -> (u, v). a and b are 0..1 over a face; each is first stretched into
        its range of the rectangle. along="v": a runs across the image, b down it;
        along="u": b runs across, a down."""
        def f(a, b):
            a2 = a_range[0] + a * (a_range[1] - a_range[0])
            b2 = b_range[0] + b * (b_range[1] - b_range[0])
            return self.uv(rect, a2, b2) if along == "v" else self.uv(rect, b2, a2)
        return f


class Mesh:
    def __init__(self):
        self.faces = []   # (points, uvs): 3 or 4 corners, counter-clockwise from outside

    def face(self, points, uvs, outward):
        """Add a triangle or quad; `outward` is roughly the way it faces, and the corners
        are turned round if they were given the other way."""
        points, uvs = list(points), list(uvs)
        if dot(face_normal(points), outward) < 0:
            points.reverse()
            uvs.reverse()
        self.faces.append((points, uvs))

    def box(self, x0, x1, y0, y1, z0, z1, uv, skip=()):
        """An axis-aligned box. `uv` maps a face name to an f(a, b): on the four long
        sides (+x -x +z -z) a runs across the face and b along y; on the ends (+y -y) a
        runs along x and b along z. `uv["sides"]`, `uv["ends"]` and `uv["all"]` stand in
        for faces not named."""
        def f(name, group):
            return uv.get(name) or uv.get(group) or uv["all"]
        ab = [(0, 0), (0, 1), (1, 1), (1, 0)]
        for name, x, out in (("+x", x1, (1, 0, 0)), ("-x", x0, (-1, 0, 0))):
            if name not in skip:
                g = f(name, "sides")
                self.face([(x, y0, z0), (x, y1, z0), (x, y1, z1), (x, y0, z1)], [g(a, b) for a, b in ab], out)
        ab = [(0, 0), (1, 0), (1, 1), (0, 1)]
        for name, z, out in (("+z", z1, (0, 0, 1)), ("-z", z0, (0, 0, -1))):
            if name not in skip:
                g = f(name, "sides")
                self.face([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], [g(a, b) for a, b in ab], out)
        for name, y, out in (("+y", y1, (0, 1, 0)), ("-y", y0, (0, -1, 0))):
            if name not in skip:
                g = f(name, "ends")
                self.face([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], [g(a, b) for a, b in ab], out)

    def loft(self, rings, bs, uv, caps=(None, None)):
        """Skin a row of rings (each the same number of points, going round the same way):
        a round or tapering shaft, straight or bent. `uv` is an f(a, b) with a once round
        the ring and b each ring's value in `bs`. `caps` are f(a, b) mappers for a flat
        end at the first and the last ring (None leaves that end open)."""
        n = len(rings[0])
        for i in range(len(rings) - 1):
            mid = centre(rings[i] + rings[i + 1])
            for k in range(n):
                k2 = (k + 1) % n
                pts = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
                a0, a1 = k / float(n), (k + 1) / float(n)
                uvs = [uv(a0, bs[i]), uv(a1, bs[i]), uv(a1, bs[i + 1]), uv(a0, bs[i + 1])]
                self.face(pts, uvs, sub(centre(pts), mid))
        for which, cap in ((0, caps[0]), (-1, caps[1])):
            if cap is None:
                continue
            pts = rings[which]
            other = rings[1] if which == 0 else rings[-2]
            out = sub(centre(pts), centre(other))
            cuv = [cap(0.5 + 0.5 * math.cos(2 * math.pi * k / n), 0.5 + 0.5 * math.sin(2 * math.pi * k / n))
                   for k in range(n)]
            for k in range(1, n - 1):
                self.face([pts[0], pts[k], pts[k + 1]], [cuv[0], cuv[k], cuv[k + 1]], out)

    def plate(self, points, uvs, outward, thick=0.0012):
        """A thin sheet seen from both sides: the face, and its back `thick` behind it
        (two faces in the same place flicker in a renderer that draws both)."""
        self.face(points, uvs, outward)
        back = scale(unit(outward), -thick)
        self.face([add(p, back) for p in points], uvs, scale(outward, -1.0))

    def triangles(self):
        """(three points, three uvs, normal) for every face, quads split in two."""
        out = []
        for points, uvs in self.faces:
            n = face_normal(points)
            out.append((points[:3], uvs[:3], n))
            if len(points) == 4:
                out.append(([points[0], points[2], points[3]], [uvs[0], uvs[2], uvs[3]], n))
        return out

    def bounds(self):
        pts = [p for points, _ in self.faces for p in points]
        return [(min(p[k] for p in pts), max(p[k] for p in pts)) for k in range(3)]


# The game's model format ---------------------------------------------------------------
X_HEADER = """xof 0303txt 0032
template ColorRGBA {
 <35ff44e0-6c7c-11cf-8f52-0040333594a3>
 FLOAT red;
 FLOAT green;
 FLOAT blue;
 FLOAT alpha;
}

template ColorRGB {
 <d3e16e81-7835-11cf-8f52-0040333594a3>
 FLOAT red;
 FLOAT green;
 FLOAT blue;
}

template Material {
 <3d82ab4d-62da-11cf-ab39-0020af71e433>
 ColorRGBA faceColor;
 FLOAT power;
 ColorRGB specularColor;
 ColorRGB emissiveColor;
 [...]
}

template TextureFilename {
 <a42790e1-7810-11cf-8f52-0040333594a3>
 STRING filename;
}

template Frame {
 <3d82ab46-62da-11cf-ab39-0020af71e433>
 [...]
}

template Matrix4x4 {
 <f6f23f45-7686-11cf-8f52-0040333594a3>
 array FLOAT matrix[16];
}

template FrameTransformMatrix {
 <f6f23f41-7686-11cf-8f52-0040333594a3>
 Matrix4x4 frameMatrix;
}

template Vector {
 <3d82ab5e-62da-11cf-ab39-0020af71e433>
 FLOAT x;
 FLOAT y;
 FLOAT z;
}

template MeshFace {
 <3d82ab5f-62da-11cf-ab39-0020af71e433>
 DWORD nFaceVertexIndices;
 array DWORD faceVertexIndices[nFaceVertexIndices];
}

template Mesh {
 <3d82ab44-62da-11cf-ab39-0020af71e433>
 DWORD nVertices;
 array Vector vertices[nVertices];
 DWORD nFaces;
 array MeshFace faces[nFaces];
 [...]
}

template MeshNormals {
 <f6f23f43-7686-11cf-8f52-0040333594a3>
 DWORD nNormals;
 array Vector normals[nNormals];
 DWORD nFaceNormals;
 array MeshFace faceNormals[nFaceNormals];
}

template MeshMaterialList {
 <f6f23f42-7686-11cf-8f52-0040333594a3>
 DWORD nMaterials;
 DWORD nFaceIndexes;
 array DWORD faceIndexes[nFaceIndexes];
 [Material <3d82ab4d-62da-11cf-ab39-0020af71e433>]
}

template Coords2d {
 <f6f23f44-7686-11cf-8f52-0040333594a3>
 FLOAT u;
 FLOAT v;
}

template MeshTextureCoords {
 <f6f23f40-7686-11cf-8f52-0040333594a3>
 DWORD nTextureCoords;
 array Coords2d textureCoords[nTextureCoords];
}

"""


def write_x(mesh, path, name, texture):
    """Write the mesh the way vanilla's weapon files are laid out: one frame with an
    identity matrix, one mesh, flat normals, one material naming the texture."""
    tris = mesh.triangles()
    verts, normals, uvs, faces = [], [], [], []
    for points, tuv, n in tris:
        base = len(verts)
        verts.extend(points)
        normals.extend([n, n, n])
        uvs.extend(tuv)
        faces.append((base, base + 1, base + 2))

    def rows(items, fmt):
        return ",\n".join(fmt(i) for i in items) + ";"

    v3 = lambda p: "  %.6f;%.6f;%.6f;" % (p[0] + 0.0, p[1] + 0.0, p[2] + 0.0)   # noqa: E731
    n3 = lambda p: "   %.6f;%.6f;%.6f;" % (p[0] + 0.0, p[1] + 0.0, p[2] + 0.0)  # noqa: E731
    lines = [X_HEADER.rstrip("\n"), "",
             "Material %s_Material {" % name,
             " 1.000000;1.000000;1.000000;1.000000;;",
             " 9.999999;",
             " 0.000000;0.000000;0.000000;;",
             " 0.000000;0.000000;0.000000;;",
             "",
             " TextureFilename {",
             '  "%s";' % texture,
             " }",
             "}",
             "",
             "Frame %s {" % name,
             " ",
             "",
             " FrameTransformMatrix {",
             "  1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,"
             "0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,0.000000,1.000000;;",
             " }",
             "",
             " Mesh %s {" % name,
             "  %d;" % len(verts),
             rows(verts, v3),
             "  %d;" % len(faces),
             rows(faces, lambda f: "  3;%d,%d,%d;" % f),
             "",
             "  MeshNormals {",
             "   %d;" % len(normals),
             rows(normals, n3),
             "   %d;" % len(faces),
             rows(faces, lambda f: "   3;%d,%d,%d;" % f),
             "  }",
             "",
             "  MeshMaterialList {",
             "   1;",
             "   %d;" % len(faces),
             ",\n".join("   0" for _ in faces) + ";",
             "   { %s_Material }" % name,
             "  }",
             "",
             "  MeshTextureCoords c1 {",
             "   %d;" % len(uvs),
             rows(uvs, lambda t: "   %.6f;%.6f;" % (t[0], t[1])),
             "  }",
             " }",
             "}",
             ""]
    with open(path, "w", newline="\r\n") as f:
        f.write("\n".join(lines))
    return len(verts), len(faces)


def read_x(path):
    """The meshes in a text .X file: [{name, verts, faces, uvs}] (frame matrices are
    ignored: vanilla's weapon files all carry the identity)."""
    text = re.sub(r"//[^\n]*", "", open(path, encoding="latin-1").read())
    toks = re.findall(r"<[^>]*>|\"[^\"]*\"|[{};,]|[^\s{};,]+", text)
    i, out = 0, []

    def nums(n):
        nonlocal i
        vals = []
        while len(vals) < n:
            t = toks[i]
            i += 1
            if t not in (";", ","):
                vals.append(float(t))
        return vals

    while i < len(toks):
        t = toks[i]
        if t == "template":
            while toks[i] != "}":
                i += 1
        elif t == "Mesh":
            named = toks[i + 1] != "{"
            name = toks[i + 1] if named else ""
            i += 3 if named else 2
            verts = [tuple(nums(3)) for _ in range(int(nums(1)[0]))]
            faces = []
            for _ in range(int(nums(1)[0])):
                faces.append([int(v) for v in nums(int(nums(1)[0]))])
            out.append({"name": name, "verts": verts, "faces": faces, "uvs": None})
            continue
        elif t == "MeshTextureCoords":
            i += 2 if toks[i + 1] == "{" else 3
            out[-1]["uvs"] = [tuple(nums(2)) for _ in range(int(nums(1)[0]))]
            continue
        i += 1
    return out


def check_x(path):
    """Read a written file back: (vertices, faces, bounds, faces wound outward, faces not).
    Outward is judged from the mesh's middle, which is only roughly right for a shape
    like this; vanilla's own files score about nine in ten."""
    m = read_x(path)[0]
    vs, fs = m["verts"], m["faces"]
    c = [sum(v[k] for v in vs) / len(vs) for k in range(3)]
    good = bad = 0
    for f in fs:
        n = cross(sub(vs[f[1]], vs[f[0]]), sub(vs[f[2]], vs[f[0]]))
        fc = [sum(vs[j][k] for j in f) / len(f) for k in range(3)]
        if dot(n, sub(fc, c)) >= 0:
            good += 1
        else:
            bad += 1
    bounds = [(min(v[k] for v in vs), max(v[k] for v in vs)) for k in range(3)]
    return len(vs), len(fs), bounds, good, bad


# Blender ---------------------------------------------------------------------------------
def textured_material(name, image_path):
    import bpy
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    p = nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.75
    p.inputs["Specular IOR Level"].default_value = 0.25
    if image_path and os.path.exists(image_path):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(image_path)
        tex.interpolation = "Linear"
        mat.node_tree.links.new(tex.outputs["Color"], p.inputs["Base Color"])
    else:
        p.inputs["Base Color"].default_value = (0.8, 0.1, 0.7, 1.0)   # no texture: loud on purpose
    return mat


def add_object(name, verts, faces, uvs, image_path):
    """A Blender object from corner-indexed data; uvs are per vertex, v from the top."""
    import bpy
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    if uvs:
        layer = me.uv_layers.new(name="UVMap")
        for loop in me.loops:
            u, v = uvs[loop.vertex_index]
            layer.data[loop.index].uv = (u, 1.0 - v)
    me.materials.append(textured_material(name, image_path))
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_to_blender(mesh, name, image_path):
    verts, faces, uvs = [], [], []
    for points, fuv in mesh.faces:
        faces.append(list(range(len(verts), len(verts) + len(points))))
        verts.extend(points)
        uvs.extend(fuv)
    return add_object(name, verts, faces, uvs, image_path)


def x_to_blender(path, image_path, name=None):
    m = read_x(path)[0]
    return add_object(name or m["name"], m["verts"], m["faces"], m["uvs"], image_path)


def setup_scene(samples=48):
    """Cycles on the CPU, an ortho camera, a sun, a soft sky and a dark backdrop that
    `shot` puts behind whatever the camera looks at."""
    import bpy
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.film_transparent = False
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    world = bpy.data.worlds.new("Ambient")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.84, 0.88, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    scene.world = world

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    sun = bpy.data.lights.new("Key", "SUN")
    sun.energy = 2.6
    sun.angle = math.radians(12)
    sun_obj = bpy.data.objects.new("Key", sun)
    scene.collection.objects.link(sun_obj)

    back = bpy.data.meshes.new("Backdrop")
    back.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [[0, 1, 2, 3]])
    mat = bpy.data.materials.new("Backdrop")
    mat.use_nodes = True
    p = mat.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.045, 0.05, 0.058, 1.0)
    p.inputs["Roughness"].default_value = 1.0
    p.inputs["Specular IOR Level"].default_value = 0.0
    back.materials.append(mat)
    back_obj = bpy.data.objects.new("Backdrop", back)
    scene.collection.objects.link(back_obj)
    return {"scene": scene, "cam": cam, "sun": sun_obj, "back": back_obj}


def shot(rig, path, target, toward, up, width, size, behind=0.5):
    """Render one view: the camera sits `toward` the target looking back at it, `up` is
    up on screen, `width` is how much of the model space the picture is wide, `size` its
    pixels. The sun comes over the viewer's left shoulder and the backdrop stands
    `behind` the target."""
    import bpy
    from mathutils import Matrix, Vector
    z = Vector(toward).normalized()
    x = Vector(up).cross(z).normalized()
    y = z.cross(x)
    rot = Matrix((x, y, z)).transposed()
    m = rot.to_4x4()
    m.translation = Vector(target) + z * 3.0
    rig["cam"].matrix_world = m
    rig["cam"].data.ortho_scale = width
    b = rot.to_4x4()
    b.translation = Vector(target) - z * behind
    rig["back"].matrix_world = b
    light = (z * 1.0 + y * 0.9 - x * 0.55).normalized()
    rig["sun"].rotation_euler = light.to_track_quat("Z", "Y").to_euler()
    scene = rig["scene"]
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path, flush=True)


def run(name, texture, mesh, here, shots, compare=None, blend=None):
    """A build script's main, shared: write <name>.X, put the mesh in Blender, save the
    .blend and render the previews.

    shots:   [(file, target, toward, up, width, (w, h))], as `shot` takes them
    compare: ([(folder, vanilla name, where, turn about y)], one more shot) rendered only
             with --game <the game's media folder>, vanilla's models beside this one
    Flags after `--`: --out DIR, --game DIR, --samples N, --no-render."""
    import argparse
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=here)
    ap.add_argument("--game", default=None, help="the game's media folder, for the comparison picture")
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--no-render", action="store_true")
    args = ap.parse_args(argv)

    x_path = os.path.join(args.out, name + ".X")
    nv, nf = write_x(mesh, x_path, name, texture)
    print("wrote %s: %d vertices, %d triangles" % (x_path, nv, nf))
    print("bounds x, y, z:", [(round(a, 4), round(b, 4)) for a, b in mesh.bounds()])
    print("read back:", check_x(x_path))

    import bpy
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    mesh_to_blender(mesh, name, os.path.join(args.out, texture))
    rig = setup_scene(args.samples)
    blend_path = os.path.join(args.out, (blend or name.lower()) + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    if os.path.exists(blend_path + "1"):
        os.remove(blend_path + "1")
    if args.no_render:
        return

    def out(file):
        return os.path.join(args.out, file).replace("\\", "/")

    for file, target, toward, up, width, size in shots:
        shot(rig, out(file), target, toward, up, width, size)
    if args.game and compare:
        rows, (file, target, toward, up, width, size) = compare
        for folder, vname, where, turn in rows:
            base = os.path.join(args.game, "models_X", "weapons", folder, vname)
            path = base + (".X" if os.path.exists(base + ".X") else ".x")
            obj = x_to_blender(path, os.path.join(args.game, "textures", "weapons", folder, vname + ".png"),
                               "vanilla_" + vname)
            obj.location = where
            obj.rotation_euler = (0.0, turn, 0.0)
        shot(rig, out(file), target, toward, up, width, size)
