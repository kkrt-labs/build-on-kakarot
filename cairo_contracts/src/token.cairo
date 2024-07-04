#[starknet::interface]
trait IKakarot<T> {
    fn compute_starknet_address(self: @T, address: felt252) -> felt252;
}

#[starknet::contract]
mod DualVmToken {
    use cairo_contracts::token::IKakarotDispatcherTrait;
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;

    const KAKAROT: felt252 = 0x4508afc067e9818fd1b4378f25593f721c83fcc89e3ab7f780e54b9f47c4a7a;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
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
    fn constructor(ref self: ContractState, initial_supply: u256, recipient: ContractAddress) {
        let name = "MyToken";
        let symbol = "MTK";

        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }

    #[external(v0)]
    fn compute_starknet_address(self: @ContractState, address: felt252) -> felt252 {
        super::IKakarotDispatcher { contract_address: KAKAROT.try_into().unwrap() }
            .compute_starknet_address(address)
    }
}
