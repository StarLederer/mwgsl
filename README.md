# MWGSL

Modular WGSL. A superset of WGSL that allows developers to break the code up and share it between modules, as well as adds new attributes such as #[env] and #[cfg] that help building DRY statically-analyzed shader programs with compile-time superpowers. While in theory this language can be compiled natively, it is mainly designed to be bundled and transpiled into vanilla WGSL.

*Note: This document is works in progress.*

*Note: This document uses Javascript syntax highlighting which is, of course, incorrect, but works better than no highlighting at all.*

## 1 Motivation

This language is inspired by commonly used C-like shader preprocessors and by the mistakes those preproocessors make. MWGSL is intended to achieve the same end result and replace C-like preprocessors but with a better DX and a modern, robust and Rust-like approach. This language also learns from the operation of ECMAScript bundlers such as [ESBuild](https://esbuild.github.io/) since they solve an almost identical problem, as well as some of the [12 factors](https://12factor.net).

### 1.1 Why do I want MWGSL over a C-like preprocessor

* **Named imports instead of file inclusion.** This means you have the ability to filter and alias what you import and avoid unwanted and unexpected code insertions into your programs.
* **Module isolation.** In [12-factor](https://12factor.net/dependencies) manner, dependencies of imported objects are isolated in their original module scope and do not conflict with other imported or user defined obects making it effortless to name and define things in your code.
* **Principaled resource import.** MWGSL forbids redeclaration and double import of resource variables (@group(n) @binding(n)) and forces module develoeprs to export resource variables they use to prevent them from being blocked off from you.
* **Environment variables.** Defines are unpredictable and prone to unexpected collisions due to their global compile-time nature, that is why MWGSL uses environment variables instead. In [12-factor](https://12factor.net/config) manner, shaders cannot define environemnt variables but they must declare dependence on them. This prevents any unexpected compile time changes or errors when you write code.
* **Config attribute.** Like #ifdef, MWGSL has a #[cfg] attribute that can mark imports, declarations, struct entries and scopes as optional. Unlike #ifdef, however, #[cfg] takes advantage of existing syntax to make writing invalid code impossible. As a bonus, optional scopes behave closer to an actual WGSL if statements by scoping tokens together.
* **Including arbitrary/invaid code is impossible.** Horrible code practices such as starting a function in one #include and finishing it in another are syntactically impossible. 
* **Rust inspired syntax** (as opposed to C; for a more civilised age).

### 1.2 Why do I want a shader preprocessor at all

* **Maintainability.** Although shader programs tend to be short, they sometimes span across over a thousand lines of code and cover many isolated mechanisms. The community demonstrates (e.g. [Bevy](https://github.com/bevyengine/bevy/tree/main/crates/bevy_pbr/src/render)) that maintaining extensive shaders like these requires breaking them up into multipe files.
* **Reusability.** Most game engines include PBR rendering systems, however, it is often required to modify or add to the engine's shaders to achieve certain art directions. Many engines (e.g. [Unity](https://unity.com/features/shader-graph), [Bevy](https://docs.rs/bevy/0.8.0/bevy/pbr/trait.Material.html)) offer mechanisms to reuse built-in logic in user written shaders.
* **Shader variants.** Branching logic on the GPU is limited ([Bolas, 2016](https://stackoverflow.com/a/37837060)), as a result, compile-time static if statements are often used to generate different shader varants.

## 2 MWGSL features

This section describes proposed syntactical additions to WGSL.

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

### 2.3 Sharable objects

This section describes WGSL objects that can be shared between modules.

#### 2.3.1 Functions

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

#### 2.3.2 Variables

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

##### 2.3.2.1 Resource variable uniqueness

Objects that are or depend on different resource variables with same @group and @binfding attributes cannot be decalred or imported into the same module. Whether the resoruce variable is the same is determined based on whether it comes from the same module.

###### 2.3.2.1.1 Example #1

```js
// shader.mwgsl

import { a /* a is @group(0) @binding(0) */ } from "module.mwgsl";

@group(0) @biding(0)
var<uniform> b: f32; // Illegal because a variable with the same @group and @binding is imported
```

Fix: Do not declare variables with the same @group(0) and @binding(0) atributes

###### 2.3.2.1.2 Example #2

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

###### 2.3.2.1.3 Example #3

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

#### 2.3.3 Structs

Structs can be exported.

```js
// library.mwgsl

struct VertexOutput {
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
}

export { VertexOutput };
```

Imported structs can be used directly.

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

Alternatively, structs can be spread into other structs.

```js
// shader.mwgsl

import { VertexOutput } from "module.mwgsl";

struct MyVertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    ...VertexOutput,
}
```


### 2.4 Environment variables

#### 2.4.1 #[env]

Compile-time environemnt variables can be declared as dependencies of structs and functions.

```js
// library.mwgsl

#[env(COLORED: bool, "Toggles usage of vertex colors")]
struct VertexInput = {
    // Compile time attributes can use TOGGLE here 
}

#[env(TOGGLE: bool, "Toggles optional behaviour")]
fn foo() {
    // Compile time attributes can use TOGGLE here 
}

export { foo, VertexOutput };
```

Environment dependencies can be accessed by compile-time attributes by the variable's identifier.

```js
// shader.mwgsl

import { VertexOutput } from "library.mwgsl";

@group(1) @binding(0)
var texture: texture_2d<f32>;
@group(1) @binding(1)
var sampler: sampler;

@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    var color = textureSample(texture, sampler, in.uv);
    #[cfg(VertexOutput.COLORED)] { // Marks scopes as optional. See next section
        color = in.color * color;
    }
    return color;
}
```

Environment variables can be aliased upon import. This can be used to resolve name conflicts when importing objects.

```js
// library_1.mwgsl

#[env(COLORED: bool, "Option that means something")]
struct Structure1 = {
    // ...
}
```

```js
// library_2.mwgsl

#[env(COLORED: bool, "Option that means something different")]
struct Structure2 = {
    // ...
}
```

```js
// shader.mwgsl

#[env_alias(COLORED, VERTEX_COLORS)]
import { Structure1 } from "library_1.mwgsl";
#[env_alias(COLORED, TINT)]
import { Structure2 } from "library_2.mwgsl";

fn foo(one: Structure1, other: Structure2) {
    // foo depends on VERTEX_COLORS and TINT
    return color;
}
```

MWGSL compilers shall require the user to define environment variables found in the entry file and its dependencies.

```rs
use mwgsl::compiler::compile;
use std::collections::HashMap;

fn main() {
    let mut environemnt = HashMap::new();
    environemnt.insert(
        "COLORED".to_string(),
        true.to_string(),
    );
    compile("path/to/shader.mwgsl", Some(environemnt)).unwrap(); // Shall succeed
}
```

```rs
use mwgsl::compiler::compile;

fn main() {
    compile("path/to/shader.mwgsl", None).unwrap(); // Shall fail with a message similar to "Could not compile /absolute/path/to/shader.mwgsl. VERTEX_COLORS and TINT variables were required by the file but not found in the environment. Please pass a HashMap with the listed environemnt variables to the compile function."
}
```

#### 2.4.2 #[cfg]

Similarly to the cfg attibute in Rust, this attribute can mark objects to be ignored. cfg is executed at compile time and operates only on environment variables.

*Bikeshedding material: Should MWGSL @ syntax be used instead?*

*Note: Environment variables are set on the compiler programmatically and not within MWGSL code.*

*Note: While there can in theory be a native MWGSL compiler, this is mainly meant for MWGSL to WGSL transpiers.*

##### 2.4.1 #[cfg] import

Imports can be made optional.

```js
#[cfg(USE_FOO)]
import { foo } from "library.mwgsl";
#[@cfg(!USE_FOO)]
import { bar as foo } from "library.mwgsl";
```

##### 2.4.2 #[cfg] struct

Structs and can be declared optionally.

```js
#[cfg(USE_MODULE_OUTPUT_STRUCT)]
import { VertexOutput as ModuleVO } from "module.mwgsl";

#[cfg(USE_MODULE_OUTPUT_STRUCT)]
struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    ...ModuleVO,
}

#[cfg(!USE_MODULE_OUTPUT_STRUCT)]
struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
}
```

Struct fileds can be added optonally.

```js
struct VertexOutput {
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    #[cfg(VERTEX_TANGENTS)]
    @location(3) world_tangent: vec4<f32>,
    #[cfg(VERTEX_COLORS)]
    @location(4) color: vec4<f32>,
}
```

##### 2.4.2 #[cfg] function parameter

Similarly to struct fields, function parameters can be marked as optional.

```js
fn foo(
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
    #[cfg(VERTEX_TANGENTS)]
    @location(3) world_tangent: vec4<f32>,
    #[cfg(VERTEX_COLORS)]
    @location(4) color: vec4<f32>,
) {}
```

##### 2.4.4 #[cfg] scope

Scopes can be made optional.

*Note: This acts as compile time if statetent*

```js
#[env(COLORED: bool)]
@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    var color = textureSample(texture, sampler, in.uv);
    #[cfg(COLORED)] {
        color = in.color * color;
    } // This scope is ignored unless COLORED is present in compilation enviroment
    return color;
}

export { fragment };
```

## 3 Experimental features

This section describes controversial and experimental features that might be poorly designed or there might be opposition for. These features are to be migrated or removed after debates are complete.

### 3.1 Optional/named parameters

Function parameters can be made optional if marked with "?".

```js
fn foo(a: f32, b?: f32, c?: f32) {}

fn bar() {
    foo(0.0); // Legal
    foo(0.0, 0.0); // Legal
    foo(0.0, 0.0, 0.0); // Legal
}
```

To omit arbitrary parameters they can be passed by names.

```js
fn foo(a: f32, b?: u8, c?: f32) {}

fn bar() {
    foo(0.0, c: 0.0); // Legal
    foo(a: 0.0, b: 0); // Legal
    foo(a: 0.0, b: 0, c: 0.0); // Legal
}
```

Optional parameters can only be used in scopes with a #[has] attribute.

```js
fn add_mul(a: f32, add?: f32, multiply?: f32) -> f32 {
    var res: f32 = a;

    #[has(add)] {
        res = res + add;
    }

    #[has(multiply)] {
        res = res * multiply;
    }

    return res;
}
```

*Warning: Entry points such as @vertex and @fragment cannot have optional parameters.*

*Note: This feature can cause a lot of variants if transpiled to WGSL. It is strongly recommended that developer tools provide insight into how many variants need to be generated in transpilation.*

### 3.2 The "environment variable container (EVC)" pattern

Dependence on environment variables is inherited, developers might therefore use the following pattern to group varaibles together and reuse them across modules.

```js
// pbr_options.mwgsl

// Code repetition
#[env(COLORED: bool, "Toggles usage of vertex colors")]
#[env(IRIDESCENT: bool, "Toggles usage of iridescence")]
#[env(ANISOTROPIC: bool, "Toggles usage of anisotropy")]
#[env(EMISSIVE: bool, "Toggles usage of emissive colors")]
struct PBROptions {}

fn use_pbr_options(options?: PBROptions) {}

export { PBROptions, use_pbr_options };
```

```js
// pbr_lib.mwgsl

import { PBROptions, use_pbr_options } from "pbr_options.mwgsl";

struct VertexInput = {
    ...PBROptions, // spreads nothing but gives access to PBROptions environment dependencies.
    #[cfg(PBROptions.COLORED)]
    @location(0) color: vec4<f32>,
    // ...
}

fn calculate_pbr_lighting(/* ... */) -> vec4<f32> {
    use_pbr_options(); // Does nothing but gives access to use_pbr_options environment dependencies.

    var color = vec4<f32>(1.0);

    // ...

    #[cfg(usePBROptions.COLORED)] {
        // ...
    }

    #[cfg(usePBROptions.IRIDESCENT)] {
        // ...
    }

    #[cfg(usePBROptions.ANISOTROPIC)] {
        // ...
    }

    #[cfg(usePBROptions.EMISSIVE)] {
        // ...
    }

    // ...

    return color;
}

export { VertexInput, calculate_pbr_lighting };
```

Unlike other experimental features, the EVC pattern is almost possible with the existing syntax (requires optional variables), however, it is debatable whether it should be allowed or measures should be taken to forbid it. Or perhaps the opposite, maybe it should gain first-class spport?

### 3.3 #[cfg] declarations

Any definition can be marked as optional.

```js
#[cfg(ZERO_IS_FLOAT)]
@group(0) @biding(0)
var<uniform> a: f32;
#[cfg(!ZERO_IS_FLOAT)]
@group(0) @biding(0)
var<uniform> a: i32;
```

```js
#[cfg(FOO_IS_USED)]
fn foo() {}
```

This feature does not add any value. Definitions can just be exported optionally or elliminated at compile time automatically.
