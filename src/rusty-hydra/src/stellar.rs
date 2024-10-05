use nalgebra::SVector as Vector;

mod cluster;
mod star;
mod universe;

pub use cluster::Cluster;
pub use star::Star;
pub use universe::Universe;
pub type Id = usize;
pub type Coordinate = Vector<f64, 3>;
pub type ProperMotion = Vector<f64, 2>;
