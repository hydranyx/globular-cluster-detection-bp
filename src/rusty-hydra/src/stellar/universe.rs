use std::collections::HashMap;

use kiddo::distance::squared_euclidean;
use kiddo::KdTree;
use rayon::slice::ParallelSliceMut;
use serde::{Deserialize, Serialize};

use super::{Cluster, Id, Star};

#[derive(Debug, Default, Clone, Deserialize, Serialize)]
pub struct Universe {
    stars: HashMap<Id, Star>,
}

impl<'a> Universe {
    pub fn with_stars(stars: HashMap<Id, Star>) -> Self {
        Self { stars }
    }

    pub fn get(&self, id: &Id) -> Option<&Star> {
        self.stars.get(id)
    }

    pub fn stars(&self) -> impl Iterator<Item = (&Id, &Star)> {
        self.stars.iter()
    }

    fn sources(&'a self) -> (Vec<Id>, Vec<Id>) {
        let (zeros, mut non_zeros): (Vec<_>, Vec<_>) = self
            .stars()
            .map(|(id, _)| id)
            .partition(|id| self.stars.get(id).unwrap().pheromone == 0.0);

        non_zeros.par_sort_by(|star1, star2| {
            let star1 = self.stars.get(star1).unwrap();
            let star2 = self.stars.get(star2).unwrap();

            star1.pheromone.partial_cmp(&star2.pheromone).unwrap()
        });

        (zeros, non_zeros)
    }

    pub fn clusters(&'a self) -> impl Iterator<Item = Cluster<'a>> {
        let (zeros, mut non_zeros) = self.sources();

        let mut clusters = Vec::new();

        // While there are stars still left to process.
        while !non_zeros.is_empty() {
            log::trace!(
                "{} clusters so far: {} stars remaining",
                clusters.len(),
                non_zeros.len()
            );
            let star = non_zeros.pop().unwrap();
            let mut cluster = Cluster::with_star(self, star);

            // Go through the stars based on pheromone values to check if it is
            // clustured.
            {
                let mut index_source = non_zeros.len().checked_sub(1);
                while let Some(index) = index_source {
                    let star = non_zeros[index];
                    if cluster.captures(star) {
                        non_zeros.remove(index);
                        cluster.insert(star);
                    }

                    index_source = index.checked_sub(1);
                }
            }
            clusters.push(cluster);
        }
        log::debug!(
            "Finished clustering main stars: {} clusters",
            clusters.len()
        );

        log::debug!("Procesing {} zero pheromone stars", zeros.len());

        let mut distance_lookup: KdTree<f64, usize, 3> = KdTree::new();
        for (idx, cluster) in clusters.iter().enumerate() {
            distance_lookup
                .add(&cluster.centroid().into(), idx)
                .unwrap();
        }

        for star in zeros {
            let coordinate = self.get(&star).unwrap().coordinate;
            let (_, &cluster) = distance_lookup
                .nearest_one(&coordinate.into(), &squared_euclidean)
                .unwrap();
            let cluster = &mut clusters[cluster];
            if (coordinate - cluster.centroid()).abs() <= cluster.diameter() / 2.0 {
                cluster.insert(star);
            }
        }
        // for star in zeros {
        //     let coordinate = self.get(&star).unwrap().coordinate;
        //     for cluster in &mut clusters {
        //         if cluster.bounds(coordinate) {
        //             cluster.insert(star);
        //             break;
        //         }
        //     }
        // }

        log::debug!("Finished clustering");
        clusters.into_iter()
    }
}
