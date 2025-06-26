use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::{set_caller_address, set_block_timestamp};

use forezy_contracts::prediction_market::PredictionMarket;
use forezy_contracts::interfaces::{IPredictionMarketDispatcher, IPredictionMarketDispatcherTrait};

fn setup() -> (IPredictionMarketDispatcher, ContractAddress, ContractAddress) {
    // Mock ERC20 token address (in real tests, you'd deploy a real ERC20)
    let token_address = contract_address_const::<0x1234>();
    let owner = contract_address_const::<0x5678>();
    let user = contract_address_const::<0x9abc>();
    
    // For this test, we'll just create a mock dispatcher
    // In real tests with starknet foundry, you'd deploy the actual contract
    let contract_address = contract_address_const::<0xdead>();
    let dispatcher = IPredictionMarketDispatcher { contract_address };
    
    (dispatcher, owner, user)
}

#[test]
fn test_market_creation() {
    let (dispatcher, owner, _) = setup();
    
    // Set caller as owner
    set_caller_address(owner);
    set_block_timestamp(1000);
    
    // Create a market
    let market_id = dispatcher.create_market(
        "Will Bitcoin reach $100k by end of 2024?",
        "A prediction market for Bitcoin price",
        "Yes - Bitcoin will reach $100k",
        "No - Bitcoin will not reach $100k",
        2000, // resolution time
        1000000 // initial liquidity
    );
    
    assert(market_id == 1, 'Market ID should be 1');
    
    // Check market details
    let market = dispatcher.get_market_details(1);
    assert(market.id == 1, 'Market ID should match');
    assert(market.creator == owner, 'Creator should match');
    assert(market.total_liquidity == 1000000, 'Liquidity should match');
    assert(market.resolved_outcome == 0, 'Should be unresolved');
}

#[test]
fn test_deposit_and_withdraw() {
    let (dispatcher, owner, user) = setup();
    
    // Set caller as user
    set_caller_address(user);
    
    // Test deposit (note: in real test, you'd need to mock ERC20 transfer)
    // This test would fail without proper ERC20 mock, but shows the structure
    
    // Check initial balance
    let initial_balance = dispatcher.get_balance(user);
    assert(initial_balance == 0, 'Initial balance should be 0');
    
    // In a real test with ERC20 mock:
    // dispatcher.deposit(1000);
    // let new_balance = dispatcher.get_balance(user);
    // assert(new_balance == 1000, 'Balance should be 1000 after deposit');
}

#[test]
fn test_market_resolution() {
    let (dispatcher, owner, _) = setup();
    
    set_caller_address(owner);
    set_block_timestamp(1000);
    
    // Create a market
    let market_id = dispatcher.create_market(
        "Test Market",
        "Test Description",
        "Yes",
        "No",
        1500, // resolution time
        1000000
    );
    
    // Move time forward past resolution time
    set_block_timestamp(1600);
    
    // Resolve the market
    dispatcher.resolve_market(market_id, true); // Yes wins
    
    // Check market is resolved
    let market = dispatcher.get_market_details(market_id);
    assert(market.resolved_outcome == 1, 'Should be resolved to outcome A');
}

#[test]
fn test_share_price_calculation() {
    let (dispatcher, owner, _) = setup();
    
    set_caller_address(owner);
    set_block_timestamp(1000);
    
    // Create a market
    let market_id = dispatcher.create_market(
        "Test Market",
        "Test Description", 
        "Yes",
        "No",
        2000,
        1000000
    );
    
    // Get initial prices (should be 50/50)
    let price_a = dispatcher.get_share_price(market_id, true);
    let price_b = dispatcher.get_share_price(market_id, false);
    
    // Prices should be equal initially (50/50 split)
    assert(price_a == price_b, 'Initial prices should be equal');
    
    // Calculate shares for amount
    let shares_for_1000 = dispatcher.calculate_shares_for_amount(market_id, true, 1000);
                assert(shares_for_1000 > 0, 'Should calc positive shares');
}

#[test] 
fn test_get_all_markets() {
    let (dispatcher, owner, _) = setup();
    
    set_caller_address(owner);
    set_block_timestamp(1000);
    
    // Initially no markets
    assert(dispatcher.get_market_count() == 0, 'Should start with 0 markets');
    
    // Create two markets
    dispatcher.create_market("Market 1", "Description 1", "Yes", "No", 2000, 1000000);
    dispatcher.create_market("Market 2", "Description 2", "Yes", "No", 2000, 1000000);
    
    // Check market count
    assert(dispatcher.get_market_count() == 2, 'Should have 2 markets');
    
    // Get all market IDs
    let market_ids = dispatcher.get_all_market_ids();
    assert(market_ids.len() == 2, 'Should return 2 market IDs');
    assert(*market_ids.at(0) == 1, 'First market ID should be 1');
    assert(*market_ids.at(1) == 2, 'Second market ID should be 2');
}

#[test]
#[should_panic(expected: ('Market does not exist',))]
fn test_invalid_market_access() {
    let (dispatcher, _, _) = setup();
    
    // Try to get details of non-existent market
    dispatcher.get_market_details(999);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_unauthorized_market_creation() {
    let (dispatcher, _, user) = setup();
    
    // Try to create market as non-owner
    set_caller_address(user);
    set_block_timestamp(1000);
    
    dispatcher.create_market(
        "Unauthorized Market",
        "Should fail",
        "Yes", 
        "No",
        2000,
        1000000
    );
} 