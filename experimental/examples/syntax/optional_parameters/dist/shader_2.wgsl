fn add_mul_01(a: f32, multiply: f32) -> f32 {
    var res: f32 = a;

    {
        res = res * multiply;
    }

    return res;
}

fn main() {
    add_mul_01(2.0, 2.0);
}
