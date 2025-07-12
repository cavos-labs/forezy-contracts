use starknet::ContractAddress;

#[starknet::interface]
pub trait IPredictionMarket<TContractState> {
    // User balance management
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, amount: u256);
    fn get_balance(self: @TContractState, user: ContractAddress) -> u256;
    
    // Market creation and management
    fn create_market(
        ref self: TContractState,
        resolution_time: u64,
        initial_liquidity: u256
    ) -> u256;
    
    // Market information
    fn get_market_details(self: @TContractState, market_id: u256) -> Market;
    fn get_all_market_ids(self: @TContractState) -> Array<u256>;
    fn get_market_count(self: @TContractState) -> u256;
    
    // Betting functions (replacing share trading)
    fn place_bet(ref self: TContractState, market_id: u256, is_outcome_a: bool, amount: u256);
    fn get_market_percentages(self: @TContractState, market_id: u256) -> (u256, u256); // Returns (percentage_a, percentage_b) in basis points
    fn get_user_bet(self: @TContractState, user: ContractAddress, market_id: u256, is_outcome_a: bool) -> u256;
    fn get_total_bets_for_outcome(self: @TContractState, market_id: u256, is_outcome_a: bool) -> u256;
    
    // Market resolution
    fn resolve_market(ref self: TContractState, market_id: u256, winning_outcome_is_a: bool);
    fn claim_winnings(ref self: TContractState, market_id: u256) -> u256;
    
    // Utility functions
    fn get_token_address(self: @TContractState) -> ContractAddress;
    fn get_maintenance_contract(self: @TContractState) -> ContractAddress;
    fn set_maintenance_contract(ref self: TContractState, new_maintenance_contract: ContractAddress);
    fn get_owner(self: @TContractState) -> ContractAddress;
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Market {
    pub id: u256,
    pub resolution_time: u64,
    pub resolved_outcome: u8, // 0 = unresolved, 1 = outcome A, 2 = outcome B
    pub creator: ContractAddress,
    pub total_liquidity: u256,
    pub total_percentage_a: u256, // Percentage in basis points (10000 = 100%)
    pub total_percentage_b: u256, // Percentage in basis points (10000 = 100%)
    pub created_at: u64,
} 