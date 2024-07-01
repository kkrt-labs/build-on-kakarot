# Build On Kakarot

## Description

An example repository to demonstrate how to build on Kakarot.

## Requirements

- [Docker](https://docs.docker.com/get-docker/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Scarb](https://docs.swmansion.com/scarb/download.html#install-via-asdf) and [Starkli](https://github.com/xJonathanLEI/starkli) if you want to deploy Cairo contracts. Make sure to install starkli version `0.2.9` with `starkliup -v  v0.2.9`

## Setting up

Run the following command to setup the git submodules.

```
make setup
```

To get started, you will need to run the local nodes. You can do this by running:

```sh
make start
```

This will start an Anvil Node (that runs the L1 contracts for L1 <> L2 messaging) at address `http://127.0.0.1:8545` and a Kakarot Node at address `http://127.0.0.1:3030`

Kakarot is deployed along with commonly used contracts, such as [Multicall3](https://github.com/mds1/multicall/blob/main/src/Multicall3.sol), [CreateX](https://github.com/pcaversaccio/createx?tab=readme-ov-file#permissioned-deploy-protection-and-cross-chain-redeploy-protection) and the [Arachnid Proxy](https://github.com/Arachnid/deterministic-deployment-proxy).

## Deploying an EVM contract

You can deploy contracts on Kakarot using the regular EVM tooling, without any modifications. For example, this is how you would deploy a simple Counter contract:

```sh
export PRIVATE_KEY = <your_private_key>
export ETH_RPC_URL=http://127.0.0.1:3030
forge create solidity_contracts/src/Counter.sol:Counter --private-key $PRIVATE_KEY
```

This will deploy the Counter contract on Kakarot and return the address of the deployed contract.

You can then interact with the contract using `cast`.

- Increment the counter

```sh
cast send 0x5fbdb2315678afecb367f032d93f642f64180aa3 "increment()" --private-key $PRIVATE_KEY
```

- Check the current counter value:

```
cast call 0x5fbdb2315678afecb367f032d93f642f64180aa3 "number()"
```

## Kakarot Cairo Interoperability

As Kakarot is an EVM-L2 using the Starknet Stack, you can natively interact with Cairo contracts from the EVM. This opens up a world of possibilities complex and resource-intensive applications on Kakarot, while benefiting from the performance of the cheapest zkVM, Cairo.

## Deploying a Cairo Contract

Once scarb is installed in version `2.5.4`, `cd` into the `cairo_contracts` directory and build the `Counter` cairo contract:

```
cd cairo_contracts && scarb build && ../
```

Once built, you can deploy the contract using the `starkli`. First, set an account up (using the default Katana private key, no password):

```
export STARKNET_KEYSTORE="katana.key.json"
export STARKNET_ACCOUNT="katana.account.json"
export STARKNET_RPC="http://127.0.0.1:5050"
starkli declare cairo_contracts/target/dev/cairo_contracts_Counter.contract_class.json
```

This will output the contract's class hash. You can use this hash to deploy the contract:

```
starkli deploy 0x06c5782124c2d5047f4d5413cea0da564172ad099d5b5c37ce54c9e5d91dc917 --salt 1
```

This will give you the _starknet_ address of the deployed Counter contract. You can interact with it using the `starkli` tool.

```
starkli invoke 0x0606d7ab23440e73e30cf7bd17f9097ac0fcd2dc53a24785ee209f9c57dd9d05 increment
starkli call 0x0606d7ab23440e73e30cf7bd17f9097ac0fcd2dc53a24785ee209f9c57dd9d05 number
```

## Interacting with the Cairo Counter from Solidity

The `CairoCounterCaller.sol` contract demonstrates how one can interact with the Cairo Counter contract from Solidity. The Cairo Counter is deployed on the "Starknet side" of Kakarot and can be interacted with from the "EVM side" of Kakarot.

Let's deploy the `CairoCounterCaller` contract, providing as constructor argument the _starknet_ address of the deployed Cairo Counter contract:

> ⚠️ Don't forget to update the commands with your actual values

```sh
forge create solidity_contracts/src/CairoCounterCaller.sol:CairoCounterCaller --constructor-args 0x0606d7ab23440e73e30cf7bd17f9097ac0fcd2dc53a24785ee209f9c57dd9d05 --private-key $PRIVATE_KEY
```

This will deploy a solidity contract, on Kakarot, that is able to interact with the Cairo Counter contract. However, before that, we need to _whitelist_ this contract to authorize it to call arbitrary contracts on the Starknet side.

```sh
make whitelist-contract CONTRACT_ADDRESS=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

You can then interact with the `CairoCounterCaller` contract using `cast`. By calling `incrementCairoCounter()`, the contract will call the Cairo Counter contract to increment the counter.

```sh
cast send 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "setCairoNumber(uint256 newNumber)" 10 --private-key $PRIVATE_KEY
```

We can then verify the counter value by calling `getCairoNumber()` on the solidity contract, or `number` on the Cairo contract.:

```sh
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0  "getCairoNumber()"
> 0x000000000000000000000000000000000000000000000000000000000000000a
```
