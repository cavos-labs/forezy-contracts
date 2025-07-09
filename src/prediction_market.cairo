// Module-level imports are kept minimal

#[starknet::contract]
pub mod PredictionMarket {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::{get_caller_address, get_block_timestamp, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    use super::super::interfaces::{IPredictionMarket, Market};
    use super::super::events::{Deposit, DepositFeeCollected, Withdraw, MarketCreated, BetPlaced, MarketResolved, WinningsClaimed};
    use super::super::utils::{
        calculate_outcome_percentage, calculate_winnings_from_bet,
        is_market_active, is_market_resolved, can_resolve_market,
        calculate_fee, calculate_net_amount, DEPOSIT_FEE_BASIS_POINTS
    };

    #[storage]
    pub struct Storage {
        // Token used for deposits/withdrawals
        token_address: ContractAddress,
        
        // Contract owner
        owner: ContractAddress,
        
        // Maintenance contract for fee collection
        maintenance_contract: ContractAddress,
        
        // User balances (address => amount)
        user_balances: Map<ContractAddress, u256>,
        
        // Market storage (market_id => Market)
        markets: Map<u256, Market>,
        
        // Market count for generating unique IDs
        market_count: u256,
        
        // User bet amounts (user => market_id => is_outcome_a => bet_amount)
        user_bets: Map<(ContractAddress, u256, bool), u256>,
        
        // Track which users have claimed winnings for each market
        winnings_claimed: Map<(ContractAddress, u256), bool>,

        // Total bet amounts for each outcome (market_id => outcome => total_bets)
        total_bets_a: Map<u256, u256>,
        total_bets_b: Map<u256, u256>,
        
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deposit: Deposit,
        DepositFeeCollected: DepositFeeCollected,
        Withdraw: Withdraw,
        MarketCreated: MarketCreated,
        BetPlaced: BetPlaced,
        MarketResolved: MarketResolved,
        WinningsClaimed: WinningsClaimed,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        maintenance_contract: ContractAddress,
    ) {
        let caller = get_caller_address();
        self.token_address.write(token_address);
        self.maintenance_contract.write(maintenance_contract);
        self.owner.write(caller);
        self.market_count.write(0);
    }

    #[abi(embed_v0)]
    pub impl PredictionMarketImpl of IPredictionMarket<ContractState> {
        fn deposit(ref self: ContractState, amount: u256) {
            assert(amount > 0, 'Amount must be greater than 0');
            
            let caller = get_caller_address();
            let token = IERC20Dispatcher { contract_address: self.token_address.read() };
            let maintenance_contract = self.maintenance_contract.read();
            
            // Calculate fee (1%) and net amount (99%)
            let fee_amount = calculate_fee(amount, DEPOSIT_FEE_BASIS_POINTS);
            let net_amount = calculate_net_amount(amount, DEPOSIT_FEE_BASIS_POINTS);
            
            // Transfer full amount from user to this contract
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, 'Token transfer failed');
            
            // Transfer fee to maintenance contract
            if fee_amount > 0 && maintenance_contract != get_contract_address() {
                let fee_transfer_success = token.transfer(maintenance_contract, fee_amount);
                assert(fee_transfer_success, 'Fee transfer failed');
            }
            
            // Update user balance with net amount (after fee deduction)
            let current_balance = self.user_balances.entry(caller).read();
            let new_balance = current_balance + net_amount;
            self.user_balances.entry(caller).write(new_balance);
            
            // Emit deposit event
            self.emit(Event::Deposit(Deposit {
                user: caller,
                amount: net_amount, // Amount credited to user's balance
                new_balance
            }));
            
            // Emit fee collection event
            if fee_amount > 0 {
                self.emit(Event::DepositFeeCollected(DepositFeeCollected {
                    user: caller,
                    gross_amount: amount,
                    fee_amount,
                    net_amount,
                    maintenance_contract
                }));
            }
        }

        fn withdraw(ref self: ContractState, amount: u256) {
            assert(amount > 0, 'Amount must be greater than 0');
            
            let caller = get_caller_address();
            let current_balance = self.user_balances.entry(caller).read();
            assert(current_balance >= amount, 'Insufficient balance');
            
            // Update user balance
            let new_balance = current_balance - amount;
            self.user_balances.entry(caller).write(new_balance);
            
            // Transfer tokens from contract to user
            let token = IERC20Dispatcher { contract_address: self.token_address.read() };
            let success = token.transfer(caller, amount);
            assert(success, 'Token transfer failed');
            
            // Emit event
            self.emit(Event::Withdraw(Withdraw {
                user: caller,
                amount,
                new_balance
            }));
        }

        fn get_balance(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_balances.entry(user).read()
        }

        fn create_market(
            ref self: ContractState,
            resolution_time: u64,
            initial_liquidity: u256
        ) -> u256 {

            let caller = get_caller_address();

            assert(resolution_time > get_block_timestamp(), 'Invalid resolution time');
            
            // Generate new market ID
            let market_id = self.market_count.read() + 1;
            self.market_count.write(market_id);
            
            // Create market struct
            let market = Market {
                id: market_id,
                resolution_time,
                resolved_outcome: 0, // 0 = unresolved
                creator: caller,
                total_liquidity: 0,
                total_percentage_a: 0, // Start with 0% for both outcomes
                total_percentage_b: 0,
                created_at: get_block_timestamp(),
            };
            
            // Store market
            self.markets.entry(market_id).write(market);
            
            // Emit event
            self.emit(Event::MarketCreated(MarketCreated {
                market_id,
                creator: caller,
                resolution_time,
                initial_liquidity
            }));
            
            market_id
        }

        fn get_market_details(self: @ContractState, market_id: u256) -> Market {
            let market = self.markets.entry(market_id).read();
            assert(market.id != 0, 'Market does not exist');
            market
        }

        fn get_all_market_ids(self: @ContractState) -> Array<u256> {
            let mut market_ids = array![];
            let count = self.market_count.read();
            
            for i in 1..=count {
                market_ids.append(i);
            };
            
            market_ids
        }

        fn get_market_count(self: @ContractState) -> u256 {
            self.market_count.read()
        }

        fn place_bet(
            ref self: ContractState, 
            market_id: u256, 
            is_outcome_a: bool, 
            amount: u256
        ) {
            assert(amount > 0, 'Amount must be greater than 0');
            
            let caller = get_caller_address();
            let current_balance = self.user_balances.entry(caller).read();
            assert(current_balance >= amount, 'Insufficient balance');
            
            // Get market details
            let mut market = self.markets.entry(market_id).read();
            assert(market.id != 0, 'Market does not exist');
            
            // Check if market is active
            let current_time = get_block_timestamp();
            assert(is_market_active(market.resolution_time, current_time, market.resolved_outcome), 'Market not active');
            
            // Update user balance
            let new_balance = current_balance - amount;
            self.user_balances.entry(caller).write(new_balance);
            
            // Update user bet
            let current_bet = self.user_bets.entry((caller, market_id, is_outcome_a)).read();
            self.user_bets.entry((caller, market_id, is_outcome_a)).write(current_bet + amount);
            
            // Update total bets for the outcome
            if is_outcome_a {
                let current_total_a = self.total_bets_a.entry(market_id).read();
                self.total_bets_a.entry(market_id).write(current_total_a + amount);
            } else {
                let current_total_b = self.total_bets_b.entry(market_id).read();
                self.total_bets_b.entry(market_id).write(current_total_b + amount);
            }
            
            // Update market liquidity
            market.total_liquidity = market.total_liquidity + amount;
            
            // Calculate new percentages in basis points
            let total_a = self.total_bets_a.entry(market_id).read();
            let total_b = self.total_bets_b.entry(market_id).read();
            
            market.total_percentage_a = calculate_outcome_percentage(total_a, market.total_liquidity);
            market.total_percentage_b = calculate_outcome_percentage(total_b, market.total_liquidity);
            
            // Store updated market
            self.markets.entry(market_id).write(market);
            
            // Emit event
            self.emit(Event::BetPlaced(BetPlaced {
                user: caller,
                market_id,
                is_outcome_a,
                bet_amount: amount,
                new_percentage_a: market.total_percentage_a,
                new_percentage_b: market.total_percentage_b,
                total_liquidity: market.total_liquidity,
            }));
        }

        fn get_market_percentages(self: @ContractState, market_id: u256) -> (u256, u256) {
            let market = self.markets.entry(market_id).read();
            assert(market.id != 0, 'Market does not exist');
            
            (market.total_percentage_a, market.total_percentage_b)
        }

        fn get_user_bet(
            self: @ContractState,
            user: ContractAddress,
            market_id: u256,
            is_outcome_a: bool
        ) -> u256 {
            self.user_bets.entry((user, market_id, is_outcome_a)).read()
        }

        fn get_total_bets_for_outcome(self: @ContractState, market_id: u256, is_outcome_a: bool) -> u256 {
            if is_outcome_a {
                self.total_bets_a.entry(market_id).read()
            } else {
                self.total_bets_b.entry(market_id).read()
            }
        }

        fn resolve_market(ref self: ContractState, market_id: u256, winning_outcome_is_a: bool) {
            // Only owner can resolve markets (Ideally this would be with an oracle)
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Caller is not the owner');
            
            let mut market = self.markets.entry(market_id).read();
            assert(market.id != 0, 'Market does not exist');
            
            let current_time = get_block_timestamp();
            assert(can_resolve_market(market.resolution_time, current_time, market.resolved_outcome), 'Cannot resolve market');
            
            // Set resolved outcome
            market.resolved_outcome = if winning_outcome_is_a { 1 } else { 2 };
            self.markets.entry(market_id).write(market);
            
            // Emit event
            self.emit(Event::MarketResolved(MarketResolved {
                market_id,
                resolver: get_caller_address(),
                winning_outcome_is_a,
                resolved_at: current_time
            }));
        }

        fn claim_winnings(ref self: ContractState, market_id: u256) -> u256 {
            let caller = get_caller_address();
            let market = self.markets.entry(market_id).read();
            assert(market.id != 0, 'Market does not exist');
            assert(is_market_resolved(market.resolved_outcome), 'Market not resolved');
            
            // Check if user has already claimed
            let has_claimed = self.winnings_claimed.entry((caller, market_id)).read();
            assert(!has_claimed, 'Winnings already claimed');
            
            // Determine winning outcome
            let winning_outcome_is_a = market.resolved_outcome == 1;
            
            // Get user's bet on winning outcome
            let user_winning_bet = self.user_bets.entry((caller, market_id, winning_outcome_is_a)).read();
            assert(user_winning_bet > 0, 'No winning bet to claim');
            
            // Calculate winnings
            let total_winning_bets = if winning_outcome_is_a {
                self.total_bets_a.entry(market_id).read()
            } else {
                self.total_bets_b.entry(market_id).read()
            };
            
            let winnings = calculate_winnings_from_bet(
                user_winning_bet,
                total_winning_bets,
                market.total_liquidity
            );
            
            // Mark as claimed
            self.winnings_claimed.entry((caller, market_id)).write(true);
            
            // Add winnings to user balance
            let current_balance = self.user_balances.entry(caller).read();
            self.user_balances.entry(caller).write(current_balance + winnings);
            
            // Emit event
            self.emit(Event::WinningsClaimed(WinningsClaimed {
                user: caller,
                market_id,
                winnings_amount: winnings,
                bet_amount: user_winning_bet
            }));
            
            winnings
        }

        fn get_token_address(self: @ContractState) -> ContractAddress {
            self.token_address.read()
        }

        fn get_maintenance_contract(self: @ContractState) -> ContractAddress {
            self.maintenance_contract.read()
        }

        fn set_maintenance_contract(ref self: ContractState, new_maintenance_contract: ContractAddress) {
            // Only owner can change maintenance contract
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Caller is not the owner');
            
            self.maintenance_contract.write(new_maintenance_contract);
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }
} 