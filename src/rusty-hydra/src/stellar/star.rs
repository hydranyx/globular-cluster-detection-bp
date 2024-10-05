use serde::{Deserialize, Serialize};

use super::{Coordinate, ProperMotion};

#[derive(Clone, Debug, Default, PartialEq, Deserialize, Serialize)]
pub struct Star {
    pub coordinate: Coordinate,
    pub proper_motion: ProperMotion,
    pub parallax: f64,
    pub absolute_magnitude: f64,
    pub pheromone: f64,
    pub visitations: usize,
    pub total_visitations: usize,
}
