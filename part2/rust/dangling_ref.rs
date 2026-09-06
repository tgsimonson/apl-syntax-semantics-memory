// rust: the equivalent of the C++ dangling pointer, rejected at compile time
fn dangle() -> &String {
    let s = String::from("freed at end of function");
    &s                          // error: returns a reference to local data
}

fn main() {
    let r = dangle();
    println!("{}", r);
}
