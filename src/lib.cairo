use starknet::{ContractAddress, get_caller_address};
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

#[starknet::interface]
pub trait IZklendMarket<TContractState> {
    fn deposit(ref self: TContractState, token : ContractAddress, amount: felt252);
    fn withdraw(ref self: TContractState, token : ContractAddress, amount: felt252);
}

#[starknet::interface]
pub trait IHelloStarknet<TContractState> {
    fn increase_balance(ref self: TContractState, amount: felt252);
    fn get_balance(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod HelloStarknet {
    use core::traits::Into;
    use starknet::{ContractAddress, get_caller_address};
    #[storage]
    struct Storage {
        balance: felt252,
    }

    #[abi(embed_v0)]
    impl HelloStarknetImpl of super::IHelloStarknet<ContractState> {
        fn increase_balance(ref self: ContractState, amount: felt252) {
            assert(amount != 0, 'Amount cannot be 0');
            assert(get_caller_address().into() == 1, 'wrong address');
            self.balance.write(self.balance.read() + amount);
        }

        fn get_balance(self: @ContractState) -> felt252 {
            self.balance.read()
        }
    }
}

#[starknet::interface]
pub trait IMyERC20Token<TContractState> {
    fn balance_of(self: @TContractState, user: ContractAddress) -> u256;
    fn approve(self: @TContractState, user: ContractAddress, amount : u256) -> bool;
    fn transfer(self: @TContractState, user: ContractAddress, amount : u256) -> bool;
} 

#[starknet::contract]
mod MyERC20Token {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState
    ) { 
        let name: ByteArray = "Token";
        let symbol: ByteArray = "tkn";
        let recipient: ContractAddress = 0x1.try_into().unwrap();
        let fixed_supply: u256 = 1200;
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, fixed_supply);
    }
}

#[starknet::interface]
pub trait ISimpleVault<TContractState> {
    fn constructor(ref self: TContractState, _owner : ContractAddress, _erc20 : ContractAddress);
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn set_vault(ref self : TContractState, _vault : ContractAddress);
    fn set_market(ref self : TContractState, _market : ContractAddress);
    fn deposit(ref self: TContractState, amount: u128);
    fn withdraw(ref self: TContractState, amount: u128);
}

#[starknet::contract]
mod SimpleVault {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    //use super::IERC20Dispatcher;
    //use super::IERC20DispatcherTrait;
    use super::IZklendMarketDispatcher;
    use super::IZklendMarketDispatcherTrait;

    #[storage]
    struct Storage {
        owner : ContractAddress,
        deposits : LegacyMap::<ContractAddress, u128>,
        erc20 : ContractAddress,
        this : ContractAddress, //hack to have access to this contract's address
        market : ContractAddress,
    }

    #[constructor]
        fn constructor(ref self: ContractState, _owner: ContractAddress, _erc20: ContractAddress) {
            self.owner.write(_owner);
            self.erc20.write(_erc20);
        }
    
    //impl SimpleVaultImpl of super::ISimpleVault<ContractState> {
        #[external(v0)]
        fn set_vault(ref self:ContractState, _vault: ContractAddress){
            let caller : ContractAddress = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner");
            self.this.write(_vault);
        }

        #[external(v0)]
        fn set_market(ref self:ContractState, _market: ContractAddress){
            let caller : ContractAddress = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner");
            self.market.write(_market);
        }

        
        #[external(v0)]
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        #[external(v0)]
        fn deposit(ref self: ContractState, amount: u128) {
            let user : ContractAddress = get_caller_address();
            let existing_total = self.deposits.read(user);
            let new_total = existing_total + amount;
            let _amount : u256 = amount.try_into().unwrap();
            let target_erc20 : ContractAddress = self.erc20.read();
            let dispatcher = ERC20ABIDispatcher { contract_address : target_erc20 } ;
            let vault = self.this.read();
            dispatcher.transferFrom(user, vault, _amount);
            self.deposits.write(user, new_total);
            

            //move deposit to active ZkLend market
            let target_market = self.market.read();
            let dispatcher_zklendMarket = IZklendMarketDispatcher{ contract_address : target_market } ;
            
            dispatcher.approve(target_market, amount.try_into().unwrap());
            dispatcher_zklendMarket.deposit(target_erc20, amount.try_into().unwrap());
            //self.emit(DepositAction {user, amount});
        }
        #[external(v0)]
        fn withdraw(ref self: ContractState, amount: u128){
            let user : ContractAddress = get_caller_address();
            let existing_total = self.deposits.read(user);

            assert!(existing_total >= amount, "User has not deposited amount before");

            let target_erc20 : ContractAddress = self.erc20.read();
            let dispatcher = ERC20ABIDispatcher { contract_address : target_erc20 } ;
            
            let new_total = existing_total - amount; 
            self.deposits.write(user, new_total);

            //move deposit from active ZkLend market back to vault then user
            let target_market = self.market.read();
            let dispatcher_zklendMarket = IZklendMarketDispatcher{ contract_address : target_market } ;
            dispatcher_zklendMarket.withdraw(target_erc20, amount.try_into().unwrap());

            //if it is possible the amount sent to us is less than the amount requested need to rewrite as this would then always fail.
            dispatcher.transfer(user, amount.try_into().unwrap());
        }

        // process deposits of ETH
        //ETH lives at 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 and is treated like an ERC20?

        //process withdrawals of ETH

        //handle deposits and withdrawals of ETH into Ekubo pool

        //handle minting and burning of stablecoin

        //fn mint(ref self: ContractState, _to: ContractAddress, _amount: u128){
        //    //create a modified ERC20 which has the vault as an approved burner and minter
//
        //    //mint _amount for address _to
//
        //}
//
        //fn burn(ref self: ContractState, _from: ContractAddress, _amount: u128){
        //    
        //}
    //}
}
