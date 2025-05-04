use contracts::counter::{Counter};
use contracts::counter::Counter::FELT_STRK_CONTRACT;
use contracts::counter::{
    ICounterDispatcher, ICounterDispatcherTrait, ICounterSafeDispatcher,
    ICounterSafeDispatcherTrait,
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_token::erc20::interface::{
    IERC20Dispatcher, IERC20DispatcherTrait,
};
use snforge_std::ContractClassTrait;
use snforge_std::EventSpyAssertionsTrait;
use snforge_std::{
    DeclareResultTrait, declare, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress};

const ZERO_COUNT: u32 = 0;
const STRK_AMOUNT: u256 = 5000000000000000000;
const WIN_NUMBER: u32 = 5;
pub const STRK_TOKEN_HOLDER_ADDRESS: felt252 = 0x00000005dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b;



fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn USER_1() -> ContractAddress {
    'USER_1'.try_into().unwrap()
}

fn STRK() -> ContractAddress {
    FELT_STRK_CONTRACT.try_into().unwrap()
}

fn STRK_TOKEN_HOLDER() -> ContractAddress {
    STRK_TOKEN_HOLDER_ADDRESS.try_into().unwrap()
}

fn get_strk_token_balance(account: ContractAddress) -> u256 {
    IERC20Dispatcher { contract_address: STRK() }.balance_of(account)
}

fn transfer_strk(caller: ContractAddress, amount: u256, recipient: ContractAddress) {
    start_cheat_caller_address(STRK(), caller);
    IERC20Dispatcher { contract_address: STRK() }.transfer(recipient, amount);
    stop_cheat_caller_address(STRK());
}

fn approve_strk(owner: ContractAddress, spender: ContractAddress, amount: u256) {
    start_cheat_caller_address(STRK(), owner);
    IERC20Dispatcher { contract_address: STRK() }.approve(spender, amount);
    stop_cheat_caller_address(STRK());
}


fn __deploy__(init_value: u32) -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher, IERC20Dispatcher) {
    let contract_class = declare("Counter").unwrap().contract_class();

    let mut calldata: Array<felt252> = array![];
    init_value.serialize(ref calldata);
    OWNER().serialize(ref calldata);

    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    let counter = ICounterDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_counter = ICounterSafeDispatcher { contract_address };
    let strk_token = IERC20Dispatcher { contract_address: STRK() };

    transfer_strk(
        STRK_TOKEN_HOLDER(),
        STRK_AMOUNT,
        contract_address,
    );

    (counter, ownable, safe_counter, strk_token)
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_counter_deployment() {
    let (counter, ownable, _, _) = __deploy__(ZERO_COUNT);

    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'counter not set');
    assert(ownable.owner() == OWNER(), 'owner not set');
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_increase_counter() {
    let (counter, _, _, _) = __deploy__(ZERO_COUNT);

    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'counter not set');

    counter.increase_counter();

    let count_2 = counter.get_counter();
    assert(count_2 == count_1 + 1, 'invalid counter');
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_emitted_increased_event() {
    let (counter, _, _, _) = __deploy__(ZERO_COUNT);
    let mut spy = spy_events();

    start_cheat_caller_address(counter.contract_address, USER_1());
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);
    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER_1() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER_1() }),
                ),
            ],
        );
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_increase_counter_contract_transfers_strk_to_caller_when_counter_is_a_win_number() {
    let (counter, _, _, _) = __deploy__(4);

    let count_1 = counter.get_counter();

    assert(count_1 == 4, 'invalid counter');

    let counter_strk_balance_1 = get_strk_token_balance(counter.contract_address);

    let user_1_strk_balance = get_strk_token_balance(USER_1());

    assert(user_1_strk_balance == 0, 'user 1 strk balance not 0');

    assert(counter_strk_balance_1 == STRK_AMOUNT, 'invalid counter strk balance');

    start_cheat_caller_address(counter.contract_address, USER_1());

    start_cheat_caller_address(STRK(), counter.contract_address);

    let win_number: u32 = counter.get_win_number();
    assert(win_number == 5, 'invalid win number');

    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);
    stop_cheat_caller_address(STRK());

    let count_2 = counter.get_counter();
    assert(count_2 == 5, 'count 2 not set');

    let counter_strk_balance_2 = get_strk_token_balance(counter.contract_address);
    assert(counter_strk_balance_2 == 0, 'invalid counter2 strk balance');

    let user_1_strk_balance = get_strk_token_balance(USER_1());
    assert(user_1_strk_balance == STRK_AMOUNT, 'strk not transferred');

}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_increase_counter_contract_does_not_transfer_strk_token_to_caller_when_counter_contract_has_zero_strk() {
    let (counter, _, _, _) = __deploy__(4);

    let counter_address = counter.contract_address;

    let count_1 = counter.get_counter();

    assert(count_1 == 4, 'invalid counter');

    let counter_strk_balance_1 = get_strk_token_balance(counter.contract_address);

    assert(counter_strk_balance_1 == STRK_AMOUNT, 'invalid counter strk balance');

    let owner_strk_balance_1 = get_strk_token_balance(OWNER());

    assert(owner_strk_balance_1 == 0, 'owner strk balance not 0');

    transfer_strk(
        counter_address,
        STRK_AMOUNT,
        OWNER()
    );

    let counter_balance_after_transfer_to_owner = get_strk_token_balance(counter_address);

    assert(counter_balance_after_transfer_to_owner == 0, 'invalid strk bal after transfer');

    let owner_strk_balance = get_strk_token_balance(OWNER());

    assert(owner_strk_balance == STRK_AMOUNT, 'bad owner balanc after transfer');


    start_cheat_caller_address(counter.contract_address, USER_1());

    let win_number_1 : u32 = counter.get_win_number();

    assert(win_number_1 == 5, 'invalid win number');

    counter.increase_counter();

    stop_cheat_caller_address(counter.contract_address);

    let count_2 = counter.get_counter();

    assert(count_2 == 5, 'count 2 not set');

    let strk_balance_user_1 = get_strk_token_balance(USER_1());

    assert(strk_balance_user_1 == 0, 'strk balance user 1 not 0');

    let counter_strk_balance_2 = get_strk_token_balance(counter.contract_address);
    assert(counter_strk_balance_2 == 0, 'invalid counter strk balance');


}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
#[feature("safe_dispatcher")]
fn test_safe_panic_decrease_counter() {
    let (counter, _, safe_counter, _) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'counter not set');

    match safe_counter.decrease_counter() {
        Result::Ok(_) => panic!("Shouldn't decrease 0"),
        Result::Err(e) => assert(*e[0] == 'Counter is going negative', *e.at(0)),
    }
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
#[should_panic(expected: 'Counter is going negative')]
fn test_panic_decrease_counter() {
    let (counter, _, _, _) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'counter not set');

    counter.decrease_counter()
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_successful_decrease_counter() {
    let (counter, _, _, _) = __deploy__(5);

    let count_1 = counter.get_counter();
    assert(count_1 == 5, 'invalid counter');

    counter.decrease_counter();
    let final_count = counter.get_counter();
    assert(final_count == count_1 - 1, 'invalid decrease');
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_emitted_decreased_event() {
    let (counter, _, _, _) = __deploy__(2);
    let mut spy = spy_events();

    start_cheat_caller_address(counter.contract_address, USER_1());
    counter.decrease_counter();
    stop_cheat_caller_address(counter.contract_address);
    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER_1() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER_1() }),
                ),
            ],
        );
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_successful_reset_counter() {
    let (counter, _, _, strk_token) = __deploy__(5);
    let mut spy = spy_events();

    let count_1 = counter.get_counter();
    assert(count_1 == 5, 'invalid counter');

    let test_strk_amount = 10000000000000000000;

    approve_strk(
        USER_1(),
        counter.contract_address,
        test_strk_amount,
    );

    let counter_allowance = strk_token.allowance(USER_1(), counter.contract_address);
    assert(counter_allowance == test_strk_amount, 'invalid allowance');

    let strk_holder_balance = get_strk_token_balance(STRK_TOKEN_HOLDER());
    assert(strk_holder_balance > test_strk_amount, 'invalid strk holder balance');

    transfer_strk(
        STRK_TOKEN_HOLDER(),
        test_strk_amount,
        USER_1(),
    );
    let user_1_strk_balance = get_strk_token_balance(USER_1());
    assert(user_1_strk_balance == test_strk_amount, 'invalid user 1 strk balance');

    let counter_strk_balance = get_strk_token_balance(counter.contract_address);
    assert(counter_strk_balance == STRK_AMOUNT, 'invalid counter strk balance');

    start_cheat_caller_address(counter.contract_address, USER_1());

    counter.reset_counter();

    stop_cheat_caller_address(counter.contract_address);

    let count_2 = counter.get_counter();

    assert(count_2 == 0, 'invalid counter after reset');

    let counter_strk_balance_2 = get_strk_token_balance(counter.contract_address);

    assert(counter_strk_balance_2 == STRK_AMOUNT + STRK_AMOUNT, 'invalid new counter strk bal');

    let user_1_strk_balance_2 = get_strk_token_balance(USER_1());
    assert(user_1_strk_balance_2 == test_strk_amount - STRK_AMOUNT, 'invalid new user 1 strk bal'); 

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Reset(Counter::Reset { account: USER_1() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER_1() }),
                ),
            ],
        );

}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_reset_counter_when_contract_strk_balance_is_zero() {
    let (counter, _, _, _) = __deploy__(4);

    let mut spy = spy_events();

    let count_1 = counter.get_counter();

    let counter_address = counter.contract_address;

    assert(count_1 == 4, 'invalid counter');

    let counter_strk_balance_1 = get_strk_token_balance(counter_address);

    assert(counter_strk_balance_1 == STRK_AMOUNT, 'invalid counter strk balance');

    let user_1_strk_balance = get_strk_token_balance(USER_1());

    assert(user_1_strk_balance == 0, 'user 1 strk balance not 0');

    start_cheat_caller_address(counter.contract_address, USER_1());

    start_cheat_caller_address(STRK(), counter.contract_address);

    let win_number_1 : u32 = counter.get_win_number();

    assert(win_number_1 == 5, 'invalid win number');

    counter.increase_counter();

    stop_cheat_caller_address(counter.contract_address);
    stop_cheat_caller_address(STRK());

    let count_2 = counter.get_counter();

    assert(count_2 == 5, 'count 2 not set');

    let counter_strk_balance_2 = get_strk_token_balance(counter_address);

    assert(counter_strk_balance_2 == 0, 'invalid counter strk balance');

    let user_1_strk_balance = get_strk_token_balance(USER_1());

    assert(user_1_strk_balance == STRK_AMOUNT, 'strk not transferred');

    start_cheat_caller_address(counter.contract_address, USER_1());

    counter.reset_counter();

    stop_cheat_caller_address(counter.contract_address);

    let count_3 = counter.get_counter();

    assert(count_3 == 0, 'invalid counter after reset');

    let counter_strk_balance_3 = get_strk_token_balance(counter.contract_address);

    assert(counter_strk_balance_3 == 0, 'invalid new counter strk bal');

    let user_1_strk_balance_3 = get_strk_token_balance(USER_1());
    assert(user_1_strk_balance_3 == STRK_AMOUNT, 'invalid new user 1 strk bal');

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Reset(Counter::Reset { account: USER_1() }),
                ),
            ],
        );

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER_1() }),
                ),
            ],
        );

}   