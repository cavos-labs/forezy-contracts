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
        title: ByteArray,
        description: ByteArray,
        outcome_a_text: ByteArray,
        outcome_b_text: ByteArray,
        resolution_time: u64,
        initial_liquidity: u256
    ) -> u256;
    
    // Market information
    fn get_market_details(self: @TContractState, market_id: u256) -> Market;
    fn get_all_market_ids(self: @TContractState) -> Array<u256>;
    fn get_market_count(self: @TContractState) -> u256;
    
    // Share trading
    fn buy_shares(ref self: TContractState, market_id: u256, is_outcome_a: bool, amount_to_spend: u256) -> u256;
    fn get_share_price(self: @TContractState, market_id: u256, is_outcome_a: bool) -> u256;
    fn calculate_shares_for_amount(self: @TContractState, market_id: u256, is_outcome_a: bool, amount: u256) -> u256;
    fn get_user_shares(self: @TContractState, user: ContractAddress, market_id: u256, is_outcome_a: bool) -> u256;
    
    // Market resolution
    fn resolve_market(ref self: TContractState, market_id: u256, winning_outcome_is_a: bool);
    fn claim_winnings(ref self: TContractState, market_id: u256) -> u256;
    
    // Utility functions
    fn get_token_address(self: @TContractState) -> ContractAddress;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Market {
    pub id: u256,
    pub title: ByteArray,
    pub description: ByteArray,
    pub outcome_a_text: ByteArray,
    pub outcome_b_text: ByteArray,
    pub resolution_time: u64,
    pub resolved_outcome: u8, // 0 = unresolved, 1 = outcome A, 2 = outcome B
    pub creator: ContractAddress,
    pub total_liquidity: u256,
    pub total_shares_a: u256,
    pub total_shares_b: u256,
    pub created_at: u64,
} 