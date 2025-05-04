#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
    fn get_win_number(self: @TContractState) -> u32;
}


#[starknet::contract]
pub mod Counter {
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use super::ICounter;

    

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;

    pub const FELT_STRK_CONTRACT: felt252 = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
    
    pub const WIN_NUMBER: u32 = 5;

    #[storage]
    pub struct Storage {
        counter: u32,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, init_value: u32, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.counter.write(init_value);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Increased: Increased,
        Decreased: Decreased,
        Reset: Reset,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Increased {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Decreased {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Reset {
        pub account: ContractAddress,
    }

    pub mod CounterError {
        pub const COUNTER_NEGATIVE: felt252 = 'Counter is going negative';
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {

        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn get_win_number(self: @ContractState) -> u32 {
            WIN_NUMBER
        }

        fn increase_counter(ref self: ContractState) {
            let new_counter = self.counter.read() + 1;
            self.counter.write(new_counter);

            self.emit(Increased { account: get_caller_address() });

            if new_counter == WIN_NUMBER {
                let caller: ContractAddress = get_caller_address();
                let strk_ctrt: ContractAddress = FELT_STRK_CONTRACT.try_into().unwrap();

                let strk_ctrt_dispatcher = IERC20Dispatcher { contract_address: strk_ctrt };

                let balance = strk_ctrt_dispatcher.balance_of(get_contract_address());
                
                if balance > 0 {
                    strk_ctrt_dispatcher.transfer(caller, balance);
                }
            }
        }

        fn decrease_counter(ref self: ContractState) {
            let current_value = self.counter.read();
            assert(current_value > 0, CounterError::COUNTER_NEGATIVE);
            self.counter.write(current_value - 1);

            self.emit(Decreased { account: get_caller_address() })
        }

        fn reset_counter(ref self: ContractState) {

            let caller: ContractAddress = get_caller_address();
            let strk_ctrt: ContractAddress = FELT_STRK_CONTRACT.try_into().unwrap();
            
            let strk_ctrt_dispatcher = IERC20Dispatcher {
                contract_address: strk_ctrt,
            };
            
            let contract_balance = strk_ctrt_dispatcher.balance_of(get_contract_address());
            
            if contract_balance > 0 {
                strk_ctrt_dispatcher.transfer_from(caller, get_contract_address(), contract_balance);
            }

            self.counter.write(0);
            self.emit(Reset { account: get_caller_address() })
        }

        
    }
}
