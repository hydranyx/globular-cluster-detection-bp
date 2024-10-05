use std::fs::File;
use std::io::BufReader;
use std::path::{Path, PathBuf};

use rayon::prelude::*;
use rusty_hydra::stellar;
use structopt::StructOpt;

/// Convert a provided set of CSV files to a binary format for quick processing.
#[derive(Debug, StructOpt)]
struct Arguments {
    /// CSV files to convert (the file-stem of the input files are used
    /// to name the output files).
    #[structopt(required = true)]
    csv_files: Vec<std::path::PathBuf>,

    /// Where the output files should be written.
    #[structopt(short, long, default_value = ".")]
    output_dir: std::path::PathBuf,

    /// Set verbosity (-v, -vv, -vvv, etc...).
    #[structopt(global = true, short, parse(from_occurrences))]
    verbosity: u64,
}

trait ReadFromCsv {
    type Error;
    fn read_from_csv<P: AsRef<Path>>(path: P) -> Result<Self, Self::Error>
    where
        Self: Sized;
}

impl ReadFromCsv for stellar::Universe {
    type Error = anyhow::Error;

    fn read_from_csv<P: AsRef<Path>>(path: P) -> Result<Self, Self::Error> {
        let path = path.as_ref();
        const EXPECTED_HEADERS: &[&str] = &[
            "source_id",
            "ra",
            "dec",
            "parallax",
            "pmra",
            "pmdec",
            "phot_g_mean_mag",
            "distance",
            "neighbors",
            "weights",
            "pheromone",
            "visitations",
            "total_visitations",
        ];

        // Open a buffered reader into the file.
        log::info!(r#"opening "{}""#, path.display());
        let file = File::open(&path)?;
        let reader = BufReader::new(file);
        // Open that reader as a csv file.
        let mut csv = csv::Reader::from_reader(reader);

        // Check that the headers match.
        let headers: Vec<_> = csv.headers()?.iter().collect();
        if headers != EXPECTED_HEADERS {
            return Err(anyhow::anyhow!(
                "expected: {:?} got: {:?}",
                EXPECTED_HEADERS,
                headers
            ));
        }
        log::info!("headers validated");

        // create intermediary type to reduce verbosity.
        #[derive(serde::Deserialize, Debug)]
        struct ParsedRecord {
            source_id: usize,
            ra: f64,
            dec: f64,
            parallax: f64,
            pmra: f64,
            pmdec: f64,
            phot_g_mean_mag: f64,
            distance: f64,
            #[serde(rename = "neighbors")]
            _neighbors: String,
            #[serde(rename = "weights")]
            _weights: String,
            pheromone: f64,
            visitations: usize,
            total_visitations: usize,
        }

        // Iterate through each record to pull out the bare minimum data.
        let records = csv
            .deserialize()
            .inspect(|val| log::trace!("{:?}", val))
            .collect::<Result<Vec<ParsedRecord>, _>>()?;

        records
            .iter()
            .map(
                |ParsedRecord {
                     source_id,
                     ra,
                     dec,
                     parallax,
                     pmra,
                     pmdec,
                     phot_g_mean_mag,
                     distance,
                     _neighbors: _,
                     _weights: _,
                     pheromone,
                     visitations,
                     total_visitations,
                 }| {
                    let id = *source_id;
                    let coordinate = stellar::Coordinate::from([*ra, *dec, *distance]);
                    let proper_motion = stellar::ProperMotion::from([*pmra, *pmdec]);
                    let parallax = *parallax;
                    let absolute_magnitude = *phot_g_mean_mag;

                    let pheromone = *pheromone;
                    let visitations = *visitations;
                    let total_visitations = *total_visitations;
                    let star = stellar::Star {
                        coordinate,
                        proper_motion,
                        parallax,
                        absolute_magnitude,
                        pheromone,
                        visitations,
                        total_visitations,
                    };
                    Ok((id, star))
                },
            )
            .collect::<Result<_, _>>()
            .map(stellar::Universe::with_stars)
    }
}

fn main() {
    let Arguments {
        csv_files,
        output_dir,
        verbosity,
    } = Arguments::from_args();

    rusty_hydra::cli::setup(verbosity);

    csv_files.into_par_iter().for_each(|path| {
        // Open the CSV file.
        // Parse it into the Universe struct.
        let universe = stellar::Universe::read_from_csv(&path).expect("parsed Universe");

        // Write the universe into the binary format in the provided output
        // directory.
        let output_file_name = PathBuf::from(path.file_name().unwrap()).with_extension("bin");
        let output_path = output_dir.join(output_file_name);
        let output_file = File::create(&output_path).expect("created output file");
        bincode::serialize_into(output_file, &universe)
            .expect("serialized Universe to output file");
    });
}
