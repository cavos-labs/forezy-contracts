use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct Deposit {
    #[key]
    pub user: ContractAddress,
    pub amount: u256,
    pub new_balance: u256,
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
    pub title: ByteArray,
    pub description: ByteArray,
    pub outcome_a_text: ByteArray,
    pub outcome_b_text: ByteArray,
    pub resolution_time: u64,
    pub initial_liquidity: u256,
}

#[derive(Drop, starknet::Event)]
pub struct SharesBought {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub market_id: u256,
    pub is_outcome_a: bool,
    pub amount_spent: u256,
    pub shares_received: u256,
    pub new_price: u256,
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
    pub shares_held: u256,
} 