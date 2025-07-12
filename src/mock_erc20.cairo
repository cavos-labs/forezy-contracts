#[starknet::interface]
pub trait IMockERC20<TContractState> {
    // Standard ERC20 functions
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: starknet::ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: starknet::ContractAddress, spender: starknet::ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: starknet::ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, from: starknet::ContractAddress, to: starknet::ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: starknet::ContractAddress, amount: u256) -> bool;
    
    // Mock-specific functions for testing
    fn mint(ref self: TContractState, to: starknet::ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod MockERC20 {
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    
    // We include the component implementations to access their methods internally
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("Mock Token", "MOCK");
    }

    #[abi(embed_v0)]
    pub impl MockERC20Impl of super::IMockERC20<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.erc20.decimals()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            self.erc20.transfer(to, amount)
        }

        fn transfer_from(ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool {
            self.erc20.transfer_from(from, to, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20.approve(spender, amount)
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.erc20.mint(to, amount);
        }
    }
} 