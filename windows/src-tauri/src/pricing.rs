// Sonnet 4.6 pricing per token — keep in sync with the macOS app
// (TokenTracker/TokenTracker/Data/ClaudeCodeReader.swift).
pub const INPUT_PRICE: f64 = 3.00 / 1_000_000.0;
pub const OUTPUT_PRICE: f64 = 15.00 / 1_000_000.0;
pub const CACHE_CREATE_PRICE: f64 = 3.75 / 1_000_000.0;
pub const CACHE_READ_PRICE: f64 = 0.30 / 1_000_000.0;

pub fn entry_cost(input: u64, output: u64, cache_create: u64, cache_read: u64) -> f64 {
    input as f64 * INPUT_PRICE
        + output as f64 * OUTPUT_PRICE
        + cache_create as f64 * CACHE_CREATE_PRICE
        + cache_read as f64 * CACHE_READ_PRICE
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_million_of_each_token_type() {
        let cost = entry_cost(1_000_000, 1_000_000, 1_000_000, 1_000_000);
        assert!((cost - (3.00 + 15.00 + 3.75 + 0.30)).abs() < 1e-9);
    }

    #[test]
    fn zero_tokens_zero_cost() {
        assert_eq!(entry_cost(0, 0, 0, 0), 0.0);
    }
}
