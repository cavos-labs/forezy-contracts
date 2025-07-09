use starknet::ContractAddress;

// Import the contract modules
use forezy_contracts::prediction_market::PredictionMarket;
use forezy_contracts::interfaces::{IPredictionMarketDispatcher, IPredictionMarketDispatcherTrait};
use forezy_contracts::events::{Deposit, DepositFeeCollected, BetPlaced, MarketCreated, MarketResolved, WinningsClaimed};

// Import Mock ERC20 from src directory
use forezy_contracts::mock_erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

// Import snforge testing utilities
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    start_cheat_caller_address, stop_cheat_caller_address,
    start_cheat_block_timestamp, stop_cheat_block_timestamp,
    spy_events, EventSpyAssertionsTrait
};

// Test setup and deployment functions
fn deploy_mock_erc20() -> (IMockERC20Dispatcher, ContractAddress) {
    let contract = declare("MockERC20").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IMockERC20Dispatcher { contract_address };
    (dispatcher, contract_address)
}

fn deploy_prediction_market(token_address: ContractAddress, maintenance_contract: ContractAddress) -> (IPredictionMarketDispatcher, ContractAddress) {
    let contract = declare("PredictionMarket").unwrap().contract_class();
    let mut constructor_args = array![];
    
    // Serialize constructor arguments
    token_address.serialize(ref constructor_args);
    maintenance_contract.serialize(ref constructor_args);
    
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    let dispatcher = IPredictionMarketDispatcher { contract_address };
    (dispatcher, contract_address)
}

fn setup_contracts() -> (IMockERC20Dispatcher, IPredictionMarketDispatcher, ContractAddress, ContractAddress, ContractAddress) {
    // Create test addresses
    let user: ContractAddress = 0x456.try_into().unwrap();
    let maintenance_contract: ContractAddress = 0x789.try_into().unwrap();
    
    // Deploy mock ERC20
    let (erc20, erc20_address) = deploy_mock_erc20();
    
    // Deploy prediction market - the deployer will be the owner by default
    let (prediction_market, pm_address) = deploy_prediction_market(erc20_address, maintenance_contract);
    
    // Get the actual owner from the contract (which is the deployer)
    let owner = prediction_market.get_owner();
    
    (erc20, prediction_market, owner, user, maintenance_contract)
}

// Deposit and Fee Tests
#[test]
fn test_deposit_with_fee_collection() {
    let (erc20, prediction_market, owner, user, maintenance_contract) = setup_contracts();
    let mut spy = spy_events();
    
    // Mint tokens to user
    start_cheat_caller_address(erc20.contract_address, owner);
    erc20.mint(user, 1000);
    stop_cheat_caller_address(erc20.contract_address);
    
    // User approves prediction market
    start_cheat_caller_address(erc20.contract_address, user);
    erc20.approve(prediction_market.contract_address, 1000);
    stop_cheat_caller_address(erc20.contract_address);
    
    // User deposits 1000 tokens (should result in 10 fee, 990 credited)
    start_cheat_caller_address(prediction_market.contract_address, user);
    prediction_market.deposit(1000);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Check user balance (should be 990 after 1% fee)
    let user_balance = prediction_market.get_balance(user);
    assert(user_balance == 990, 'Wrong balance');
    
    // Check maintenance contract received fee
    let maintenance_balance = erc20.balance_of(maintenance_contract);
    assert(maintenance_balance == 10, 'No fee received');
    
    // Check contract has remaining amount (990)
    let contract_balance = erc20.balance_of(prediction_market.contract_address);
    assert(contract_balance == 990, 'Wrong contract balance');
    
    // Verify events
    let expected_deposit_event = PredictionMarket::Event::Deposit(
        Deposit { user, amount: 990, new_balance: 990 }
    );
    let expected_fee_event = PredictionMarket::Event::DepositFeeCollected(
        DepositFeeCollected {
            user,
            gross_amount: 1000,
            fee_amount: 10,
            net_amount: 990,
            maintenance_contract
        }
    );
    
    spy.assert_emitted(@array![
        (prediction_market.contract_address, expected_deposit_event),
        (prediction_market.contract_address, expected_fee_event)
    ]);
}

#[test]
fn test_withdraw() {
    let (erc20, prediction_market, owner, user, _) = setup_contracts();
    
    // Setup user with balance
    start_cheat_caller_address(erc20.contract_address, owner);
    erc20.mint(user, 1000);
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(erc20.contract_address, user);
    erc20.approve(prediction_market.contract_address, 1000);
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(prediction_market.contract_address, user);
    prediction_market.deposit(1000);
    
    // Withdraw 500
    prediction_market.withdraw(500);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Check balances
    let user_contract_balance = prediction_market.get_balance(user);
    assert(user_contract_balance == 490, 'Wrong balance'); // 990 - 500
    
    let user_token_balance = erc20.balance_of(user);
    assert(user_token_balance == 500, 'Wrong tokens');
}

// Market Creation Tests
#[test]
fn test_market_creation() {
    let (_, prediction_market, owner, _, _) = setup_contracts();
    let mut spy = spy_events();
    
    start_cheat_caller_address(prediction_market.contract_address, owner);
    start_cheat_block_timestamp(prediction_market.contract_address, 1000);
    
    let market_id = prediction_market.create_market(2000, 100000);
    
    stop_cheat_block_timestamp(prediction_market.contract_address);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    assert(market_id == 1, 'Wrong market ID');
    
    // Check market details
    let market = prediction_market.get_market_details(1);
    assert(market.id == 1, 'ID mismatch');
    assert(market.creator == owner, 'Creator mismatch');
    assert(market.resolution_time == 2000, 'Time mismatch');
    assert(market.total_liquidity == 0, 'Liquidity != 0');
    assert(market.total_percentage_a == 0, 'Percentage A != 0');
    assert(market.total_percentage_b == 0, 'Percentage B != 0');
    assert(market.resolved_outcome == 0, 'Already resolved');
    
    // Verify event
    let expected_event = PredictionMarket::Event::MarketCreated(
        MarketCreated {
            market_id: 1,
            creator: owner,
            resolution_time: 2000,
            initial_liquidity: 100000
        }
    );
    spy.assert_emitted(@array![(prediction_market.contract_address, expected_event)]);
}

// Betting Tests
#[test]
fn test_place_bet_and_percentages() {
    let (erc20, prediction_market, owner, user, _) = setup_contracts();
    let mut spy = spy_events();
    
    // Setup market
    start_cheat_caller_address(prediction_market.contract_address, owner);
    start_cheat_block_timestamp(prediction_market.contract_address, 1000);
    let market_id = prediction_market.create_market(2000, 0);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Setup user with tokens and balance
    start_cheat_caller_address(erc20.contract_address, owner);
    erc20.mint(user, 1000);
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(erc20.contract_address, user);
    erc20.approve(prediction_market.contract_address, 1000);
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(prediction_market.contract_address, user);
    prediction_market.deposit(1000); // User gets 990 after fee
    
    // Place bet: 300 on outcome A
    prediction_market.place_bet(market_id, true, 300);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Check user balance decreased
    let user_balance = prediction_market.get_balance(user);
    assert(user_balance == 690, 'Wrong balance'); // 990 - 300
    
    // Check bet amount
    let user_bet = prediction_market.get_user_bet(user, market_id, true);
    assert(user_bet == 300, 'Bet not recorded');
    
    // Check total bets
    let total_bets_a = prediction_market.get_total_bets_for_outcome(market_id, true);
    assert(total_bets_a == 300, 'Wrong total bets');
    
    // Check market percentages (300 out of 300 = 10000 basis points = 100%)
    let (percentage_a, percentage_b) = prediction_market.get_market_percentages(market_id);
    assert(percentage_a == 10000, 'Wrong % A'); // 10000 basis points
    assert(percentage_b == 0, 'Wrong % B');
    
    // Verify event
    let expected_event = PredictionMarket::Event::BetPlaced(
        BetPlaced {
            user,
            market_id,
            is_outcome_a: true,
            bet_amount: 300,
            new_percentage_a: 10000,
            new_percentage_b: 0,
            total_liquidity: 300
        }
    );
    spy.assert_emitted(@array![(prediction_market.contract_address, expected_event)]);
}

#[test]
fn test_multiple_bets_percentage_calculation() {
    let (erc20, prediction_market, owner, user, _) = setup_contracts();
    
    // Setup market
    start_cheat_caller_address(prediction_market.contract_address, owner);
    start_cheat_block_timestamp(prediction_market.contract_address, 1000);
    let market_id = prediction_market.create_market(2000, 0);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Setup user with tokens
    start_cheat_caller_address(erc20.contract_address, owner);
    erc20.mint(user, 2000);
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(erc20.contract_address, user);
    erc20.approve(prediction_market.contract_address, 2000);
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(prediction_market.contract_address, user);
    prediction_market.deposit(2000); // User gets 1980 after fee
    
    // Place multiple bets: 300 on A, 700 on B (total 1000)
    prediction_market.place_bet(market_id, true, 300);   // 30% on A
    prediction_market.place_bet(market_id, false, 700);  // 70% on B
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Check percentages: 300/1000 = 30% = 3000 basis points, 700/1000 = 70% = 7000 basis points
    let (percentage_a, percentage_b) = prediction_market.get_market_percentages(market_id);
    assert(percentage_a == 3000, 'Wrong % A'); // 3000 basis points
    assert(percentage_b == 7000, 'Wrong % B'); // 7000 basis points
    
    // Check total bets
    let total_a = prediction_market.get_total_bets_for_outcome(market_id, true);
    let total_b = prediction_market.get_total_bets_for_outcome(market_id, false);
    assert(total_a == 300, 'Wrong total A');
    assert(total_b == 700, 'Wrong total B');
}

// Market Resolution Tests
#[test]
fn test_market_resolution() {
    let (_, prediction_market, owner, _, _) = setup_contracts();
    let mut spy = spy_events();
    
    start_cheat_caller_address(prediction_market.contract_address, owner);
    start_cheat_block_timestamp(prediction_market.contract_address, 1000);
    let market_id = prediction_market.create_market(1500, 0);
    
    // Move time past resolution
    start_cheat_block_timestamp(prediction_market.contract_address, 1600);
    
    prediction_market.resolve_market(market_id, true); // A wins
    
    stop_cheat_block_timestamp(prediction_market.contract_address);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Check market is resolved
    let market = prediction_market.get_market_details(market_id);
    assert(market.resolved_outcome == 1, 'Not resolved');
    
    // Verify event
    let expected_event = PredictionMarket::Event::MarketResolved(
        MarketResolved {
            market_id,
            resolver: owner,
            winning_outcome_is_a: true,
            resolved_at: 1600
        }
    );
    spy.assert_emitted(@array![(prediction_market.contract_address, expected_event)]);
}

#[test]
fn test_claim_winnings() {
    let (erc20, prediction_market, owner, user, _) = setup_contracts();
    let mut spy = spy_events();
    
    // Setup market and bets
    start_cheat_caller_address(prediction_market.contract_address, owner);
    start_cheat_block_timestamp(prediction_market.contract_address, 1000);
    let market_id = prediction_market.create_market(1500, 0);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // User deposits and bets
    start_cheat_caller_address(erc20.contract_address, owner);
    erc20.mint(user, 1000);
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(erc20.contract_address, user);
    erc20.approve(prediction_market.contract_address, 1000);
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(prediction_market.contract_address, user);
    prediction_market.deposit(1000);
    prediction_market.place_bet(market_id, true, 300);  // Bet on A
    prediction_market.place_bet(market_id, false, 600); // Bet on B
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Resolve market (A wins)
    start_cheat_caller_address(prediction_market.contract_address, owner);
    start_cheat_block_timestamp(prediction_market.contract_address, 1600);
    prediction_market.resolve_market(market_id, true);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Claim winnings
    start_cheat_caller_address(prediction_market.contract_address, user);
    let winnings = prediction_market.claim_winnings(market_id);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // User bet 300 on A, total bets 900, user should get all liquidity since only user bet on A
    assert(winnings == 900, 'Wrong winnings');
    
    // Check user balance increased
    let user_balance = prediction_market.get_balance(user);
    // Initial: 990 - 300 - 600 = 90, after winnings: 90 + 900 = 990
    assert(user_balance == 990, 'Wrong final balance');
    
    // Verify event
    let expected_event = PredictionMarket::Event::WinningsClaimed(
        WinningsClaimed {
            user,
            market_id,
            winnings_amount: 900,
            bet_amount: 300
        }
    );
    spy.assert_emitted(@array![(prediction_market.contract_address, expected_event)]);
}

// Maintenance Contract Management Tests
#[test]
fn test_maintenance_contract_management() {
    let (_, prediction_market, owner, _, _) = setup_contracts();
    let new_maintenance: ContractAddress = 0x999.try_into().unwrap();
    
    // Only owner can set maintenance contract
    start_cheat_caller_address(prediction_market.contract_address, owner);
    prediction_market.set_maintenance_contract(new_maintenance);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Check maintenance contract was updated
    let current_maintenance = prediction_market.get_maintenance_contract();
    assert(current_maintenance == new_maintenance, 'Not updated');
}

// Error Tests
#[test]
#[should_panic(expected: 'Amount must be greater than 0')]
fn test_deposit_zero_amount() {
    let (_, prediction_market, _, user, _) = setup_contracts();
    
    start_cheat_caller_address(prediction_market.contract_address, user);
    prediction_market.deposit(0);
    stop_cheat_caller_address(prediction_market.contract_address);
}

#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_withdraw_insufficient_balance() {
    let (_, prediction_market, _, user, _) = setup_contracts();
    
    start_cheat_caller_address(prediction_market.contract_address, user);
    prediction_market.withdraw(1000);
    stop_cheat_caller_address(prediction_market.contract_address);
}

#[test]
#[should_panic(expected: 'Market does not exist')]
fn test_invalid_market_access() {
    let (_, prediction_market, _, _, _) = setup_contracts();
    
    prediction_market.get_market_details(999);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_unauthorized_market_resolution() {
    let (_, prediction_market, owner, user, _) = setup_contracts();
    
    start_cheat_caller_address(prediction_market.contract_address, owner);
    start_cheat_block_timestamp(prediction_market.contract_address, 1000);
    let market_id = prediction_market.create_market(1500, 0);
    stop_cheat_caller_address(prediction_market.contract_address);
    
    // Try to resolve as non-owner
    start_cheat_caller_address(prediction_market.contract_address, user);
    start_cheat_block_timestamp(prediction_market.contract_address, 1600);
    prediction_market.resolve_market(market_id, true);
    stop_cheat_caller_address(prediction_market.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_unauthorized_maintenance_contract_update() {
    let (_, prediction_market, _, user, _) = setup_contracts();
    let new_maintenance: ContractAddress = 0x999.try_into().unwrap();
    
    start_cheat_caller_address(prediction_market.contract_address, user);
    prediction_market.set_maintenance_contract(new_maintenance);
    stop_cheat_caller_address(prediction_market.contract_address);
} 