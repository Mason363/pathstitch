#ifndef STEP_MESH_H
#define STEP_MESH_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Triangle mesh tessellated from a STEP file by foxtrot. Pointers stay valid
/// until step_mesh_free(). `verts` is interleaved position+normal: 6 floats per
/// vertex (px,py,pz,nx,ny,nz). `indices` holds index_count u32 (3 per triangle).
typedef struct CMesh {
    const float *verts;
    size_t vertex_count;
    const uint32_t *indices;
    size_t index_count;
    void *owner;
} CMesh;

/// Tessellate the STEP file at `path`. Returns NULL on failure / empty mesh.
CMesh *step_mesh_load(const char *path);

/// Free a mesh returned by step_mesh_load. NULL-safe.
void step_mesh_free(CMesh *mesh);

#ifdef __cplusplus
}
#endif

#endif /* STEP_MESH_H */
