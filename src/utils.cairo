// Utility functions for AMM calculations and market operations

pub const PRECISION: u256 = 1000000; // 10^6 for precision in calculations
pub const MIN_LIQUIDITY: u256 = 1000; // Minimum liquidity to prevent division by zero

pub fn calculate_constant_product_price(
    total_shares_a: u256, 
    total_shares_b: u256, 
    is_outcome_a: bool
) -> u256 {
    // Simple constant product formula: price = other_shares / (this_shares + other_shares)
    if is_outcome_a {
        if total_shares_a + total_shares_b == 0 {
            return PRECISION / 2; // 50% initial price
        }
        (total_shares_b * PRECISION) / (total_shares_a + total_shares_b)
    } else {
        if total_shares_a + total_shares_b == 0 {
            return PRECISION / 2; // 50% initial price
        }
        (total_shares_a * PRECISION) / (total_shares_a + total_shares_b)
    }
}

pub fn calculate_shares_from_amount(
    total_shares_a: u256,
    total_shares_b: u256,
    amount: u256,
    is_outcome_a: bool
) -> u256 {
    // Using a simplified constant product AMM formula
    // shares = amount / price
    let price = calculate_constant_product_price(total_shares_a, total_shares_b, is_outcome_a);
    if price == 0 {
        return 0;
    }
    (amount * PRECISION) / price
}

pub fn calculate_winnings(
    user_shares: u256,
    total_winning_shares: u256,
    total_market_liquidity: u256
) -> u256 {
    if total_winning_shares == 0 {
        return 0;
    }
    (user_shares * total_market_liquidity) / total_winning_shares
}

pub fn is_market_active(resolution_time: u64, current_time: u64, resolved_outcome: u8) -> bool {
    resolved_outcome == 0 && current_time < resolution_time
}

pub fn is_market_resolved(resolved_outcome: u8) -> bool {
    resolved_outcome == 1 || resolved_outcome == 2
}

pub fn can_resolve_market(resolution_time: u64, current_time: u64, resolved_outcome: u8) -> bool {
    resolved_outcome == 0 && current_time >= resolution_time
} 