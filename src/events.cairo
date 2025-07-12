use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct Deposit {
    #[key]
    pub user: ContractAddress,
    pub amount: u256,
    pub new_balance: u256,
}

#[derive(Drop, starknet::Event)]
pub struct DepositFeeCollected {
    #[key]
    pub user: ContractAddress,
    pub gross_amount: u256, // Total amount user deposited
    pub fee_amount: u256,   // Fee collected (1%)
    pub net_amount: u256,   // Amount credited to user (99%)
    pub maintenance_contract: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Withdraw {
    #[key]
    pub user: ContractAddress,
    pub amount: u256,
    pub new_balance: u256,
}

#[derive(Drop, starknet::Event)]
pub struct MarketCreated {
    #[key]
    pub market_id: u256,
    #[key]
    pub creator: ContractAddress,
    pub resolution_time: u64,
    pub initial_liquidity: u256,
}

#[derive(Drop, starknet::Event)]
pub struct BetPlaced {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub market_id: u256,
    pub is_outcome_a: bool,
    pub bet_amount: u256,
    pub new_percentage_a: u256, // Percentage for outcome A in basis points
    pub new_percentage_b: u256, // Percentage for outcome B in basis points
    pub total_liquidity: u256,
}

#[derive(Drop, starknet::Event)]
pub struct MarketResolved {
    #[key]
    pub market_id: u256,
    #[key]
    pub resolver: ContractAddress,
    pub winning_outcome_is_a: bool,
    pub resolved_at: u64,
}

#[derive(Drop, starknet::Event)]
pub struct WinningsClaimed {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub market_id: u256,
    pub winnings_amount: u256,
    pub bet_amount: u256, // User's original bet amount on winning outcome
} 