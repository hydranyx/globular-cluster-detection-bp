use std::collections::HashSet;

use super::{Coordinate, Id, Star, Universe};

pub const MIN_ATTRACTION: f64 = 0.01;

#[derive(Clone)]
pub struct Cluster<'a> {
    context: &'a Universe,
    inner: HashSet<Id>,
    cache: CachedData,
}

#[derive(Clone)]
struct CachedData {
    pheromone_mass: f64,
    coordinate_sum: Coordinate,
    /// (Lower Bound, Upper Bound)
    bounds: (Coordinate, Coordinate),
    /// pheromone of star * coordinate of star
    coordimone: Coordinate,
}

impl<'a> std::fmt::Debug for Cluster<'a> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Cluster")
            .field("stars", &self.inner)
            .finish()
    }
}

impl<'a> Cluster<'a> {
    pub fn len(&'a self) -> usize {
        self.inner.len()
    }

    pub fn with_star(context: &'a Universe, star: Id) -> Self {
        let Star {
            pheromone,
            coordinate,
            ..
        } = context.get(&star).unwrap();
        let mut inner = HashSet::new();
        inner.insert(star);

        let cache = CachedData {
            pheromone_mass: *pheromone,
            bounds: (*coordinate, *coordinate),
            coordinate_sum: *coordinate,
            coordimone: (*coordinate) * (*pheromone),
        };
        Self {
            context,
            inner,
            cache,
        }
    }

    pub fn ids(&'a self) -> impl Iterator<Item = &'a Id> {
        self.inner.iter()
    }

    pub fn stars(&'a self) -> impl Iterator<Item = &'a Star> {
        self.inner
            .iter()
            .map(move |id| self.context.get(id).unwrap())
    }

    pub fn centroid(&self) -> Coordinate {
        self.cache.coordinate_sum / self.inner.len() as f64
    }

    pub fn center_of_gravity(&self) -> Coordinate {
        self.cache.coordimone / self.cache.pheromone_mass
    }

    pub fn diameter(&self) -> Coordinate {
        (self.cache.bounds.1 - self.cache.bounds.0).abs()
    }

    pub fn pheromone_mass(&self) -> f64 {
        self.cache.pheromone_mass
    }

    pub fn captures(&self, id: Id) -> bool {
        let Star {
            pheromone,
            coordinate,
            ..
        } = self.context.get(&id).expect("star was within context");

        let cog = self.center_of_gravity();
        let pheromone_mass = self.pheromone_mass();

        let distance = cog.metric_distance(coordinate).abs();

        let attraction = (pheromone * pheromone_mass) / distance.powi(2);

        if attraction >= MIN_ATTRACTION {
            log::debug!("Attraction is sufficient");
        }
        attraction >= MIN_ATTRACTION
    }

    pub fn bounds(&self) -> (Coordinate, Coordinate) {
        self.cache.bounds
    }

    pub fn insert(&mut self, id: Id) {
        if self.inner.insert(id) {
            let Star {
                pheromone,
                coordinate,
                ..
            } = self.context.get(&id).unwrap();

            self.cache.pheromone_mass += pheromone;
            self.cache.bounds.0 = self.cache.bounds.0.min_bounds(*coordinate);
            self.cache.bounds.1 = self.cache.bounds.1.max_bounds(*coordinate);
            self.cache.coordinate_sum += *coordinate;
            self.cache.coordimone += (*coordinate) * (*pheromone);
        } else {
            log::warn!("{} already existed", id);
        }
    }

    pub fn extend<I: std::iter::Iterator<Item = Id>>(&mut self, ids: I) {
        self.inner.extend(ids);
    }
}

impl BoundsCheck for Coordinate {
    fn min_bounds(&self, rhs: Self) -> Self {
        Self::from([
            self[0].min(rhs[0]),
            self[1].min(rhs[1]),
            self[2].min(rhs[2]),
        ])
    }

    fn max_bounds(&self, rhs: Self) -> Self {
        Self::from([
            self[0].max(rhs[0]),
            self[1].max(rhs[1]),
            self[2].max(rhs[2]),
        ])
    }
}

trait BoundsCheck {
    fn min_bounds(&self, rhs: Self) -> Self;
    fn max_bounds(&self, rhs: Self) -> Self;
}
