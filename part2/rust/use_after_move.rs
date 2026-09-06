// rust: the compiler rejects use-after-move at compile time
fn main() {
    let a = String::from("owned data");
    let b = a;                 // ownership moves out of a
    println!("{}", a);         // error: borrow of moved value
    println!("{}", b);
}
