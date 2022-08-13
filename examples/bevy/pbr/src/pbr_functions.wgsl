#[env(VERTEX_TANGENTS: bool, "Toggles the usage ofvertex tangents")]
#[env(STANDARDMATERIAL_NORMAL_MAP: bool, "Toggles the usage of normal maps")]
#[env(VERTEX_UVS: bool, "Toggles the usage of vertex UVs")]
fn prepare_normal(
    standard_material_flags: u32,

    world_normal: vec3<f32>,

    #[cfg(VERTEX_TANGENTS), cfg(STANDARDMATERIAL_NORMAL_MAP)]
    world_tangent: vec4<f32>,

    #[cfg(VERTEX_UVS)]
    uv: vec2<f32>,

    is_front: bool,
) -> vec3<f32> {
    var N: vec3<f32> = normalize(world_normal);
    var T: vec3<f32>;
    var B: vec3<f32>;

    #[cfg(VERTEX_TANGENTS), cfg(STANDARDMATERIAL_NORMAL_MAP)]
    {
        // NOTE: The mikktspace method of normal mapping explicitly requires that these NOT be
        // normalized nor any Gram-Schmidt applied to ensure the vertex normal is orthogonal to the
        // vertex tangent! Do not change this code unless you really know what you are doing.
        // http://www.mikktspace.com/
        T = world_tangent.xyz;
        B = world_tangent.w * cross(N, T);
    }

    if ((standard_material_flags & STANDARD_MATERIAL_FLAGS_DOUBLE_SIDED_BIT) != 0u) {
        if (!is_front) {
            N = -N;
            #[cfg(VERTEX_TANGENTS), cfg(STANDARDMATERIAL_NORMAL_MAP)]
            {
                T = -T;
                B = -B;
            }
        }
    }

    #[cfg(VERTEX_TANGENTS), cfg(VERTEX_UVS), cfg(STANDARDMATERIAL_NORMAL_MAP)]
    {
        // Nt is the tangent-space normal.
        var Nt = textureSample(normal_map_texture, normal_map_sampler, uv).rgb;
        if ((standard_material_flags & STANDARD_MATERIAL_FLAGS_TWO_COMPONENT_NORMAL_MAP) != 0u) {
            // Only use the xy components and derive z for 2-component normal maps.
            Nt = vec3<f32>(Nt.rg * 2.0 - 1.0, 0.0);
            Nt.z = sqrt(1.0 - Nt.x * Nt.x - Nt.y * Nt.y);
        } else {
            Nt = Nt * 2.0 - 1.0;
        }
        // Normal maps authored for DirectX require flipping the y component
        if ((standard_material_flags & STANDARD_MATERIAL_FLAGS_FLIP_NORMAL_MAP_Y) != 0u) {
            Nt.y = -Nt.y;
        }
        // NOTE: The mikktspace method of normal mapping applies maps the tangent-space normal from
        // the normal map texture in this way to be an EXACT inverse of how the normal map baker
        // calculates the normal maps so there is no error introduced. Do not change this code
        // unless you really know what you are doing.
        // http://www.mikktspace.com/
        N = normalize(Nt.x * T + Nt.y * B + Nt.z * N);
    }

    return N;
}

export {
    prepare_normal, // Exports with VERTEX_TANGENTS, STANDARDMATERIAL_NORMAL_MAP and VERTEX_UVS dependencies
};
