use std::fs::File;
use std::io::BufReader;
use std::path::PathBuf;
use std::sync::atomic::AtomicUsize;

use rayon::prelude::*;
use rusty_hydra::stellar;
use serde::{Deserialize, Serialize};
use structopt::StructOpt;

/// Compute clusters present in a set of provided raster files.
#[derive(Debug, StructOpt)]
struct Arguments {
    /// Bin files to process and cluster within.
    #[structopt(required = true)]
    raster_files: Vec<std::path::PathBuf>,

    /// Where the output files should be written.
    #[structopt(short, long, default_value = ".")]
    output_dir: std::path::PathBuf,

    /// Set verbosity (-v, -vv, -vvv, etc...).
    #[structopt(global = true, short, parse(from_occurrences))]
    verbosity: u64,
}

#[derive(Debug, Serialize, Deserialize)]
struct OutputCluster {
    stars: Vec<stellar::Id>,
    centroid: Coordinate,
    center_of_gravity: Coordinate,
    diameter: Coordinate,
    bounds: (Coordinate, Coordinate),
}

#[derive(Debug, Serialize, Deserialize)]
struct Coordinate {
    ra: f64,
    dec: f64,
    distance: f64,
}

impl From<stellar::Coordinate> for Coordinate {
    fn from(coordinate: stellar::Coordinate) -> Self {
        Self {
            ra: coordinate[0],
            dec: coordinate[1],
            distance: coordinate[2],
        }
    }
}

impl<'a> From<stellar::Cluster<'a>> for OutputCluster {
    fn from(cluster: stellar::Cluster) -> Self {
        let stars = cluster.ids().copied().collect();
        let centroid = cluster.centroid().into();
        let center_of_gravity = cluster.center_of_gravity().into();
        let diameter = cluster.diameter().into();
        let (lower_bound, upper_bound) = cluster.bounds();
        let bounds = (lower_bound.into(), upper_bound.into());
        OutputCluster {
            stars,
            centroid,
            center_of_gravity,
            diameter,
            bounds,
        }
    }
}

const MIN_AMOUNT_OF_STARS: usize = 100; // 20% less than 100 (minimum from the papers).
const MIN_DIAMETER: [f64; 3] = [0.0, 0.0, 0.0]; // Should be equivalent to 10 parsecs in arc-minutes.

fn main() -> anyhow::Result<()> {
    let Arguments {
        raster_files,
        output_dir,
        verbosity,
    } = Arguments::from_args();

    rusty_hydra::cli::setup(verbosity);

    let cluster_count = AtomicUsize::new(0);
    let raster_count = AtomicUsize::new(0);

    raster_files.par_iter().for_each(|path| {
        let file = File::open(&path).expect("opened file");
        let reader = BufReader::new(file);
        let universe: stellar::Universe = bincode::deserialize_from(reader).expect("read universe");
        log::debug!("Loaded Universe");
        let clusters: Vec<_> = universe
            .clusters()
            .filter(|cluster| cluster.stars().count() >= MIN_AMOUNT_OF_STARS)
            .filter(|cluster| cluster.diameter() >= stellar::Coordinate::from(MIN_DIAMETER))
            .inspect(|cluster| log::trace!("Cluster of len: {}", cluster.len()))
            .map(OutputCluster::from)
            .collect();

        if !clusters.is_empty() {
            cluster_count.fetch_add(clusters.len(), std::sync::atomic::Ordering::SeqCst);
            raster_count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
            log::info!(
                r#"Detected {} clusters from "{}""#,
                clusters.len(),
                path.display()
            );
        }

        let output_file_name =
            PathBuf::from(path.file_name().unwrap()).with_extension("cluster.json");
        let output_file_path = output_dir.join(output_file_name);
        let output_file = File::create(output_file_path).unwrap();
        serde_json::ser::to_writer_pretty(output_file, &clusters).expect("serialized ouput");
    });

    log::info!(
        "Detected {} clusters across {} rasters",
        cluster_count.into_inner(),
        raster_count.into_inner()
    );

    Ok(())
}
