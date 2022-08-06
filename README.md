# MWGSL

Meta/Macro/Modular WGSL. A superset of WGSL that introduces compile-time macros to help you build statically-analyzed DRY shader programs in WGSL.

*Note: This document is works in progress.*

*Note: this document uses Javascript syntax highlighting, which is of course, incorrect, but works bettert than no highlighing at all.*

## Propesed syntax additions

This section describes proposed macros, which are syntactical additions to WGSL.

### import

Brings named exports into the shader module.

```js
import { EXPORT_NAME } from "file/path.mwgsl";
import { EXPORT_NAME_1, EXPORT_NAME2_ } from "file/path.mwgsl";
```

### export

Indicates to other modules that listed exports can be imported.

```js
export { EXPORT_NAME };
```

### ...

Spread macro. The key building block of MWGSL. Inserts the value passed to the macro during compilation into the shader.

*Debate material: Should ... be implicit? Especially with if? macros*

*Bikesheding material: Can be replaced with <- and renamed to "insert" macro*

### void!

Represents nothing to spread. Only useful internally for if! macros.

```js
...void!;
```

```js
void! v = void!;

...v; // legal because it spreads nothing into the top level of the shader

struct FragmentInput {
    @builtin(front_facing) is_front: bool,
    ...v, // legal because it spreads nothig into this struct
};

@fragment
fn fragment(in: FragmentInput) -> @location(0) vec4<f32> {
    ...v; // legal because it spreads nothing into the function body
    var output_color: vec4<f32> = material.color;
    return output_color;
}
```

### struct!

Returns a structure meant to be spread into regular WGSL structs;

```js
struct! {
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
};
```

Can be spread into a WGSL struct like following:

```js
struct! params = struct! {
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
};

struct FragmentInput {
    @builtin(front_facing) is_front: bool,
    ...params,
};
```

### scope!

Represents an WGSL scope and tokens inside it.

```rs
scope! s = scope! {
    var a: f32 = 2.0;
    var b: f32 = 2.0;
};
```

Scopes cancontain

```js
fn foo () {
    var a: f32 = 2.0;

    scope! s = scope! {
        var b: f32 = 2.0;
        a += b;
    };

    var c: f32 = ...s;
}
```

Scopes only make sense to be used in combinations with if?.

```js
@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    var color = textureSample(texture, sampler, in.uv);
    ...if? (COLORED) scope! {
        color = in.color * color;
    } // if? returns the scope!, which is spread into the shader
    return color;
}
```

*Note: scopes! can only be declared inside functions and therefore cannot be exported.*

### var!

Represents a variable definition. Mainly useful for resource definitions.

```js
var! view = var! {
    @group(0) @binding(0)
    var<uniform> t: f32;
};

export { view };
```

```js
import { view } from "file/path.mwgsl";

...view;
@group(1) @binding(0)
var<uniform> material: MaterialData;

```

### if? and else?

Returns RETURN_VALUE to compilation if DEFINITION exists.

*TODO: Decide how and whether more comparisions should be possible, such as comparing to numbers*

```js
if? (DEFINITION) RETURN_VALUE;
```

Returns RETURN_VALUE_1 to compilation if DEFINITION exists, otherwise returns RETURN_VALUE_2.

```js
if? (DEFINITION) RETURN_VALUE_1;
else? RETURN_VALUE_2;
```

Executes macro code inside the {} block and returns the tail ("functional_expression" in this case) to compilation if DEFINITION exists, otherwise returns void!.

```js
fn foo() {
    var a = 2.0;
    ...if! (DEFINITION) {
        fe! fn_expr = fe! {
            // a WGSL function body
            var b = 2.0;
            return a + b;
        };

        functional_expression
    };
}
```
