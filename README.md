# MWGSL

Modular WGSL. A superset of WGSL that introduces syntax that allows developers to split WGSL and share parts between different files as well as some new useful attributes such as @cfg. While in theory this language can be compiled natively, it is mainly designed to be bundled and transpiled into vanilla WGSL.This document describes a different version of the language that was presented recently. The original document can be found in the ./drafts directory.

*Note: This document is works in progress.*

*Note: This document uses Javascript syntax highlighting which is, of course, incorrect, but works better than no highlighting at all.*

## 1 Motivation

This language is inspired by commonly used C-like shader preprocessors and by the mistakes those preproocessors make. MWGSL is intended to achieve the same end result and replace C-like preprocessors but with a better DX and a modern, robust and Rust-like approach. This language also learns from the operation of ECMAScript bundlers such as [ESBuild](https://esbuild.github.io/) since they solve an almost identical problem and do it in a very developer-friendly way.

### 1.1 Why do I want MWGSL over a C-like preprocessor

* TODO: Update and restore.

### 1.2 Why do I want a shader preprocessor at all

* TODO.

## 2 MWGSL features

This section describes proposed macros, which are syntactical additions to WGSL.

### 2.1 import

Brings named exports into the shader module.

```js
import { EXPORT_NAME } from "file/path.mwgsl";
import { EXPORT_NAME_1, EXPORT_NAME_2 } from "file/path.mwgsl";
```

### 2.2 export

Indicates to other modules that listed exports can be imported.

```js
export { EXPORT_NAME };
```

#### 2.2.1 Functions

WGSL functions can be exported.

```js
// library.mwgsl

function bar(a: f32) -> f32 {
    return b + 1.0;
}

export { foo };
```

Dependencies of exported objects do not need to be exported separately.

```js
// library.mwgsl

function bar(a: f32) -> f32 {
    return b + 1.0;
}

function foo(a: f32) -> f32 {
    return bar(a + 1.0);
}

export { foo }; // MWGSL is aware of bar without it being exported or imported itself. Shall foo be imported into a module where another bar exists, the bar from module-scope of foo is used. No name conflicts occur.
```

Exported functions can depend on varialbes too.

```js
// library.mwgsl

@group(0) @biding(0)
var<uniform> b: f32;

function foo(a: f32) -> f32 {
    return a + b;
}

export { b /* b must be exported, this is explained in the section about variables */, foo };
```

#### 2.2.2 Variables

Module-scope variables can be exported.

```js
// library.mwgsl

@group(0) @biding(0)
var<uniform> b: f32;

export { b };
```

```js
// shader.mwgsl

import { b } from "module.mwgsl";

@fragment
fn fragment() -> @location(0) vec4<f32> {
    var color = vec4<f32>(b);
    return color;
}
```

*Warning: A module scope variable with a @group or a @binding attribute must be exported to prevent blocking the binding in importing modules.*

*Note: if MWGSL code is transpiled to WGSL there is a chance a variable can be renamed to resolve name collisions. It is advised that compilers do not rename variables that have @group and @binding attributes*

*TODO: Describe a new attribute for preserving variable names during transpilation to vanilla WGSL.*

##### 2.2.2.1 Resource variable uniqueness

Objects that are or depend on different resource variables with same @group and @binfding attributes cannot be decalred or imported into the same module. Whether the resoruce variable is the same is determined based on whether it comes from the same module.

###### 2.2.2.1.1 Example #1

```js
// shader.mwgsl

import { a /* b is @group(0) @binding(0) */ } from "module.mwgsl";

@group(0) @biding(0)
var<uniform> b: f32; // Illegal because a variable with the same @group and @binding is imported
```

Fix: Do not declare variables with the same @group(0) and @binding(0) atributes

###### 2.2.2.1.2 Example #2

```js
// library.mwgsl

@group(0) @biding(0)
var<uniform> b: f32;

function foo(a: f32) -> f32 {
    return a + b;
}

export { b /* b must be exported */, foo };
```

```js
// shader.mwgsl

import { foo } from "library.mwgsl";

@group(0) @biding(0)
var<uniform> a: f32; // Illegal because foo depends on a variable with the same @group and @binding attributes
```

Fix: Import b instead and optinally alias it.

```js
// shader.mwgsl

import { foo, b as a } from "library.mwgsl";
```

###### 2.2.2.1.3 Example #3

```js
// library_1.mwgsl

@group(0) @biding(0)
var<uniform> b: f32;

function foo(a: f32) -> f32 {
    return a + b;
}

export { b, foo };
```

```js
// library_2.mwgsl

@group(0) @biding(0)
var<uniform> b: f32;

function bar(a: f32) -> f32 {
    return b + a;
}

export { b, bar };
```

```js
// shader.mwgsl

import { foo } from "library_1.mwgsl";
import { bar } from "library_2.mwgsl"; // Illegal because both foo and bar depend on variables with the same @group and @binding attributes
```

Fix as a user: Choose between bar or foo. They are conflicting imports

Fix as a library developer: Split the uniform into a separate module and import it in library_1 and library_2

```js
// library_uniforms.mwgsl

@group(0) @biding(0)
var<uniform> b: f32;

export { b };
```

```js
// library_1.mwgsl

import { b } from "library_uniforms.mwgsl";

function foo(a: f32) -> f32 {
    return a + b;
}

export { foo }
```

```js
// library_2.mwgsl

import { b } from "library_uniforms.mwgsl";

function bar(a: f32) -> f32 {
    return b + a;
}

export { bar }
```

```js
// shader.mwgsl

import { b } from "library_uniforms.mwgsl"; // This line is optional if variable with @group(0) and @binding(0) is needed
import { foo } from "library_1.mwgsl";
import { bar } from "library_2.mwgsl";
```

#### 2.2.3 Structs

Structures can be exported.

```js
// library.mwgsl

struct VertexOutput {
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
}

export { VertexOutput };
```

Imported structures can be used directly.

```js
// shader.mwgsl

import { VertexOutput } from "module.mwgsl";

@vertex
fn vertex(
    @location(0) vertex_position: vec3<f32>,
    @location(1) vertex_uv: vec2<f32>,
) -> VertexOutput {
    var out: VertexOutput;
    out.uv = vertex_uv;
    out.position = view.view_proj * vec4<f32>(vertex_position, 1.0);
    return out;
}

@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    var color = vec4<f32>(0.0);
    return color;
}
```

Alternatively, structures can be spread into other structures.

```js
// shader.mwgsl

import { VertexOutput } from "module.mwgsl";

struct MyVertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    ...VertexOutput,
}
```

### 2.3 @cfg

Similarly to the cfg attibute in Rust, this attribute can mark definitions to be ignored. @cfg is executed at compile time and operates only on environment variables.

*Note: Environment variables are set on the compiler programmatically and not within MWGSL code.*

*Note: While there can in theory be a native MWGSL compiler, this is mainly meant for MWGSL to WGSL transpiers.*

#### 2.3.1 @cfg import

Imports can be made optional.

*Debate: Should they?*

```js
@cfg(USE_FOO)
import { foo } from "library.mwgsl";
@cfg(!USE_FOO)
import { bar as foo } from "library.mwgsl";
```

#### 2.3.2 @cfg var

Variables can be declared optionally.

```js
@cfg(ZERO_IS_FLOAT) @group(0) @biding(0)
var<uniform> a: f32;
@cfg(!ZERO_IS_FLOAT) @group(0) @biding(0)
var<uniform> a: i32;
```

#### 2.3.3 @cfg struct

Structs can be declared optionally.

```js
@cfg(USE_MODULE_OUTPUT_STRUCT)
import { VertexOutput as ModuleVO } from "module.mwgsl";

@cfg(USE_MODULE_OUTPUT_STRUCT)
struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    ...ModuleVO,
}

@cfg(!USE_MODULE_OUTPUT_STRUCT)
struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
}
```

#### 2.3.4 @cfg scope

Scopes can be made optional.

*Note: This acts as compile time if statetent*

```js
@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    var color = textureSample(texture, sampler, in.uv);
    @cfg(COLORED) {
        color = in.color * color;
    } // This scope is ignored unless COLORED is present in compilation enviroment
    return color;
}
```
