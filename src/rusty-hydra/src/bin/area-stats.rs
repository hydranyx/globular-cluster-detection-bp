use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

use rayon::prelude::*;
use rusty_hydra::stellar;
use serde::Serialize;
use structopt::StructOpt;

/// Process the stats associated with some set of files.
#[derive(Debug, StructOpt)]
struct Arguments {
    /// Bin files to process and find statistics on.
    #[structopt(required = true)]
    area_files: Vec<std::path::PathBuf>,
    /// Set output to be in json.
    #[structopt(global = true, short, long)]
    json: bool,
    /// Set verbosity (-v, -vv, -vvv, etc...).
    #[structopt(global = true, short, parse(from_occurrences))]
    verbosity: u64,
}

#[derive(Default, Copy, Clone, Serialize)]
#[serde(into = "String")]
struct Bucket<const SUBDIVISION: usize>(f64);

impl<const SUBDIVISION: usize> From<Bucket<SUBDIVISION>> for String {
    fn from(val: Bucket<SUBDIVISION>) -> Self {
        let precision = (SUBDIVISION as f64).log(10.0) as usize;
        format!("{:.*}", precision, val.0)
    }
}

impl<const SUBDIVISION: usize> Bucket<SUBDIVISION> {
    fn new(value: f64) -> Self {
        let numerator = if value.is_sign_negative() {
            (value * SUBDIVISION as f64).floor()
        } else {
            (value * SUBDIVISION as f64).ceil()
        };

        Bucket(numerator / SUBDIVISION as f64)
    }

    fn equivalent(&self) -> usize {
        (self.0 * SUBDIVISION as f64) as usize
    }
}

impl<const SUBDIVISION: usize> std::hash::Hash for Bucket<SUBDIVISION> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.equivalent().hash(state)
    }
}

impl<const SUBDIVISION: usize> PartialEq for Bucket<SUBDIVISION> {
    fn eq(&self, other: &Self) -> bool {
        self.equivalent() == other.equivalent()
    }
}
impl<const SUBDIVISION: usize> Eq for Bucket<SUBDIVISION> {}

impl<const SUBDIVISION: usize> std::fmt::Debug for Bucket<SUBDIVISION> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(f)
    }
}

#[derive(Default, Clone)]
struct IntermediaryStats {
    cumulative_pheromone_visited: f64,
    count_visited: usize,
    count_unvisited: usize,
    pheromone_distribution: HashMap<Bucket<100000>, usize>,
    magnitude_distribution: HashMap<Bucket<1>, usize>,
    pmra_distribution: HashMap<Bucket<10>, usize>,
    pmdec_distribution: HashMap<Bucket<10>, usize>,
    parallax_distribution: HashMap<Bucket<100>, usize>,
    distance_distribution: HashMap<Bucket<100>, usize>,
}

#[derive(Serialize)]
struct Stats {
    #[serde(rename = "visited_pheromone_mean")]
    cumulative_pheromone_mean_visited: f64,
    #[serde(rename = "total_pheromone_mean")]
    cumulative_pheromone_mean_all: f64,
    pheromone_distribution: HashMap<Bucket<100000>, usize>,
    magnitude_distribution: HashMap<Bucket<1>, usize>,
    pmra_distribution: HashMap<Bucket<10>, usize>,
    pmdec_distribution: HashMap<Bucket<10>, usize>,
    parallax_distribution: HashMap<Bucket<100>, usize>,
    distance_distribution: HashMap<Bucket<100>, usize>,
    total_visited: usize,
    total_count: usize,
}

impl std::fmt::Display for Stats {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> Result<(), std::fmt::Error> {
        let Self {
            cumulative_pheromone_mean_visited,
            cumulative_pheromone_mean_all,
            pheromone_distribution,
            magnitude_distribution,
            pmra_distribution,
            pmdec_distribution,
            parallax_distribution,
            distance_distribution,
            total_visited,
            total_count,
        } = self;
        write!(
            f,
            concat!(
                "visited pheromone mean: {}\n",
                "total pheromone mean: {}\n",
                "pheromone distribution: {:#?}\n",
                "magnitude distribution: {:#?}\n",
                "pmra distribution: {:#?}\n",
                "pmdec distribution: {:#?}\n",
                "parallax distribution: {:#?}\n",
                "distance distribution: {:#?}\n",
                "total visited: {}",
                "total: {}"
            ),
            cumulative_pheromone_mean_visited,
            cumulative_pheromone_mean_all,
            pheromone_distribution,
            magnitude_distribution,
            pmra_distribution,
            pmdec_distribution,
            parallax_distribution,
            distance_distribution,
            total_visited,
            total_count
        )
    }
}

impl IntermediaryStats {
    fn combine(self, rhs: &Self) -> Self {
        let IntermediaryStats {
            mut pheromone_distribution,
            mut magnitude_distribution,
            mut pmra_distribution,
            mut pmdec_distribution,
            mut parallax_distribution,
            mut distance_distribution,
            ..
        } = self;

        for (&key, value) in rhs.pheromone_distribution.iter() {
            let count = pheromone_distribution.entry(key).or_insert(0);
            *count += value;
        }

        for (&key, value) in rhs.magnitude_distribution.iter() {
            let count = magnitude_distribution.entry(key).or_insert(0);
            *count += value;
        }

        for (&key, value) in rhs.pmra_distribution.iter() {
            let count = pmra_distribution.entry(key).or_insert(0);
            *count += value;
        }

        for (&key, value) in rhs.pmdec_distribution.iter() {
            let count = pmdec_distribution.entry(key).or_insert(0);
            *count += value;
        }

        for (&key, value) in rhs.parallax_distribution.iter() {
            let count = parallax_distribution.entry(key).or_insert(0);
            *count += value;
        }

        for (&key, value) in rhs.distance_distribution.iter() {
            let count = distance_distribution.entry(key).or_insert(0);
            *count += value;
        }

        IntermediaryStats {
            cumulative_pheromone_visited: self.cumulative_pheromone_visited
                + rhs.cumulative_pheromone_visited,
            count_visited: self.count_visited + rhs.count_visited,
            count_unvisited: self.count_unvisited + rhs.count_unvisited,
            pheromone_distribution,
            magnitude_distribution,
            pmra_distribution,
            pmdec_distribution,
            parallax_distribution,
            distance_distribution,
        }
    }

    fn compute(self) -> Stats {
        let cummulative_pheromone_mean_visited =
            self.cumulative_pheromone_visited / self.count_visited as f64;
        let cummulative_pheromone_mean_all =
            self.cumulative_pheromone_visited / (self.count_visited + self.count_unvisited) as f64;
        let pheromone_distribution = self.pheromone_distribution;
        let magnitude_distribution = self.magnitude_distribution;
        let pmra_distribution = self.pmra_distribution;
        let pmdec_distribution = self.pmdec_distribution;
        let parallax_distribution = self.parallax_distribution;
        let distance_distribution = self.distance_distribution;
        let total_visited = self.count_visited;
        let total_count = self.count_visited + self.count_unvisited;
        Stats {
            cumulative_pheromone_mean_visited: cummulative_pheromone_mean_visited,
            cumulative_pheromone_mean_all: cummulative_pheromone_mean_all,
            pheromone_distribution,
            magnitude_distribution,
            pmra_distribution,
            pmdec_distribution,
            parallax_distribution,
            distance_distribution,
            total_visited,
            total_count,
        }
    }
}

fn main() {
    let Arguments {
        area_files,
        json,
        verbosity,
    } = Arguments::from_args();

    rusty_hydra::cli::setup(verbosity);

    let stats: IntermediaryStats = area_files
        .par_iter()
        .map(|path| {
            let file = File::open(&path).expect("opened file");
            let reader = BufReader::new(file);
            let universe: stellar::Universe =
                bincode::deserialize_from(reader).expect("read universe");
            universe
                .stars()
                .map(|(_, star)| {
                    let (
                        cummulative_pheromone_visited,
                        count_visited,
                        count_unvisited,
                        pheromone_distribution,
                        magnitude_distribution,
                        pmra_distribution,
                        pmdec_distribution,
                        parallax_distribution,
                        distance_distribution,
                    ) = if star.pheromone == 0.0 {
                        (
                            0.0,
                            0,
                            1,
                            [(Bucket::new(0.0), 1_usize)].iter().cloned().collect(),
                            [(Bucket::new(star.absolute_magnitude), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.proper_motion[0]), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.proper_motion[1]), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.parallax), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.coordinate[2]), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                        )
                    } else {
                        (
                            star.pheromone,
                            1,
                            0,
                            [(Bucket::new(star.pheromone), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.absolute_magnitude), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.proper_motion[0]), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.proper_motion[1]), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.parallax), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                            [(Bucket::new(star.coordinate[2]), 1_usize)]
                                .iter()
                                .cloned()
                                .collect(),
                        )
                    };
                    IntermediaryStats {
                        cumulative_pheromone_visited: cummulative_pheromone_visited,
                        count_visited,
                        count_unvisited,
                        pheromone_distribution,
                        magnitude_distribution,
                        pmra_distribution,
                        pmdec_distribution,
                        parallax_distribution,
                        distance_distribution,
                    }
                })
                .fold(IntermediaryStats::default(), |acc, stats| {
                    acc.combine(&stats)
                })
        })
        .reduce(IntermediaryStats::default, |acc, stats| acc.combine(&stats));

    let stats = stats.compute();
    if json {
        println!("{}", serde_json::ser::to_string_pretty(&stats).unwrap());
    } else {
        println!("{}", stats);
    }
}
