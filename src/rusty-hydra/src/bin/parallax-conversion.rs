use std::fs::File;
use std::io::BufReader;

use structopt::StructOpt;

/// Process the stats associated with some set of files.
#[derive(Debug, StructOpt)]
struct Arguments {
    /// CSV file to extract parallax info.
    #[structopt(required = true)]
    csv_file: std::path::PathBuf,

    /// Set output to be in json.
    #[structopt(global = true, short, long)]
    json: bool,

    /// Set verbosity (-v, -vv, -vvv, etc...).
    #[structopt(global = true, short, parse(from_occurrences))]
    verbosity: u64,
}

fn main() {
    let Arguments {
        csv_file,
        json,
        verbosity,
    } = Arguments::from_args();

    rusty_hydra::cli::setup(verbosity);

    const EXPECTED_HEADERS: &[&str] = &[
        "source_id",
        "ra",
        "dec",
        "parallax",
        "pmra",
        "pmdec",
        "phot_g_mean_mag",
    ];

    // Prepare a buffered view into the data.
    let file = File::open(&csv_file).expect("opened file");
    let reader = BufReader::new(file);
    // Open that reader as a csv file.
    let mut csv = csv::Reader::from_reader(reader);

    // Check that the headers match.
    let headers: Vec<_> = csv.headers().unwrap().iter().collect();
    if headers != EXPECTED_HEADERS {
        panic!("expected: {:?} got: {:?}", EXPECTED_HEADERS, headers);
    }

    // create intermediary type to reduce verbosity.
    #[derive(serde::Deserialize, serde::Serialize, Debug)]
    struct InputRecord {
        source_id: usize,
        ra: f64,
        dec: f64,
        parallax: Option<f64>,
        pmra: Option<f64>,
        pmdec: Option<f64>,
        phot_g_mean_mag: f64,
    }

    #[derive(serde::Deserialize, serde::Serialize, Debug)]
    struct OutputRecord {
        parallax: f64,
    }

    // Iterate through each record to pull out the bare minimum data.
    let records = csv
        .deserialize()
        .collect::<Result<Vec<InputRecord>, _>>()
        .unwrap();

    let records: Vec<_> = records
        .into_iter()
        .filter_map(|record| {
            if record.parallax == None
                || record.pmra == None
                || record.pmdec == None
                || record.parallax.unwrap() < 0.
            {
                None
            } else {
                Some(OutputRecord {
                    parallax: record.parallax.unwrap(),
                })
            }
        })
        .collect();

    // output the bucketing
    if json {
        println!("{}", serde_json::ser::to_string_pretty(&records).unwrap());
    } else {
        println!("{:#?}", records);
    }
}
