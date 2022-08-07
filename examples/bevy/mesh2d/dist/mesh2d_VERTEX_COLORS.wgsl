struct View {
    view_proj: mat4x4<f32>,
    inverse_view_proj: mat4x4<f32>,
    view: mat4x4<f32>,
    inverse_view: mat4x4<f32>,
    projection: mat4x4<f32>,
    inverse_projection: mat4x4<f32>,
    world_position: vec3<f32>,
    width: f32,
    height: f32,
};

struct Mesh2d {
    model: mat4x4<f32>,
    inverse_transpose_model: mat4x4<f32>,
    // 'flags' is a bit field indicating various options. u32 is 32 bits so we have up to 32 options.
    flags: u32,
};

@group(0) @binding(0)
var<uniform> view: View;

@group(2) @binding(0)
var<uniform> mesh: Mesh2d;

fn mesh2d_position_local_to_world(model: mat4x4<f32>, vertex_position: vec4<f32>) -> vec4<f32> {
    return model * vertex_position;
}

fn mesh2d_position_world_to_clip(world_position: vec4<f32>) -> vec4<f32> {
    return view.view_proj * world_position;
}

fn mesh2d_normal_local_to_world(vertex_normal: vec3<f32>) -> vec3<f32> {
    return mat3x3<f32>(
        mesh.inverse_transpose_model[0].xyz,
        mesh.inverse_transpose_model[1].xyz,
        mesh.inverse_transpose_model[2].xyz
    ) * vertex_normal;
}

// @cfg(VERTEX_TANGENTS) false
// fn mesh2d_tangent_local_to_world(model: mat4x4<f32>, vertex_tangent: vec4<f32>) -> vec4<f32> {
//     return vec4<f32>(
//         mat3x3<f32>(
//             model[0].xyz,
//             model[1].xyz,
//             model[2].xyz
//         ) * vertex_tangent.xyz,
//         vertex_tangent.w
//     );
// }

struct Vertex {
    @location(0) position: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    // @cfg(VERTEX_TANGENTS) false
    // @location(3) tangent: vec4<f32>,
    // @cfg(VERTEX_COLORS) true
    @location(4) color: vec4<f32>,
};

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    // @cfg(VERTEX_TANGENTS) false
    // @location(3) world_tangent: vec4<f32>,
    // @cfg(VERTEX_COLORS) true
    @location(4) color: vec4<f32>,
}

@vertex
fn vertex(vertex: Vertex) -> VertexOutput {
    var out: VertexOutput;
    out.uv = vertex.uv;
    out.world_position = mesh2d_position_local_to_world(mesh.model, vec4<f32>(vertex.position, 1.0));
    out.clip_position = mesh2d_position_world_to_clip(out.world_position);
    out.world_normal = mesh2d_normal_local_to_world(vertex.normal);
    // @cfg(VERTEX_TANGENTS) false
    // out.world_tangent = mesh2d_tangent_local_to_world(vertex.tangent);
    // @cfg(VERTEX_COLORS) true
    out.color = vertex.color;
    return out;
}

struct FragmentInput {
    @builtin(front_facing) is_front: bool,
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    // @cfg(VERTEX_TANGENTS) false
    // @location(3) world_tangent: vec4<f32>,
    // @cfg(VERTEX_COLORS) true
    @location(4) color: vec4<f32>,
};

@fragment
fn fragment(in: FragmentInput) -> @location(0) vec4<f32> {
    return vec4<f32>(1.0, 0.0, 1.0, 1.0);
}
