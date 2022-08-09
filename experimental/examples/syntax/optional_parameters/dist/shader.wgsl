fn add_mul_11(a: f32, add: f32, multiply: f32) -> f32 {
    var res: f32 = a;

    {
        res = res + add;
    }

    {
        res = res * multiply;
    }

    return res;
}

fn add_mul_10(a: f32, add: f32) -> f32 {
    var res: f32 = a;

    {
        res = res + add;
    }

    return res;
}

fn add_mul_01(a: f32, multiply: f32) -> f32 {
    var res: f32 = a;

    {
        res = res * multiply;
    }

    return res;
}

fn add_mul_00(a: f32) -> f32 {
    var res: f32 = a;

    return res;
}

fn main() {
    // 2 + 2 * 2
    var focused = 2.0 + 2.0 * 2.0; // 6.0
    var distracted = add_mul_11(2.0, 2.0, 2.0); // 8.0

    // omit parameters
    add_mul_10(2.0, 2.0); // 4.0
    add_mul_00(2.0); // 2.0

    // named parameters
    add_mul_01(2.0, 3.0); // 6.0
    add_mul_01(2.0, 3.0); // 6.0

    add_mul_11(2.0, 1.0, 0.5); // 1.5
}
