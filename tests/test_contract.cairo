use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address};
use basic::IHelloStarknetDispatcher;
use basic::IHelloStarknetDispatcherTrait;
use basic::IHelloStarknetSafeDispatcher;
use basic::IHelloStarknetSafeDispatcherTrait;

use basic::IMyERC20TokenDispatcher;
use basic::IMyERC20TokenDispatcherTrait;

use basic::ISimpleVaultDispatcher;
use basic::ISimpleVaultDispatcherTrait;

use basic::ISimpleVaultSafeDispatcher;
use basic::ISimpleVaultSafeDispatcherTrait;

use basic::IZklendMarketDispatcher;
use basic::IZklendMarketDispatcherTrait;

use starknet::{ContractAddress, contract_address_const};

//use traits::TryInto;

#[test]
fn test_get_balance() {
    let contract = declare("HelloStarknet").unwrap();
    let (contract_address, _ ) = contract.deploy(@array![]).unwrap();

    let dispatcher = IHelloStarknetDispatcher {contract_address};

    let balance = dispatcher.get_balance();

    assert(balance == 0, 'Balance is wrong');
}
#[test]
#[feature("safe_dispatcher")]
fn test_increase_balance() {
    let contract = declare("HelloStarknet").unwrap();
    let (contract_address, _ ) = contract.deploy(@array![]).unwrap();

    let dispatcher = IHelloStarknetDispatcher {contract_address};
    let safe_dispatcher = IHelloStarknetSafeDispatcher {contract_address};

    start_cheat_caller_address(contract_address, 0x1.try_into().unwrap());
    dispatcher.increase_balance(2);

    stop_cheat_caller_address(contract_address);
    //this call should fail

    match safe_dispatcher.increase_balance(2) {
        Result::Ok(_) => panic(ArrayTrait::new()),
        Result::Err(_) => {}

    }

    //now test zero input revert
    start_cheat_caller_address(contract_address, 0x1.try_into().unwrap());

    match safe_dispatcher.increase_balance(0) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Amount cannot be 0', *panic_data.at(0));
        }

    }


}

#[test]
fn test_erc20() {
    let contract = declare("MyERC20Token").unwrap();
    //How to format constructor args?
    let mut constructor_args : Array<felt252> = ArrayTrait::new();
    
    //let name : felt252 = 'token';
    //let symbol : felt252 = 'TKN';
    //let fixed_supply : felt252 = 1200;
    let recipient : ContractAddress = 0x1.try_into().unwrap();
    //let recipient_BA : ByteArray = "0x1";

    //constructor_args.append(name);
    //constructor_args.append(symbol);
    //constructor_args.append(fixed_supply);
    //constructor_args.append(fixed_supply);

    let (contract_address, _ ) = contract.deploy(@constructor_args).unwrap();

    let dispatcherERC20 = IMyERC20TokenDispatcher {contract_address};

    assert(dispatcherERC20.balance_of(recipient) > 0, 'Initial mint missing');

}

#[test]
#[should_panic(expected: ('ERC20: insufficient allowance', ))]
fn test_simpleVault_DepositFailure() {
    //set up vault's token
    let contract = declare("MyERC20Token").unwrap();
    let mut constructor_args : Array<felt252> = ArrayTrait::new();
    //did constructor here have issues because the strings didn't fit in one felt252?
    let (contract_address, _ ) = contract.deploy(@constructor_args).unwrap();
    let dispatcherERC20 = IMyERC20TokenDispatcher {contract_address};
    
    let owner : ContractAddress = 0x1.try_into().unwrap();

    dispatcherERC20.balance_of(owner);
   

    //deploy vault linked to token
    let contractVault = declare("SimpleVault").unwrap();
    let mut constructor_calldata : Array<felt252> = array![owner.into(), contract_address.into()];
    let (contract_address_vault, _ ) = contractVault.deploy(@constructor_calldata).unwrap();
    let dispatcherVault = ISimpleVaultDispatcher {contract_address : contract_address_vault};

    //test get_owner
    assert!(dispatcherVault.get_owner() == owner, "constructor did not set owner");
    
    
    //test deposit 
    //the call should fail if the token is not approved for transfer
    let amount : u256 = 1;
    let user : ContractAddress = 0x2.try_into().unwrap();
    start_cheat_caller_address(contract_address_vault, user); //start impersonating owner for Vault
    dispatcherVault.deposit(amount.try_into().unwrap());
}

#[test]
#[should_panic(expected: ("User has not deposited amount before", ))]
fn test_simpleVault_WithdrawFailure() {
    //set up vault's token
    let contract = declare("MyERC20Token").unwrap();
    let mut constructor_args : Array<felt252> = ArrayTrait::new();
    //did constructor here have issues because the strings didn't fit in one felt252?
    let (contract_address, _ ) = contract.deploy(@constructor_args).unwrap();
    let dispatcherERC20 = IMyERC20TokenDispatcher {contract_address};
    
    let owner : ContractAddress = 0x1.try_into().unwrap();

    dispatcherERC20.balance_of(owner);
   

    //deploy vault linked to token
    let contractVault = declare("SimpleVault").unwrap();
    let mut constructor_calldata : Array<felt252> = array![owner.into(), contract_address.into()];
    let (contract_address_vault, _ ) = contractVault.deploy(@constructor_calldata).unwrap();
    let dispatcherVault = ISimpleVaultDispatcher {contract_address : contract_address_vault};

    //test get_owner
    assert!(dispatcherVault.get_owner() == owner, "constructor did not set owner");
    
    
    //test withdraw
    //the call should fail if the user has deposited nothing
    let amount : u256 = 1;
    let user : ContractAddress = 0x2.try_into().unwrap();
    start_cheat_caller_address(contract_address_vault, user); //start impersonating owner for Vault
    dispatcherVault.withdraw(amount.try_into().unwrap());
}

#[test]
#[feature("safe_dispatcher")]
fn test_simpleVault_Successes() {
    //set up vault's token
    let contract = declare("MyERC20Token").unwrap();
    let mut constructor_args : Array<felt252> = ArrayTrait::new();
    //did constructor here have issues because the strings didn't fit in one felt252?
    let (contract_address, _ ) = contract.deploy(@constructor_args).unwrap();
    let dispatcherERC20 = IMyERC20TokenDispatcher {contract_address};
    
    let owner : ContractAddress = 0x1.try_into().unwrap();
    //deploy vault linked to token
    let contractVault = declare("SimpleVault").unwrap();
    let mut constructor_calldata : Array<felt252> = array![owner.into(), contract_address.into()];
    let (contract_address_vault, _ ) = contractVault.deploy(@constructor_calldata).unwrap();
    let dispatcherVault = ISimpleVaultDispatcher {contract_address : contract_address_vault};
    let safeDispatcherVault = ISimpleVaultSafeDispatcher {contract_address : contract_address_vault};

    //test get_owner
    assert!(dispatcherVault.get_owner() == owner, "constructor did not set owner");

    //set vault address to itself
    start_cheat_caller_address(contract_address_vault, owner);
    dispatcherVault.set_vault(contract_address_vault);
    stop_cheat_caller_address(contract_address_vault);
    
    
    //test deposit 
    let amount : u256 = 1;
    let user : ContractAddress = 0x2.try_into().unwrap();

    //fund user with tokens
    start_cheat_caller_address(contract_address, owner); //impersonate owner for ERC20
    dispatcherERC20.transfer(user, amount);
    stop_cheat_caller_address(contract_address); 
   
    //the call should succeed if the token is approved and record the deposit correctly
    start_cheat_caller_address(contract_address, user); //impersonate userfor ERC20
    dispatcherERC20.approve(contract_address_vault, amount);
    stop_cheat_caller_address(contract_address); //stop impersonating user for ERC20

    //record user balance before deposit
    let user_balance_before = dispatcherERC20.balance_of(user);

    start_cheat_caller_address(contract_address_vault, user); //start impersonating user for Vault
    dispatcherVault.deposit(amount.try_into().unwrap());
    stop_cheat_caller_address(contract_address_vault); //stop impersonating user for ERC20

    //check state change is as expected
    let user_balance_after = dispatcherERC20.balance_of(user);
    assert!(dispatcherERC20.balance_of(contract_address_vault) == amount, "Vault balance does not match deposit");
    assert!(user_balance_after == user_balance_before - amount, "User balance should have decreased");
    //test withdrawal 

    //the call should fail if the user has not deposited the requested amount

    //the call should succeed if the user has the amount requested deposited
    start_cheat_caller_address(contract_address_vault, user);
    dispatcherVault.withdraw(amount.try_into().unwrap());
    stop_cheat_caller_address(contract_address_vault);

    //the call should fail if the user repeats a previously valid call

    match safeDispatcherVault.withdraw(amount.try_into().unwrap()) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {}
        //    assert(*panic_data.at(0) == 'User Wrong', *panic_data.at(0));
        

    }

    //the call should fail if a different user from the depositor attempts to withdraw
    start_cheat_caller_address(contract_address_vault, owner);
    match safeDispatcherVault.withdraw(amount.try_into().unwrap()) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {}
        //    assert(*panic_data.at(0) == 'User Wrong', *panic_data.at(0));
        

    }
    stop_cheat_caller_address(contract_address_vault);

}

#[test]
#[fork(url: "API ENDPOINT HERE", block_id: BlockId::Number(651681))] //height 23rd June 2024
fn test_simpleVault_Fork() {

    //zklend ethereum market
    let zklend_market : ContractAddress = contract_address_const::<
    0x4c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05
    >();

    //set vault's token to Ethereum address
    let contract_address: ContractAddress = contract_address_const::<
    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
    >();

    let dispatcherERC20 = IMyERC20TokenDispatcher {
        contract_address: contract_address
    };

    let amount : u256 = 1;
    let user : ContractAddress = 0x2.try_into().unwrap();
    //ignore two token integrations for now
    //set up wsteth token
    //let contract_address_WSTETH: ContractAddress = contract_address_const::<
    //0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2
    //>();

    //let dispatcherWSTETH = IMyERC20TokenDispatcher {
    //    contract_address: contract_address_WSTETH
    //};

    let owner : ContractAddress = 0x1.try_into().unwrap();

    //dispatcherERC20.balance_of(owner);
   

    //deploy vault linked to token
    let contractVault = declare("SimpleVault").unwrap();
    let mut constructor_calldata : Array<felt252> = array![owner.into(), contract_address.into()];
    let (contract_address_vault, _ ) = contractVault.deploy(@constructor_calldata).unwrap();
    let dispatcherVault = ISimpleVaultDispatcher {contract_address : contract_address_vault};

    //test get_owner
    assert!(dispatcherVault.get_owner() == owner, "constructor did not set owner");
    
    start_cheat_caller_address(contract_address_vault, owner);
    dispatcherVault.set_market(zklend_market);
    stop_cheat_caller_address(contract_address_vault);

    //test ekubo position opening
    //let ekubo_positions : ContractAddress = contract_address_const::<
    //0x2e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067
    //>();

    
    ////transfer eth to positions address
    //dispatcherERC20.transfer(ekubo_positions, amount);
    //dispatcherWSTETH.transfer(ekubo_positions, amount);

    //impersonate an address with tokens

    let donor_account : ContractAddress = contract_address_const::<
    0x01a2de9f2895ac4e6cb80c11ecc07ce8062a4ae883f64cb2b1dc6724b85e897d
    >();

    //check donor has ETH
    assert!(dispatcherERC20.balance_of(donor_account) > 0 , "Donor has no funds");
    let donation : u256 = 1000000000;
    start_cheat_caller_address(contract_address, donor_account);
    dispatcherERC20.transfer(user, donation);


    

    let dispatcherZklendMarket = IZklendMarketDispatcher {contract_address : zklend_market};
    
    start_cheat_caller_address(contract_address, user);
    dispatcherERC20.approve(zklend_market, amount);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(zklend_market, user);
    dispatcherZklendMarket.deposit(contract_address, amount.try_into().unwrap());
    stop_cheat_caller_address(zklend_market);


}