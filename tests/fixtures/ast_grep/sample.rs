// TODO: sample comment
use std::rc::Rc;
use std::sync::Arc;

#[derive(Debug, Clone)]
struct Point { x: i32 }

trait Show { fn show(&self); }

impl Show for Point {
    fn show(&self) { println!("a string {}", self.x); }
}

impl Point {
    fn new() -> Self { Point { x: 0 } }
}

async fn fetch() -> Result<i32, String> {
    let v: Option<i32> = None;
    v.unwrap();
    v.expect("msg");
    let n = parse()?;
    let p = Point::new().clone();
    let b = Box::new(1);
    let r = Rc::new(1);
    let a = Arc::new(1);
    let y = other().await;
    let z = n as i64;
    let f = |q: i32| q + 1;
    match v { Some(_) => {}, None => {} }
    for i in 0..3 {}
    unsafe { todo!() }
    dbg!(z);
    panic!("boom");
}
