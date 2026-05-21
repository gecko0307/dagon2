import sys
import hashlib
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple
from mathutils import Matrix, Quaternion

import bpy
from bpy_extras.io_utils import ExportHelper
from bpy.props import StringProperty, BoolProperty
from bpy.types import Operator
from mathutils import Quaternion

from .daf import (
    DAFAsset,
    DAFEntity,
    DAFMesh,
    DAFMaterial,
    DAFTexture,
    DAFTextureSemantic,
    BlendMode,
)


_BASIS_MATRIX = Matrix((
    (1.0,  0.0,  0.0),
    (0.0,  0.0,  1.0),
    (0.0, -1.0,  0.0),
))

_BASIS_MATRIX_INV = _BASIS_MATRIX.inverted()


def _transform_position(pos: Tuple[float, float, float]) -> Tuple[float, float, float]:
    x, y, z = pos
    return (x, z, -y)

def _transform_scale(scale):
    x, y, z = scale
    return (x, z, y)

def _transform_vector(vec: Tuple[float, float, float]) -> Tuple[float, float, float]:
    x, y, z = vec
    return (x, z, -y)

def _transform_quaternion(quat: Quaternion) -> Quaternion:
    rot_matrix = quat.to_matrix()
    converted = (
        _BASIS_MATRIX @
        rot_matrix @
        _BASIS_MATRIX_INV
    )
    return converted.to_quaternion()


def _get_object_quaternion(obj: bpy.types.Object) -> Quaternion:
    if obj.rotation_mode == 'QUATERNION':
        return obj.rotation_quaternion.copy()
    if obj.rotation_mode == 'AXIS_ANGLE':
        angle, x, y, z = obj.rotation_axis_angle
        return Quaternion((x, y, z), angle)
    return obj.rotation_euler.to_quaternion()


def _get_object_classes(obj: bpy.types.Object) -> List[str]:
    raw = obj.get('daf_classes')
    if isinstance(raw, (list, tuple)):
        return [str(item) for item in raw if item is not None]
    if raw is not None:
        return [str(raw)]
    return []

def _build_mesh_from_object(
    obj: bpy.types.Object,
    mesh: bpy.types.Mesh,
    material_map: dict[bpy.types.Material, int]
) -> DAFMesh:

    mesh.calc_loop_triangles()

    uv_layer = None
    if mesh.uv_layers.active:
        uv_layer = mesh.uv_layers.active.data

    vertices: List[Tuple[float, float, float]] = []
    normals: List[Tuple[float, float, float]] = []
    texcoords: List[Tuple[float, float]] = []

    triangles: List[Tuple[int, int, int]] = []
    face_materials: List[int] = []

    # Maps canonical vertex key -> final vertex index
    vertex_map = {}

    def make_vertex_key(pos, normal, uv):
        # Quantize slightly to avoid floating point hash noise
        return (
            round(pos[0], 6),
            round(pos[1], 6),
            round(pos[2], 6),

            round(normal[0], 6),
            round(normal[1], 6),
            round(normal[2], 6),

            round(uv[0], 6),
            round(uv[1], 6),
        )

    for loop_tri in mesh.loop_triangles:
        tri_indices = []
        for loop_index in loop_tri.loops:
            loop = mesh.loops[loop_index]
            vertex = mesh.vertices[loop.vertex_index]

            # Position
            pos = _transform_position((
                vertex.co.x,
                vertex.co.y,
                vertex.co.z
            ))

            # Normal (IMPORTANT: per-loop normal!)
            normal = _transform_vector((
                loop.normal.x,
                loop.normal.y,
                loop.normal.z
            ))

            # UV
            if uv_layer is not None:
                uv = uv_layer[loop_index].uv
                texcoord = (uv.x, 1.0 - uv.y)
            else:
                texcoord = (0.0, 0.0)

            key = make_vertex_key(pos, normal, texcoord)

            if key in vertex_map:
                vertex_index = vertex_map[key]
            else:
                vertex_index = len(vertices)
                vertex_map[key] = vertex_index
                vertices.append(pos)
                normals.append(normal)
                texcoords.append(texcoord)

            tri_indices.append(vertex_index)

        triangles.append((
            tri_indices[0],
            tri_indices[1],
            tri_indices[2]
        ))

        local_material_index = mesh.polygons[loop_tri.polygon_index].material_index

        if local_material_index < len(obj.material_slots):
            blender_material = obj.material_slots[local_material_index].material
            if blender_material is not None:
                material_index = material_map[blender_material]
            else:
                material_index = -1
        else:
            material_index = -1

        face_materials.append(material_index)

    return DAFMesh(
        name=obj.name,
        vertices=vertices,
        normals=normals,
        texcoords=texcoords,
        triangles=triangles,
        classes=_get_object_classes(obj),
        flags=0,
        face_materials=face_materials,
    )

def _build_entity_from_object(index_map: dict[bpy.types.Object, int], obj: bpy.types.Object) -> DAFEntity:
    rotation = _transform_quaternion(_get_object_quaternion(obj))
    position = _transform_position((obj.location.x, obj.location.y, obj.location.z))
    scale = _transform_scale((obj.scale.x, obj.scale.y, obj.scale.z))
    parent_index = -1
    if obj.parent in index_map:
        parent_index = index_map[obj.parent]

    return DAFEntity(
        name=obj.name,
        class_names=_get_object_classes(obj),
        flags=0,
        parent=parent_index,
        position=position,
        rotation=(rotation.x, rotation.y, rotation.z, rotation.w),
        scale=scale,
        mesh=index_map[obj],
        pose_table=-1,
        user_data=[],
    )

def _find_principled_bsdf(material: bpy.types.Material):
    if not material.use_nodes:
        return None

    for node in material.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            return node

    return None

def linear_to_gamma22(rgba_tuple):
    r, g, b, a = rgba_tuple
    r_gamma = max(0.0, r) ** (1.0 / 2.2)
    g_gamma = max(0.0, g) ** (1.0 / 2.2)
    b_gamma = max(0.0, b) ** (1.0 / 2.2)
    return (r_gamma, g_gamma, b_gamma, a)

def _find_image_texture_node(socket):
    if socket is None or not socket.is_linked:
        return None

    for link in socket.links:
        node = link.from_node

        if node.type == 'TEX_IMAGE':
            return node

        # Normal Map node passthrough
        if node.type == 'NORMAL_MAP':
            return _find_image_texture_node(node.inputs.get("Color"))

        # Separate RGB / reroutes / etc
        for input_socket in node.inputs:
            tex = _find_image_texture_node(input_socket)
            if tex:
                return tex

    return None

def _get_image_from_socket(socket):
    tex_node = _find_image_texture_node(socket)

    if tex_node is None:
        return None

    return tex_node.image

def _resolve_image_source(image):
    """
    Returns:
    - filepath (is image source is external)
    - None (if image is packed/generated)
    """
    if image is None:
        return None

    if image.source == 'FILE' and image.filepath:
        path = bpy.path.abspath(image.filepath)
        if Path(path).exists():
            return path

    return None

def _image_key(image):
    if image.packed_file:
        return f"packed:{image.name}:{image.size[0]}x{image.size[1]}"
    src = _resolve_image_source(image)
    if src:
        return f"file:{src}"
    return f"generated:{image.name}"

def _get_texture_index(texture_map, asset, image, semantic, export_dir):
    if image is None:
        return -1

    key = (_image_key(image), semantic)

    if key in texture_map:
        return texture_map[key]

    export_path = _save_image(image, export_dir)

    texture = DAFTexture(
        filename=Path(export_path).name,
        semantic=semantic,
    )

    index = len(asset.textures)
    asset.add_texture(texture)
    texture_map[key] = index
    return index

def _make_packed_texture_filename(material_name, roughness_image, metallic_image):
    roughness_name = (roughness_image.name if roughness_image else "constR")
    metallic_name = (metallic_image.name if metallic_image else "constM")
    source = f"{material_name}_{roughness_name}_{metallic_name}"
    digest = hashlib.md5(
        source.encode("utf-8")
    ).hexdigest()[:8]
    safe_name = material_name.replace(" ", "_")
    return f"{safe_name}_rm_{digest}.png"

def _build_packed_roughness_metallic_texture(
    material,
    roughness_image,
    roughness_constant,
    metallic_image,
    metallic_constant,
    export_dir
):
    # Determine final texture size
    if roughness_image is not None:
        width = roughness_image.size[0]
        height = roughness_image.size[1]
    elif metallic_image is not None:
        width = metallic_image.size[0]
        height = metallic_image.size[1]
    else:
        width = 1
        height = 1

    # Read source pixels or synthesize constant textures
    if roughness_image is not None:
        roughness_pixels = list(roughness_image.pixels)
    else:
        roughness_pixels = []
        for _ in range(width * height):
            roughness_pixels.extend([
                roughness_constant,
                roughness_constant,
                roughness_constant,
                1.0
            ])

    if metallic_image is not None:
        metallic_pixels = list(metallic_image.pixels)
    else:
        metallic_pixels = []
        for _ in range(width * height):
            metallic_pixels.extend([
                metallic_constant,
                metallic_constant,
                metallic_constant,
                1.0
            ])

    packed = []

    for i in range(0, len(roughness_pixels), 4):
        roughness = roughness_pixels[i]
        metallic = metallic_pixels[i]
        packed.extend([1.0, roughness, metallic, 1.0])

    filename = _make_packed_texture_filename(material.name, roughness_image, metallic_image)
    
    existing_image = bpy.data.images.get(filename)
    if existing_image:
        return existing_image

    filepath = Path(export_dir) / filename

    if filepath.exists():
        return bpy.data.images.load(str(filepath))

    image = bpy.data.images.new(
        filename,
        width=width,
        height=height,
        alpha=True
    )
    image.pixels = packed
    #image.filepath_raw = str(filepath)
    #image.file_format = 'PNG'
    #image.save()
    return image

def _save_image(image, export_dir):
    export_dir = Path(export_dir)
    export_dir.mkdir(parents=True, exist_ok=True)
    name = Path(image.name).stem
    ext = "png"
    filename = f"{name}.{ext}"
    filepath = export_dir / filename
    if filepath.exists():
        return filepath

    # CASE 1: image already has real file path
    if image.source == 'FILE' and image.filepath:
        src_path = Path(bpy.path.abspath(image.filepath))
        if src_path.exists():
            filepath.write_bytes(src_path.read_bytes())
            return filepath

    # CASE 2: packed image
    if image.packed_file:
        image.filepath_raw = str(filepath)
        image.file_format = ext.upper()
        image.save()
        return filepath

    # CASE 3: generated / render / missing file
    image.filepath_raw = str(filepath)
    image.file_format = ext.upper()
    image.save()

    return filepath

def _get_normal_texture_from_principled(principled):
    normal_input = principled.inputs["Normal"]
    if not normal_input.is_linked:
        return None
    
    link = normal_input.links[0]
    node = link.from_node

    # CASE 1: Normal Map node
    if node.type == 'NORMAL_MAP':
        tex_input = node.inputs["Color"]
        return _get_image_from_socket(tex_input)

    # CASE 2: Bump node
    #if node.type == 'BUMP':
    #    tex_input = node.inputs["Height"]
    #    return _get_image_from_socket(tex_input)

    return None

def _build_material_from_blender_material(material: bpy.types.Material, asset, texture_map, export_dir) -> DAFMaterial:
    base_color = (1.0, 1.0, 1.0, 1.0)
    base_color_texture = -1
    normal_texture = -1
    height_texture = -1
    roughness = 0.5
    metallic = 0.0
    roughness_metallic_texture = -1
    emission_color = (0.0, 0.0, 0.0, 1.0)
    emission_texture = -1
    emission_energy = 0.0
    opacity = 1.0
    alpha_clip = 0.5
    blend_mode = BlendMode.Opaque
    principled = _find_principled_bsdf(material)
    
    if principled is not None:
        base_color_input = principled.inputs["Base Color"]
        base_color_image = _get_image_from_socket(base_color_input)
        if base_color_image:
            base_color_texture = _get_texture_index(texture_map, asset, base_color_image, DAFTextureSemantic.BaseColor, export_dir)
        else:
            base_color = linear_to_gamma22(tuple(base_color_input.default_value))
        
        normal_image = _get_normal_texture_from_principled(principled)
        if normal_image is not None:
            normal_texture = _get_texture_index(texture_map, asset, normal_image, DAFTextureSemantic.Normal, export_dir)
        
        roughness_input = principled.inputs["Roughness"]
        roughness_image = _get_image_from_socket(roughness_input)
        if roughness_image is None:
            roughness = roughness_input.default_value
        
        metallic_input = principled.inputs["Metallic"]
        metallic_image = _get_image_from_socket(metallic_input)
        if metallic_image is None:
            metallic = metallic_input.default_value
        
        if roughness_image is not None or metallic_image is not None:
            roughness_metallic_image = _build_packed_roughness_metallic_texture(material, roughness_image, roughness, metallic_image, metallic, export_dir)
            roughness_metallic_texture = _get_texture_index(texture_map, asset, roughness_metallic_image, DAFTextureSemantic.RoughnessMetallic, export_dir)
        
        emission_input = principled.inputs["Emission Color"]
        emission_image = _get_image_from_socket(emission_input)
        if emission_image:
            emission_texture = _get_texture_index(texture_map, asset, emission_image, DAFTextureSemantic.Emission, export_dir)
            emission_color = (1.0, 1.0, 1.0, 1.0)
        else:
            emission_color = linear_to_gamma22(tuple(emission_input.default_value))
        
        emission_energy = principled.inputs["Emission Strength"].default_value
        opacity = principled.inputs["Alpha"].default_value

    if material.blend_method in {'BLEND', 'HASHED'}:
        blend_mode = BlendMode.Transparent

    return DAFMaterial(
        name=material.name,
        baseColor=base_color,
        roughness=roughness,
        metallic=metallic,
        emissionColor=emission_color,
        emissionEnergy=emission_energy,
        opacity=opacity,
        alphaClipThreshold=alpha_clip,
        blendMode=int(blend_mode),
        baseColorTexture=base_color_texture,
        normalTexture=normal_texture,
        heightTexture=height_texture,
        roughnessMetallicTexture=roughness_metallic_texture,
        emissionTexture=emission_texture
    )

class EXPORT_SCENE_OT_dagon_daf(Operator, ExportHelper):
    bl_idname = "export_scene.dagon_daf"
    bl_label = "Export DAF"
    bl_options = {'REGISTER', 'UNDO'}

    filename_ext: StringProperty(
        default=".daf",
        options={'HIDDEN'},
    )

    filter_glob: StringProperty(
        default="*.daf",
        options={'HIDDEN'},
    )

    export_selected_only: BoolProperty(
        name="Selected Objects",
        description="Export only selected mesh objects",
        default=False,
    )

    def execute(self, context):
        export_dir = Path(self.filepath).parent
        objects = context.selected_objects if self.export_selected_only else context.scene.objects
        mesh_objects = [obj for obj in objects if obj.type == 'MESH']
        material_map: dict[bpy.types.Material, int] = {}
        texture_map = {}

        if not mesh_objects:
            self.report({'WARNING'}, "No mesh objects found to export.")
            return {'CANCELLED'}

        used_materials = []
        for obj in mesh_objects:
            for slot in obj.material_slots:
                material = slot.material
                if material is None:
                    continue
                if material not in material_map:
                    material_index = len(used_materials)
                    material_map[material] = material_index
                    used_materials.append(material)

        try:
            asset = DAFAsset()
            depsgraph = context.evaluated_depsgraph_get()

            for obj in mesh_objects:
                obj_eval = obj.evaluated_get(depsgraph)
                mesh = obj_eval.to_mesh()
                if mesh is None:
                    continue
                asset.add_mesh(_build_mesh_from_object(obj, mesh, material_map))
                obj_eval.to_mesh_clear()

            index_map = {obj: i for i, obj in enumerate(mesh_objects)}
            for obj in mesh_objects:
                asset.add_entity(_build_entity_from_object(index_map, obj))

            for material in used_materials:
                asset.add_material(_build_material_from_blender_material(material, asset, texture_map, export_dir))

            asset.write(self.filepath)
            self.report({'INFO'}, f"Export complete: {self.filepath}")
            return {'FINISHED'}

        except Exception as exc:
            self.report({'ERROR'}, f"DAF export failed: {exc}")
            import traceback
            traceback.print_exc()
            return {'CANCELLED'}


def menu_func_export(self, context):
    self.layout.operator(EXPORT_SCENE_OT_dagon_daf.bl_idname, text="Dagon 2.0 Asset (.daf)")


def register():
    bpy.utils.register_class(EXPORT_SCENE_OT_dagon_daf)
    bpy.types.TOPBAR_MT_file_export.append(menu_func_export)


def unregister():
    bpy.utils.unregister_class(EXPORT_SCENE_OT_dagon_daf)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)
