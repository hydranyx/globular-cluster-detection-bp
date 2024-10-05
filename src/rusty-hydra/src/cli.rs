pub fn setup(verbosity: u64) {
    // Make panics log to the logger.
    std::panic::set_hook(Box::new(|panic_info| log::error!("{}", panic_info)));

    let subscriber = log_subscriber::FmtSubscriber::builder()
        .with_ansi(atty::is(atty::Stream::Stdout))
        .with_max_level(match verbosity {
            0 => log::Level::INFO,
            1 => log::Level::DEBUG,
            _ => log::Level::TRACE,
        })
        .finish();

    log::subscriber::set_global_default(subscriber).expect("set default subscriber");
}
