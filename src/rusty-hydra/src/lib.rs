pub mod cli;
pub mod stellar;
pub mod utils;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cluster() {
        let _universe = stellar::Universe::default();
    }
}
