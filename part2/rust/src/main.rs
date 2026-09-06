// rust: ownership, borrowing, and deterministic drop
use std::time::Instant;
use std::hint::black_box;

const N: usize = 200_000;

// each Vec is dropped at the end of its scope: no gc, no manual free
fn owned_allocation() -> i64 {
    let mut sum: i64 = 0;
    for i in 0..N {
        let block: Vec<i32> = (0..64).map(|j| (i as i32) + j).collect();
        sum += black_box(&block)[0] as i64;
        // block goes out of scope here and its heap buffer is freed
    }
    sum
}

// ownership transfer: the value moves, the original binding is invalidated
fn demonstrate_move() {
    let a = String::from("owned data");
    let b = a;                 // a is moved into b
    println!("  after move, b = {:?}", b);
    // println!("{}", a);      // would not compile: see use_after_move.rs
}

// borrowing: many shared refs, or exactly one mutable ref, never both
fn demonstrate_borrow() {
    let mut v = vec![1, 2, 3];
    {
        let r1 = &v;
        let r2 = &v;           // multiple immutable borrows are allowed
        println!("  immutable borrows: {:?} {:?}", r1.len(), r2.len());
    }
    {
        let m = &mut v;        // exclusive mutable borrow
        m.push(4);
    }
    println!("  after mutable borrow: {:?}", v);
}

// RAII: Drop runs at a deterministic point, not whenever a collector decides
struct Tracked(&'static str);
impl Drop for Tracked {
    fn drop(&mut self) {
        println!("  dropping {}", self.0);
    }
}

fn main() {
    let t0 = Instant::now();
    let s = owned_allocation();
    let elapsed = t0.elapsed();
    println!("owned alloc/free of {} blocks, checksum {}", N, s);
    println!("elapsed: {} ms", elapsed.as_millis());

    println!("\nmove semantics:");
    demonstrate_move();

    println!("\nborrow checker:");
    demonstrate_borrow();

    println!("\ndeterministic drop order:");
    {
        let _outer = Tracked("outer");
        {
            let _inner = Tracked("inner");
            println!("  inner scope active");
        }
        println!("  back in outer scope");
    }
    println!("  main continues after both drops");
}
