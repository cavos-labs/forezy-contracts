// Utility functions for basis points calculations and market operations

pub const BASIS_POINTS_SCALE: u256 = 10000; // 10000 basis points = 100%
pub const DEPOSIT_FEE_BASIS_POINTS: u256 = 100; // 1% fee = 100 basis points
pub const MIN_LIQUIDITY: u256 = 1000; // Minimum liquidity to prevent division by zero

// Calculate percentage in basis points for an outcome
// Example: if 30 ETH out of 100 ETH total, returns 3000 basis points (30%)
pub fn calculate_outcome_percentage(
    outcome_amount: u256,
    total_amount: u256
) -> u256 {
    if total_amount == 0 {
        return 0;
    }
    (outcome_amount * BASIS_POINTS_SCALE) / total_amount
}

// Calculate the complementary percentage (the other outcome)
pub fn calculate_complementary_percentage(percentage: u256) -> u256 {
    if percentage > BASIS_POINTS_SCALE {
        return 0;
    }
    BASIS_POINTS_SCALE - percentage
}

// Calculate winnings based on user bet amount and the total pool
pub fn calculate_winnings_from_bet(
    user_bet_amount: u256,
    total_winning_bets: u256,
    total_market_liquidity: u256
) -> u256 {
    if total_winning_bets == 0 {
        return 0;
    }
    (user_bet_amount * total_market_liquidity) / total_winning_bets
}

// Check if percentage is valid (0 to 10000 basis points)
pub fn is_valid_percentage(percentage: u256) -> bool {
    percentage <= BASIS_POINTS_SCALE
}

// Convert basis points to regular percentage (for display purposes)
// Example: 3000 basis points -> 30 (representing 30%)
pub fn basis_points_to_percentage(basis_points: u256) -> u256 {
    basis_points / 100
}

// Convert regular percentage to basis points
// Example: 30 (representing 30%) -> 3000 basis points
pub fn percentage_to_basis_points(percentage: u256) -> u256 {
    percentage * 100
}

// Calculate fee from amount using basis points
// Example: calculate_fee(1000, 100) returns 10 (1% of 1000)
pub fn calculate_fee(amount: u256, fee_basis_points: u256) -> u256 {
    (amount * fee_basis_points) / BASIS_POINTS_SCALE
}

// Calculate net amount after fee deduction
// Example: calculate_net_amount(1000, 100) returns 990 (1000 - 1% fee)
pub fn calculate_net_amount(amount: u256, fee_basis_points: u256) -> u256 {
    let fee = calculate_fee(amount, fee_basis_points);
    amount - fee
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