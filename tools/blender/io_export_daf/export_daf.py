import sys
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple
from mathutils import Matrix, Quaternion

import bpy
from bpy_extras.io_utils import ExportHelper
from bpy.props import StringProperty, BoolProperty
from bpy.types import Operator
from mathutils import Quaternion

from .daf import DAFAsset, DAFEntity, DAFMesh

# Blender:
# X = right
# Y = forward
# Z = up
#
# Dagon:
# X = right
# Y = up
# Z = forward
#
# Conversion:
# (x, y, z) -> (x, z, -y)

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
    mesh: bpy.types.Mesh
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
                texcoord = (uv.x, uv.y)
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
            tri_indices[2],
            tri_indices[1]
        ))

        material_index = mesh.polygons[
            loop_tri.polygon_index
        ].material_index

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
        objects = context.selected_objects if self.export_selected_only else context.scene.objects
        mesh_objects = [obj for obj in objects if obj.type == 'MESH']

        if not mesh_objects:
            self.report({'WARNING'}, "No mesh objects found to export.")
            return {'CANCELLED'}

        try:
            asset = DAFAsset()
            depsgraph = context.evaluated_depsgraph_get()

            for obj in mesh_objects:
                obj_eval = obj.evaluated_get(depsgraph)
                mesh = obj_eval.to_mesh()
                if mesh is None:
                    continue
                asset.add_mesh(_build_mesh_from_object(obj, mesh))
                obj_eval.to_mesh_clear()

            index_map = {obj: i for i, obj in enumerate(mesh_objects)}
            for obj in mesh_objects:
                asset.add_entity(_build_entity_from_object(index_map, obj))

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
