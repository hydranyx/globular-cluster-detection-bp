use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

use serde::{Deserialize, Serialize};
use structopt::StructOpt;

/// Rasterize a given area file into a set of raster files.
#[derive(Debug, StructOpt)]
struct Arguments {
    /// Area file to rasterize.
    #[structopt(long)]
    area: std::path::PathBuf,
    /// Start of rasterization in RA.
    #[structopt(long)]
    ra: i64,
    /// Start of rasterization in Dec.
    #[structopt(long)]
    dec: i64,
    /// Raster step size.
    #[structopt(long)]
    step: usize,
    /// Prefix for the filename.
    #[structopt(long)]
    prefix: String,
    /// Where the output files should be written.
    #[structopt(short, long)]
    output_dir: std::path::PathBuf,

    /// Set verbosity (-v, -vv, -vvv, etc...).
    #[structopt(global = true, short, parse(from_occurrences))]
    verbosity: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct InputRecord {
    pub source_id: usize,
    pub ra: f64,
    pub dec: f64,
    pub parallax: Option<f64>,
    pub pmra: Option<f64>,
    pub pmdec: Option<f64>,
    pub phot_g_mean_mag: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct OutputRecord {
    pub source_id: usize,
    pub ra: f64,
    pub dec: f64,
    pub parallax: f64,
    pub pmra: f64,
    pub pmdec: f64,
    pub phot_g_mean_mag: f64,
    pub distance: f64,
}

impl From<InputRecord> for OutputRecord {
    fn from(record: InputRecord) -> OutputRecord {
        let InputRecord {
            source_id,
            ra,
            dec,
            parallax,
            pmra,
            pmdec,
            phot_g_mean_mag,
        } = record;

        let parallax = parallax.expect("parallax must be available");
        let pmra = pmra.expect("parallax must be available");
        let pmdec = pmdec.expect("parallax must be available");

        OutputRecord {
            source_id,
            ra,
            dec,
            parallax,
            distance: 1.0 / parallax,
            pmra,
            pmdec,
            phot_g_mean_mag,
        }
    }
}

const EXPECTED_HEADERS: &[&str] = &[
    "source_id",
    "ra",
    "dec",
    "parallax",
    "pmra",
    "pmdec",
    "phot_g_mean_mag",
];

fn main() -> anyhow::Result<()> {
    let Arguments {
        area,
        ra,
        dec,
        step,
        prefix,
        output_dir,
        verbosity,
    } = Arguments::from_args();

    rusty_hydra::cli::setup(verbosity);

    log::info!(r#"opening "{}""#, area.display());
    // Open a buffered view into the csv file.
    let mut csv = csv::Reader::from_reader(BufReader::new(File::open(&area)?));

    // Check that its headers are as expected.
    let headers: Vec<_> = csv.headers()?.iter().collect();
    if headers != EXPECTED_HEADERS {
        return Err(anyhow::anyhow!(
            "expected: {:?} got: {:?}",
            EXPECTED_HEADERS,
            headers
        ));
    }
    log::info!("headers validated");

    log::info!("loading csv file");
    // Parse the csv file.
    let records = csv.deserialize().collect::<Result<Vec<InputRecord>, _>>()?;
    log::info!("csv file loaded");

    log::info!("creating rasters in memory");
    let rasters = records.rasters((ra, dec), step);
    log::info!(r#"saving rasters to {}"#, output_dir.display());
    for ((ra, dec), records) in rasters {
        let path = format!(
            "{prefix}_{ra}.0_{dec}.0.csv",
            prefix = prefix,
            ra = ra,
            dec = dec
        );

        let output_path = output_dir.join(path);

        let mut writer = csv::Writer::from_path(output_path)?;
        for record in records {
            writer.serialize(&record)?;
        }
    }

    // buffer open csv file
    // parse contents to relevant structure
    // regenerate sub-csv files based on raster properties formed from the regions
    // within the output_dir

    Ok(())
}

pub trait Rasterize<K, V> {
    fn rasters(self, start: K, step: usize) -> HashMap<K, V>;
}

impl Rasterize<(i64, i64), Vec<OutputRecord>> for Vec<InputRecord> {
    fn rasters(self, start: (i64, i64), step: usize) -> HashMap<(i64, i64), Vec<OutputRecord>> {
        fn bucket(x: f64, start: i64, step: usize) -> f64 {
            ((x - start as f64).floor() as usize / step) as f64 * step as f64 + start as f64
        }
        let mut buckets: HashMap<_, Vec<OutputRecord>> = HashMap::new();

        let records = self.into_iter().filter_map(|record| {
            if record.parallax == None
                || record.pmra == None
                || record.pmdec == None
                || record.parallax.unwrap() < 0.
            {
                None
            } else {
                Some(OutputRecord::from(record))
            }
        });

        for record in records {
            // Figure out the bucket
            let ra = bucket(record.ra, start.0, step) as i64;
            let dec = bucket(record.dec, start.1, step) as i64;

            let entry = buckets.entry((ra, dec)).or_default();
            entry.push(record);
        }

        buckets
    }
}
