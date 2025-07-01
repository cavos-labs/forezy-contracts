// Module-level imports are kept minimal

#[starknet::contract]
pub mod PredictionMarket {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::{get_caller_address, get_block_timestamp, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    use super::super::interfaces::{IPredictionMarket, Market};
    use super::super::events::{Deposit, Withdraw, MarketCreated, SharesBought, MarketResolved, WinningsClaimed};
    use super::super::utils::{
        calculate_constant_product_price, calculate_shares_from_amount, calculate_winnings,
        is_market_active, is_market_resolved, can_resolve_market
    };

    #[storage]
    pub struct Storage {
        // Token used for deposits/withdrawals
        token_address: ContractAddress,
        
        // Contract owner
        owner: ContractAddress,
        
        // User balances (address => amount)
        user_balances: Map<ContractAddress, u256>,
        
        // Market storage (market_id => Market)
        markets: Map<u256, Market>,
        
        // Market count for generating unique IDs
        market_count: u256,
        
        // User share holdings (user => market_id => is_outcome_a => shares)
        user_shares: Map<(ContractAddress, u256, bool), u256>,
        
        // Track which users have claimed winnings for each market
        winnings_claimed: Map<(ContractAddress, u256), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
        MarketCreated: MarketCreated,
        SharesBought: SharesBought,
        MarketResolved: MarketResolved,
        WinningsClaimed: WinningsClaimed,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        owner: ContractAddress
    ) {
        self.token_address.write(token_address);
        self.owner.write(owner);
        self.market_count.write(0);
    }

    #[abi(embed_v0)]
    pub impl PredictionMarketImpl of IPredictionMarket<ContractState> {
        fn deposit(ref self: ContractState, amount: u256) {
            assert(amount > 0, 'Amount must be greater than 0');
            
            let caller = get_caller_address();
            let token = IERC20Dispatcher { contract_address: self.token_address.read() };
            
            // Transfer tokens from user to contract
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success, 'Token transfer failed');
            
            // Update user balance
            let current_balance = self.user_balances.entry(caller).read();
            let new_balance = current_balance + amount;
            self.user_balances.entry(caller).write(new_balance);
            
            // Emit event
            self.emit(Event::Deposit(Deposit {
                user: caller,
                amount,
                new_balance
            }));
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
            title: ByteArray,
            description: ByteArray,
            outcome_a_text: ByteArray,
            outcome_b_text: ByteArray,
            resolution_time: u64,
            initial_liquidity: u256
        ) -> u256 {
            // Only owner can create markets
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'Caller is not the owner');
            
            assert(initial_liquidity > 0, 'Initial liquidity must be > 0');
            assert(resolution_time > get_block_timestamp(), 'Invalid resolution time');
            
            let current_balance = self.user_balances.entry(caller).read();
            assert(current_balance >= initial_liquidity, 'Insufficient balance');
            
            // Generate new market ID
            let market_id = self.market_count.read() + 1;
            self.market_count.write(market_id);
            
            // Create market struct
            let market = Market {
                id: market_id,
                title: title.clone(),
                description: description.clone(),
                outcome_a_text: outcome_a_text.clone(),
                outcome_b_text: outcome_b_text.clone(),
                resolution_time,
                resolved_outcome: 0, // 0 = unresolved
                creator: caller,
                total_liquidity: initial_liquidity,
                total_shares_a: initial_liquidity / 2, // Start with 50/50 split
                total_shares_b: initial_liquidity / 2,
                created_at: get_block_timestamp(),
            };
            
            // Store market
            self.markets.entry(market_id).write(market);
            
            // Deduct liquidity from creator's balance
            let new_balance = current_balance - initial_liquidity;
            self.user_balances.entry(caller).write(new_balance);
            
            // Emit event
            self.emit(Event::MarketCreated(MarketCreated {
                market_id,
                creator: caller,
                title,
                description,
                outcome_a_text,
                outcome_b_text,
                resolution_time,
                initial_liquidity
            }));
            
            market_id
        }

        fn get_market_details(self: @ContractState, market_id: u256) -> Market {
            self.markets.entry(market_id).read()
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

        fn buy_shares(
            ref self: ContractState, 
            market_id: u256, 
            is_outcome_a: bool, 
            amount_to_spend: u256
        ) -> u256 {
            assert(amount_to_spend > 0, 'Amount must be greater than 0');
            
            let caller = get_caller_address();
            let current_balance = self.user_balances.entry(caller).read();
            assert(current_balance >= amount_to_spend, 'Insufficient balance');
            
            // Get market details
            let mut market = self.markets.entry(market_id).read();
            assert(market.id != 0, 'Market does not exist');
            
            // Check if market is active
            let current_time = get_block_timestamp();
            assert(is_market_active(market.resolution_time, current_time, market.resolved_outcome), 'Market not active');
            
            // Calculate shares to receive using AMM formula
            let shares_received = calculate_shares_from_amount(
                market.total_shares_a,
                market.total_shares_b,
                amount_to_spend,
                is_outcome_a
            );
            
            assert(shares_received > 0, 'Invalid share calculation');
            
            // Update market state
            if is_outcome_a {
                market.total_shares_a = market.total_shares_a + shares_received;
            } else {
                market.total_shares_b = market.total_shares_b + shares_received;
            }
            market.total_liquidity = market.total_liquidity + amount_to_spend;
            
            // Update user balance
            let new_balance = current_balance - amount_to_spend;
            self.user_balances.entry(caller).write(new_balance);
            
            // Update user shares
            let current_shares = self.user_shares.entry((caller, market_id, is_outcome_a)).read();
            self.user_shares.entry((caller, market_id, is_outcome_a)).write(current_shares + shares_received);
            
            // Calculate new price for event before storing market
            let new_price = calculate_constant_product_price(
                market.total_shares_a,
                market.total_shares_b,
                is_outcome_a
            );
            
            // Store updated market
            self.markets.entry(market_id).write(market);
            
            // Emit event
            self.emit(Event::SharesBought(SharesBought {
                user: caller,
                market_id,
                is_outcome_a,
                amount_spent: amount_to_spend,
                shares_received,
                new_price
            }));
            
            shares_received
        }

        fn get_share_price(self: @ContractState, market_id: u256, is_outcome_a: bool) -> u256 {
            let market = self.markets.entry(market_id).read();
            assert(market.id != 0, 'Market does not exist');
            
            calculate_constant_product_price(
                market.total_shares_a,
                market.total_shares_b,
                is_outcome_a
            )
        }

        fn calculate_shares_for_amount(
            self: @ContractState,
            market_id: u256,
            is_outcome_a: bool,
            amount: u256
        ) -> u256 {
            let market = self.markets.entry(market_id).read();
            assert(market.id != 0, 'Market does not exist');
            
            calculate_shares_from_amount(
                market.total_shares_a,
                market.total_shares_b,
                amount,
                is_outcome_a
            )
        }

        fn get_user_shares(
            self: @ContractState,
            user: ContractAddress,
            market_id: u256,
            is_outcome_a: bool
        ) -> u256 {
            self.user_shares.entry((user, market_id, is_outcome_a)).read()
        }

        fn resolve_market(ref self: ContractState, market_id: u256, winning_outcome_is_a: bool) {
            // Only owner can resolve markets
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
            
            // Get user's shares in winning outcome
            let user_winning_shares = self.user_shares.entry((caller, market_id, winning_outcome_is_a)).read();
            assert(user_winning_shares > 0, 'No winning shares to claim');
            
            // Calculate winnings
            let total_winning_shares = if winning_outcome_is_a {
                market.total_shares_a
            } else {
                market.total_shares_b
            };
            
            let winnings = calculate_winnings(
                user_winning_shares,
                total_winning_shares,
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
                shares_held: user_winning_shares
            }));
            
            winnings
        }

        fn get_token_address(self: @ContractState) -> ContractAddress {
            self.token_address.read()
        }
    }
} 