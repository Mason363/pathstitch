//! C FFI over Formlabs/foxtrot: parse a STEP file and tessellate its B-rep into a
//! triangle mesh that the Pathstitch QuickLook extensions render (MAS-157).
//!
//! Returns interleaved vertex data (position xyz + normal xyz, 6 f32 per vertex)
//! plus a u32 index buffer. All work is wrapped in `catch_unwind` so a malformed
//! file can never crash the host preview process — it just yields a null result
//! and the Swift side falls back to its lightweight renderer.

use std::ffi::CStr;
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};

/// Owns the backing buffers so they stay alive until `step_mesh_free`.
struct MeshOwner {
    verts: Vec<f32>,
    indices: Vec<u32>,
}

/// Plain-old-data view handed to C. Pointers are valid until `step_mesh_free`.
#[repr(C)]
pub struct CMesh {
    /// Interleaved [px, py, pz, nx, ny, nz] — `vertex_count * 6` floats.
    verts: *const f32,
    vertex_count: usize,
    /// Triangle indices into the vertex array — `index_count` u32 (3 per tri).
    indices: *const u32,
    index_count: usize,
    owner: *mut MeshOwner,
}

/// Tessellate the STEP file at `path`. Returns null on any failure (bad path,
/// parse error, panic) or when the model produced no triangles (e.g. a fully
/// closed primitive surface foxtrot can't flatten). Free with `step_mesh_free`.
#[no_mangle]
pub extern "C" fn step_mesh_load(path: *const c_char) -> *mut CMesh {
    if path.is_null() {
        return std::ptr::null_mut();
    }
    let path = match unsafe { CStr::from_ptr(path) }.to_str() {
        Ok(s) => s.to_owned(),
        Err(_) => return std::ptr::null_mut(),
    };

    let result = catch_unwind(AssertUnwindSafe(|| build_mesh(&path)));
    match result {
        Ok(Some(boxed)) => Box::into_raw(boxed),
        _ => std::ptr::null_mut(),
    }
}

fn build_mesh(path: &str) -> Option<Box<CMesh>> {
    use step::step_file::StepFile;
    use triangulate::triangulate::triangulate;

    let data = std::fs::read(path).ok()?;
    let flat = StepFile::strip_flatten(&data);
    let step = StepFile::parse(&flat);
    let (mesh, _stats) = triangulate(&step);

    if mesh.triangles.is_empty() || mesh.verts.is_empty() {
        return None;
    }

    let mut verts: Vec<f32> = Vec::with_capacity(mesh.verts.len() * 6);
    for v in &mesh.verts {
        verts.push(v.pos.x as f32);
        verts.push(v.pos.y as f32);
        verts.push(v.pos.z as f32);
        verts.push(v.norm.x as f32);
        verts.push(v.norm.y as f32);
        verts.push(v.norm.z as f32);
    }
    let mut indices: Vec<u32> = Vec::with_capacity(mesh.triangles.len() * 3);
    for t in &mesh.triangles {
        indices.push(t.verts[0]);
        indices.push(t.verts[1]);
        indices.push(t.verts[2]);
    }

    let owner = Box::new(MeshOwner { verts, indices });
    let cmesh = CMesh {
        verts: owner.verts.as_ptr(),
        vertex_count: owner.verts.len() / 6,
        indices: owner.indices.as_ptr(),
        index_count: owner.indices.len(),
        owner: Box::into_raw(owner) as *mut MeshOwner,
    };
    // Re-wrap the owner pointer back so it isn't double-managed: we stored it raw
    // above, and the CMesh now carries it for `step_mesh_free` to reclaim.
    Some(Box::new(cmesh))
}

/// Releases a mesh returned by `step_mesh_load`. Null-safe.
#[no_mangle]
pub extern "C" fn step_mesh_free(mesh: *mut CMesh) {
    if mesh.is_null() {
        return;
    }
    unsafe {
        let cmesh = Box::from_raw(mesh);
        if !cmesh.owner.is_null() {
            drop(Box::from_raw(cmesh.owner));
        }
    }
}
