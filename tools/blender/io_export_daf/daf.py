import enum
import json
import struct
from dataclasses import dataclass, field
from typing import Any, Iterable, List, Optional, Sequence, Tuple

ALIGNMENT = 4
DAF_MAGIC = b"DAF\0"
DAF_FORMAT_VERSION = 100
DAF_MESH_FLAG_ANIMATED = 0x01

DAF_TEXTURE_FLAG_GENERATE_MIPMAPS = 0x01
DAF_TEXTURE_FLAG_UV_REPEAT = 0x02
DAF_TEXTURE_FLAG_ANISOTROPIC_FILTERING = 0x04

def align(value: int, alignment: int = ALIGNMENT) -> int:
    return (value + alignment - 1) // alignment * alignment


def align_bytes(data: bytes, alignment: int = ALIGNMENT) -> bytes:
    pad = align(len(data), alignment) - len(data)
    return data + (b"\0" * pad)


class DAFChunkType(enum.IntEnum):
    Entities = 0
    Meshes = 1
    Materials = 2
    Textures = 3
    Skeletons = 4
    Poses = 5
    PoseTables = 6


class BlendMode(enum.IntEnum):
    Opaque = 0
    Transparent = 1


class DAFTextureSemantic(enum.IntEnum):
    Unspecified = 0
    BaseColor = 1
    Normal = 2
    Height = 3
    RoughnessMetallic = 4
    Emission = 5


class DAFTextureFilter(enum.IntEnum):
    Nearest = 0
    Linear = 1


class DPropType(enum.IntEnum):
    Undefined = 0
    Number = 1
    Vector = 2
    String = 3


@dataclass
class DAFUserDataEntry:
    name: str
    value: Any
    prop_type: Optional[DPropType] = None

    def resolved_type(self) -> DPropType:
        if self.prop_type is not None:
            return self.prop_type

        if isinstance(self.value, str):
            return DPropType.String
        if isinstance(self.value, bool) or isinstance(self.value, (int, float)):
            return DPropType.Number
        if isinstance(self.value, (list, tuple)):
            return DPropType.Vector
        raise TypeError(f"Unsupported user data type: {type(self.value)}")

    def formatted_value(self) -> str:
        if isinstance(self.value, str):
            return json.dumps(self.value)
        if isinstance(self.value, bool):
            return "true" if self.value else "false"
        if isinstance(self.value, (int, float)):
            return repr(self.value)
        if isinstance(self.value, (list, tuple)):
            values = ", ".join(repr(float(x)) for x in self.value)
            return f"[{values}]"
        raise TypeError(f"Unsupported user data type: {type(self.value)}")


@dataclass
class DAFEntity:
    name: str
    class_names: Sequence[str] = field(default_factory=list)
    flags: int = 0
    parent: int = -1
    position: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    rotation: Tuple[float, float, float, float] = (0.0, 0.0, 0.0, 1.0)
    scale: Tuple[float, float, float] = (1.0, 1.0, 1.0)
    mesh: int = -1
    pose_table: int = -1
    user_data: Sequence[DAFUserDataEntry] = field(default_factory=list)


@dataclass
class DAFMaterial:
    name: str
    class_names: Sequence[str] = field(default_factory=list)
    flags: int = 0
    baseColor: Tuple[float, float, float, float] = (0.0, 0.0, 0.0, 1.0)
    roughness: float = 0.5
    metallic: float = 0.0
    emissionColor: Tuple[float, float, float, float] = (0.0, 0.0, 0.0, 1.0)
    emissionEnergy: float = 0.0
    ior: float = 1.5
    iorLevel: float = 0.5
    subsurfaceScattering: float = 0.0
    opacity: float = 1.0
    alphaClipThreshold: float = 0.5
    shadeless: int = 0
    blendMode: int = 0
    baseColorTexture: int = -1
    normalTexture: int = -1
    heightTexture: int = -1
    roughnessMetallicTexture: int = -1
    emissionTexture: int = -1
    user_data: Sequence[DAFUserDataEntry] = field(default_factory=list)


@dataclass
class DAFTexture:
    filename: str
    class_names: Sequence[str] = field(default_factory=list)
    flags: int = (
        DAF_TEXTURE_FLAG_GENERATE_MIPMAPS |
        DAF_TEXTURE_FLAG_UV_REPEAT |
        DAF_TEXTURE_FLAG_ANISOTROPIC_FILTERING
    )
    minFilter: int = DAFTextureFilter.Linear
    magFilter: int = DAFTextureFilter.Linear
    mipmapMode: int = DAFTextureFilter.Linear
    semantic: int = 0
    user_data: Sequence[DAFUserDataEntry] = field(default_factory=list)


@dataclass
class DAFMesh:
    name: str
    vertices: Sequence[Tuple[float, float, float]]
    normals: Sequence[Tuple[float, float, float]]
    texcoords: Sequence[Tuple[float, float]]
    triangles: Sequence[Tuple[int, int, int]]
    classes: Sequence[str] = field(default_factory=list)
    flags: int = 0
    bone_indices: Optional[Sequence[Tuple[int, int, int, int]]] = None
    bone_weights: Optional[Sequence[Tuple[float, float, float, float]]] = None
    face_materials: Optional[Sequence[int]] = None
    user_data: Sequence[DAFUserDataEntry] = field(default_factory=list)

    def __post_init__(self):
        if self.face_materials is None:
            self.face_materials = [-1] * len(self.triangles)
        if len(self.face_materials) != len(self.triangles):
            raise ValueError("face_materials length must match triangle count")


@dataclass
class DAFFaceGroup:
    material: int
    first_triangle: int
    num_triangles: int


class DAFStringTable:
    def __init__(self) -> None:
        self._index: dict[str, int] = {}
        self._data = bytearray(b"\0")

    def add(self, text: Optional[str]) -> Tuple[int, int]:
        if not text:
            return 0, 0

        if text in self._index:
            offset = self._index[text]
            size = len(text.encode("utf-8"))
            return offset, size

        offset = len(self._data)
        encoded = text.encode("utf-8")
        self._data.extend(encoded)
        self._data.append(0)
        self._index[text] = offset
        return offset, len(encoded)

    def build(self) -> bytes:
        return align_bytes(bytes(self._data))


class DAFBufferSection:
    def __init__(self) -> None:
        self._data = bytearray()

    def add(self, data: bytes, alignment: int = ALIGNMENT) -> int:
        offset = align(len(self._data), alignment)
        if offset != len(self._data):
            self._data.extend(b"\0" * (offset - len(self._data)))
        self._data.extend(data)
        pad = align(len(self._data), alignment) - len(self._data)
        if pad:
            self._data.extend(b"\0" * pad)
        return offset

    def build(self) -> bytes:
        return bytes(self._data)


class DAFAsset:
    def __init__(self) -> None:
        self.entities: List[DAFEntity] = []
        self.meshes: List[DAFMesh] = []
        self.materials: List[DAFMaterial] = []
        self.textures: List[DAFTexture] = []
        self.skeletons: List[Any] = []
        self.poses: List[Any] = []
        self.pose_tables: List[Any] = []

    def add_entity(self, entity: DAFEntity) -> None:
        self.entities.append(entity)

    def add_mesh(self, mesh: DAFMesh) -> None:
        self.meshes.append(mesh)

    def add_material(self, material: DAFMaterial) -> None:
        self.materials.append(material)

    def add_texture(self, texture: DAFTexture) -> None:
        self.textures.append(texture)

    def _pack_daf_string(self, text: Optional[str], string_table: DAFStringTable) -> Tuple[int, int]:
        return string_table.add(text)

    def _pack_daf_user_data(self, entries: Sequence[DAFUserDataEntry], string_table: DAFStringTable, buffers: DAFBufferSection) -> Tuple[int, int]:
        if not entries:
            return 0, 0

        data = bytearray()
        for entry in entries:
            name_offset, name_size = self._pack_daf_string(entry.name, string_table)
            value_text = entry.formatted_value()
            value_offset, value_size = self._pack_daf_string(value_text, string_table)
            data.extend(struct.pack("<IIIII", entry.resolved_type(), name_offset, name_size, value_offset, value_size))

        return buffers.add(bytes(data)), len(data)

    def _pack_string_array_buffer(self, strings: Sequence[str], string_table: DAFStringTable, buffers: DAFBufferSection) -> Tuple[int, int]:
        if not strings:
            return 0, 0

        data = bytearray()
        for text in strings:
            offset, size = self._pack_daf_string(text, string_table)
            data.extend(struct.pack("<II", offset, size))
        # Return offset and number of entries
        return buffers.add(bytes(data)), len(strings)

    def _pack_entity(self, entity: DAFEntity, string_table: DAFStringTable, buffers: DAFBufferSection) -> bytes:
        name_offset, name_size = self._pack_daf_string(entity.name, string_table)
        class_offset, num_classes = self._pack_string_array_buffer(entity.class_names, string_table, buffers)
        user_data_offset, user_data_size = self._pack_daf_user_data(entity.user_data, string_table, buffers)

        return struct.pack(
            "<IIIIIi3f4f3fiiII",
            name_offset,
            name_size,
            class_offset,
            num_classes,
            entity.flags,
            entity.parent,
            *entity.position,
            *entity.rotation,
            *entity.scale,
            entity.mesh,
            entity.pose_table,
            user_data_offset,
            user_data_size,
        )

    def _pack_mesh(self, mesh: DAFMesh, string_table: DAFStringTable, buffers: DAFBufferSection) -> bytes:
        name_offset, name_size = self._pack_daf_string(mesh.name, string_table)
        class_offset, num_classes = self._pack_string_array_buffer(mesh.classes, string_table, buffers)

        vertex_data = struct.pack(f"<{len(mesh.vertices) * 3}f", *[coord for vertex in mesh.vertices for coord in vertex])
        vertex_offset = buffers.add(vertex_data) if mesh.vertices else 0

        normal_data = struct.pack(f"<{len(mesh.normals) * 3}f", *[coord for normal in mesh.normals for coord in normal]) if mesh.normals else b""
        normal_offset = buffers.add(normal_data) if mesh.normals else 0

        texcoord_data = struct.pack(f"<{len(mesh.texcoords) * 2}f", *[coord for tex in mesh.texcoords for coord in tex]) if mesh.texcoords else b""
        texcoord_offset = buffers.add(texcoord_data) if mesh.texcoords else 0

        if mesh.flags & DAF_MESH_FLAG_ANIMATED:
            if mesh.bone_indices is None or mesh.bone_weights is None:
                raise ValueError("Animated mesh must provide bone_indices and bone_weights")
            bones_data = struct.pack(
                f"<{len(mesh.bone_indices) * 4}I",
                *[index for bone in mesh.bone_indices for index in bone],
            )
            bone_weights_data = struct.pack(
                f"<{len(mesh.bone_weights) * 4}f",
                *[weight for weights in mesh.bone_weights for weight in weights],
            )
            bone_offset = buffers.add(bones_data)
            bone_weights_offset = buffers.add(bone_weights_data)
        else:
            bone_offset = 0
            bone_weights_offset = 0

        face_groups: List[DAFFaceGroup] = []
        group_dict: dict[int, List[Tuple[int, int, int]]] = {}
        for triangle, material in zip(mesh.triangles, mesh.face_materials):
            group_dict.setdefault(material, []).append(triangle)

        # Build continuous index buffer
        all_indices: List[int] = []
        for material in sorted(group_dict.keys()):  # Sort for consistent ordering
            triangles_in_group = group_dict[material]
            first_triangle = len(all_indices) // 3
            for triangle in triangles_in_group:
                all_indices.extend(triangle)
            num_triangles = len(triangles_in_group)
            face_groups.append(DAFFaceGroup(material, first_triangle, num_triangles))

        indices_data = struct.pack(f"<{len(all_indices)}I", *all_indices)
        indices_offset = buffers.add(indices_data) if all_indices else 0
        num_triangles = len(mesh.triangles)

        # Pack face groups
        face_group_offset = 0
        face_group_count = 0
        if face_groups:
            face_group_bytes = bytearray()
            for group in face_groups:
                face_group_bytes.extend(struct.pack("<iII", group.material, group.first_triangle, group.num_triangles))
            face_group_offset = buffers.add(bytes(face_group_bytes))
            face_group_count = len(face_groups)

        user_data_offset, user_data_size = self._pack_daf_user_data(mesh.user_data, string_table, buffers)

        return struct.pack(
            "<17I",
            name_offset,
            name_size,
            class_offset,
            num_classes,
            mesh.flags,
            vertex_offset,
            normal_offset,
            texcoord_offset,
            bone_offset,
            bone_weights_offset,
            len(mesh.vertices),
            indices_offset,
            num_triangles,
            face_group_offset,
            face_group_count,
            user_data_offset,
            user_data_size,
        )

    def _pack_texture(self, texture: DAFTexture, string_table: DAFStringTable, buffers: DAFBufferSection) -> bytes:
        filename_offset, filename_size = self._pack_daf_string(texture.filename, string_table)
        class_offset, num_classes = self._pack_string_array_buffer(texture.class_names, string_table, buffers)
        user_data_offset, user_data_size = self._pack_daf_user_data(texture.user_data, string_table, buffers)
        
        return struct.pack(
            "<IIIIIIIIIII",
            filename_offset,
            filename_size,
            class_offset,
            num_classes,
            texture.flags,
            texture.minFilter,
            texture.magFilter,
            texture.mipmapMode,
            texture.semantic,
            user_data_offset,
            user_data_size,
        )

    def _pack_material(self, material: DAFMaterial, string_table: DAFStringTable, buffers: DAFBufferSection) -> bytes:
        name_offset, name_size = self._pack_daf_string(material.name, string_table)
        class_offset, num_classes = self._pack_string_array_buffer(material.class_names, string_table, buffers)
        user_data_offset, user_data_size = self._pack_daf_user_data(material.user_data, string_table, buffers)

        return struct.pack(
            "<IIIII4fff4fffffffIIiiiiiII",
            name_offset,
            name_size,
            class_offset,
            num_classes,
            material.flags,
            *material.baseColor,
            material.roughness,
            material.metallic,
            *material.emissionColor,
            material.emissionEnergy,
            material.ior,
            material.iorLevel,
            material.subsurfaceScattering,
            material.opacity,
            material.alphaClipThreshold,
            material.shadeless,
            material.blendMode,
            material.baseColorTexture,
            material.normalTexture,
            material.heightTexture,
            material.roughnessMetallicTexture,
            material.emissionTexture,
            user_data_offset,
            user_data_size,
        )

    def _pack_chunk_table_entry(self, chunk_type: DAFChunkType, offset: int, count: int, stride: int) -> bytes:
        return struct.pack("<IIII", int(chunk_type), offset, count, stride)

    def to_bytes(self) -> bytes:
        string_table = DAFStringTable()
        buffers = DAFBufferSection()

        chunk_entries: List[Tuple[DAFChunkType, bytes, int]] = []

        if self.entities:
            entity_bytes = b"".join(self._pack_entity(entity, string_table, buffers) for entity in self.entities)
            entity_bytes = align_bytes(entity_bytes)
            chunk_entries.append((DAFChunkType.Entities, entity_bytes, 80))

        if self.meshes:
            mesh_bytes = b"".join(self._pack_mesh(mesh, string_table, buffers) for mesh in self.meshes)
            mesh_bytes = align_bytes(mesh_bytes)
            chunk_entries.append((DAFChunkType.Meshes, mesh_bytes, 68))

        if self.textures:
            texture_bytes = b"".join(self._pack_texture(texture, string_table, buffers) for texture in self.textures)
            texture_bytes = align_bytes(texture_bytes)
            chunk_entries.append((DAFChunkType.Textures, texture_bytes, 44))

        if self.materials:
            material_bytes = b"".join(self._pack_material(material, string_table, buffers) for material in self.materials)
            material_bytes = align_bytes(material_bytes)
            chunk_entries.append((DAFChunkType.Materials, material_bytes, 120))

        chunk_table_offset = align(40)
        chunk_table_bytes = bytearray()
        chunk_data_bytes = bytearray()
        current_offset = chunk_table_offset + len(chunk_entries) * 16
        current_offset = align(current_offset)

        for chunk_type, chunk_data, stride in chunk_entries:
            chunk_offset = current_offset
            chunk_table_bytes.extend(self._pack_chunk_table_entry(chunk_type, chunk_offset, len(chunk_data) // stride, stride))
            chunk_data_bytes.extend(chunk_data)
            current_offset += len(chunk_data)

        string_table_offset = align(chunk_table_offset + len(chunk_table_bytes) + len(chunk_data_bytes))
        string_table_bytes = string_table.build()

        buffers_offset = align(string_table_offset + len(string_table_bytes))
        buffers_bytes = buffers.build()

        file_size = buffers_offset + len(buffers_bytes)

        header = struct.pack(
            "<4sIIIIIIIII",
            DAF_MAGIC,
            DAF_FORMAT_VERSION,
            0,
            file_size,
            chunk_table_offset,
            len(chunk_entries),
            string_table_offset,
            len(string_table_bytes),
            buffers_offset,
            len(buffers_bytes),
        )

        return b"".join([
            header,
            chunk_table_bytes,
            chunk_data_bytes,
            b"\0" * (string_table_offset - (len(header) + len(chunk_table_bytes) + len(chunk_data_bytes))),
            string_table_bytes,
            b"\0" * (buffers_offset - (string_table_offset + len(string_table_bytes))),
            buffers_bytes,
        ])

    def write(self, path: str) -> None:
        with open(path, "wb") as handle:
            handle.write(self.to_bytes())


# Convenience helpers for exporter usage

def build_mesh(
    name: str,
    vertices: Sequence[Tuple[float, float, float]],
    triangles: Sequence[Tuple[int, int, int]],
    normals: Optional[Sequence[Tuple[float, float, float]]] = None,
    texcoords: Optional[Sequence[Tuple[float, float]]] = None,
    bone_indices: Optional[Sequence[Tuple[int, int, int, int]]] = None,
    bone_weights: Optional[Sequence[Tuple[float, float, float, float]]] = None,
    classes: Optional[Sequence[str]] = None,
    material_indices: Optional[Sequence[int]] = None,
    user_data: Optional[Sequence[DAFUserDataEntry]] = None,
) -> DAFMesh:
    return DAFMesh(
        name=name,
        vertices=vertices,
        normals=normals or [],
        texcoords=texcoords or [],
        triangles=triangles,
        classes=classes or [],
        flags=DAF_MESH_FLAG_ANIMATED if bone_indices or bone_weights else 0,
        bone_indices=bone_indices,
        bone_weights=bone_weights,
        face_materials=material_indices or [-1] * len(triangles),
        user_data=user_data or [],
    )


def build_entity(
    name: str,
    mesh_index: int = -1,
    parent_index: int = -1,
    position: Tuple[float, float, float] = (0.0, 0.0, 0.0),
    rotation: Tuple[float, float, float, float] = (0.0, 0.0, 0.0, 1.0),
    scale: Tuple[float, float, float] = (1.0, 1.0, 1.0),
    class_names: Optional[Sequence[str]] = None,
    pose_table: int = -1,
    flags: int = 0,
    user_data: Optional[Sequence[DAFUserDataEntry]] = None,
) -> DAFEntity:
    return DAFEntity(
        name=name,
        class_names=class_names or [],
        flags=flags,
        parent=parent_index,
        position=position,
        rotation=rotation,
        scale=scale,
        mesh=mesh_index,
        pose_table=pose_table,
        user_data=user_data or [],
    )


if __name__ == "__main__":
    # Example DAF asset construction
    asset = DAFAsset()
    mesh = build_mesh(
        "ExampleMesh",
        vertices=[(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)],
        triangles=[(0, 1, 2)],
        normals=[(0.0, 0.0, 1.0)] * 3,
        texcoords=[(0.0, 0.0), (1.0, 0.0), (0.0, 1.0)],
    )
    asset.add_mesh(mesh)
    asset.add_entity(build_entity("RootEntity", mesh_index=0))
    asset.write("example.daf")
    print("Wrote example.daf")
