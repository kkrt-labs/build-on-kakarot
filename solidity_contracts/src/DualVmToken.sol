// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

using CairoLib for uint256;

/// @notice EVM adapter into a Cairo ERC20 token
/// @author Kakarot
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
contract DualVMToken {

    /*//////////////////////////////////////////////////////////////
                        CAIRO SPECIFIC VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 immutable cairoToken;
    uint256 immutable kakarotStarknetAddress;


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA ACCESS
    //////////////////////////////////////////////////////////////*/

    function name() public view returns (string memory) {
        bytes memory returnData = cairoToken.staticcallCairo("name");
        return CairoLib.byteArrayToString(returnData);
    }

    function symbol() public view returns (string memory) {
        bytes memory returnData = cairoToken.staticcallCairo("symbol");
        return CairoLib.byteArrayToString(returnData);
    }

    function decimals() public view returns (uint8) {
        bytes memory returnData = cairoToken.staticcallCairo("decimals");
        return abi.decode(returnData, (uint8));
    }

//     /*//////////////////////////////////////////////////////////////
//                               ERC20 STORAGE
//     //////////////////////////////////////////////////////////////*/

    function totalSupply() public view returns (uint256) {
        bytes memory returnData = cairoToken.staticcallCairo("total_supply");
        return abi.decode(returnData, (uint256));
    }

    function balanceOf(address account) public view returns (uint256){
        uint256[] memory kakarotCallData = new uint256[](1);
        kakarotCallData[0] = uint256(uint160(account));
        uint256 accountStarknetAddress = abi.decode(kakarotStarknetAddress.staticcallCairo("compute_starknet_address", kakarotCallData), (uint256));
        uint256[] memory balanceOfCallData = new uint256[](1);
        balanceOfCallData[0] = accountStarknetAddress;
        return abi.decode(cairoToken.staticcallCairo("balance_of", balanceOfCallData), (uint256));
    }

    function allowance(address owner, address spender) public view returns (uint256){
        uint256[] memory ownerAddressCalldata = new uint256[](1);
        ownerAddressCalldata[0] = uint256(uint160(owner));
        uint256 ownerStarknetAddress = abi.decode(kakarotStarknetAddress.staticcallCairo("compute_starknet_address", ownerAddressCalldata), (uint256));

        uint256[] memory spenderAddressCalldata = new uint256[](1);
        spenderAddressCalldata[0] = uint256(uint160(spender));
        uint256 spenderStarknetAddress = abi.decode(kakarotStarknetAddress.staticcallCairo("compute_starknet_address", spenderAddressCalldata), (uint256));

        uint256[] memory allowanceCallData = new uint256[](2);
        allowanceCallData[0] = ownerStarknetAddress;
        allowanceCallData[1] = spenderStarknetAddress;

        bytes memory returnData = cairoToken.staticcallCairo("allowance", allowanceCallData);
        (uint128 value1, uint128 value2) = abi.decode(returnData, (uint128, uint128));

        return uint256(value1) + (uint256(value2) << 128);
    }

    function computeStarknetAddress(address account) public view returns (uint256){
        uint256[] memory kakarotCallData = new uint256[](1);
        kakarotCallData[0] = uint256(uint160(account));
        return abi.decode(kakarotStarknetAddress.staticcallCairo("compute_starknet_address", kakarotCallData), (uint256));
    }

    function computeStarknetAddressRaw(uint256 account) public view returns (bytes memory){
        uint256[] memory kakarotCallData = new uint256[](1);
        kakarotCallData[0] = account;
        return kakarotStarknetAddress.staticcallCairo("compute_starknet_address", kakarotCallData);
    }

    function expectRevert() public view returns (uint256){
        uint256[] memory data = new uint256[](0);
        bytes memory callData =
            abi.encodeWithSignature("call_contract(uint256,uint256,uint256[])", kakarotStarknetAddress, uint256(keccak256(bytes("get_cairo1_helpers_class_hash"))) % 2 ** 250, data);

        (bool success, bytes memory result) = address(0x75001).staticcall(callData);
        require(success, string(abi.encodePacked("CairoLib: call_contract failed. Result: ", result)));
    }

//     mapping(address => uint256) public balanceOf;

//     /*//////////////////////////////////////////////////////////////
//                             EIP-2612 STORAGE
//     //////////////////////////////////////////////////////////////*/

//     uint256 internal immutable INITIAL_CHAIN_ID;

//     bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

//     mapping(address => uint256) public nonces;

//     /*//////////////////////////////////////////////////////////////
//                                CONSTRUCTOR
//     //////////////////////////////////////////////////////////////*/

        constructor(uint256 _kakarotStarknetAddress, uint256 _cairoToken) {
            kakarotStarknetAddress = _kakarotStarknetAddress;
            cairoToken = _cairoToken;
        }



//     /*//////////////////////////////////////////////////////////////
//                                ERC20 LOGIC
//     //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) external returns (bool) {
        uint256[] memory spenderAddressCalldata = new uint256[](1);
        spenderAddressCalldata[0] = uint256(uint160(spender));
        uint256 spenderStarknetAddress = abi.decode(kakarotStarknetAddress.staticcallCairo("compute_starknet_address", spenderAddressCalldata), (uint256));

        // Split amount in [low, high]
        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);
        uint256[] memory approveCallData = new uint256[](3);
        approveCallData[0] = spenderStarknetAddress;
        approveCallData[1] = uint256(amountLow);
        approveCallData[2] = uint256(amountHigh);

        cairoToken.delegatecallCairo("approve", approveCallData);

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256[] memory toAddressCalldata = new uint256[](1);
        toAddressCalldata[0] = uint256(uint160(to));
        uint256 toStarknetAddress = abi.decode(kakarotStarknetAddress.staticcallCairo("compute_starknet_address", toAddressCalldata), (uint256));

        // Split amount in [low, high]
        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);

        uint256[] memory transferCallData = new uint256[](3);
        transferCallData[0] = toStarknetAddress;
        transferCallData[1] = uint256(amountLow);
        transferCallData[2] = uint256(amountHigh);

        cairoToken.delegatecallCairo("transfer", transferCallData);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256[] memory fromAddressCalldata = new uint256[](1);
        fromAddressCalldata[0] = uint256(uint160(from));
        uint256 fromStarknetAddress = abi.decode(kakarotStarknetAddress.staticcallCairo("compute_starknet_address", fromAddressCalldata), (uint256));

        uint256[] memory toAddressCalldata = new uint256[](1);
        toAddressCalldata[0] = uint256(uint160(to));
        uint256 toStarknetAddress = abi.decode(kakarotStarknetAddress.staticcallCairo("compute_starknet_address", toAddressCalldata), (uint256));

        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);

        uint256[] memory transferFromCallData = new uint256[](4);
        transferFromCallData[0] = fromStarknetAddress;
        transferFromCallData[1] = toStarknetAddress;
        transferFromCallData[2] = uint256(amountLow);
        transferFromCallData[3] = uint256(amountHigh);

        cairoToken.delegatecallCairo("transfer_from", transferFromCallData);

        emit Transfer(from, to, amount);

        return true;
    }

//     /*//////////////////////////////////////////////////////////////
//                              EIP-2612 LOGIC
//     //////////////////////////////////////////////////////////////*/

//     function permit(
//         address owner,
//         address spender,
//         uint256 value,
//         uint256 deadline,
//         uint8 v,
//         bytes32 r,
//         bytes32 s
//     ) public virtual {
//         require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

//         // Unchecked because the only math done is incrementing
//         // the owner's nonce which cannot realistically overflow.
//         unchecked {
//             address recoveredAddress = ecrecover(
//                 keccak256(
//                     abi.encodePacked(
//                         "\x19\x01",
//                         DOMAIN_SEPARATOR(),
//                         keccak256(
//                             abi.encode(
//                                 keccak256(
//                                     "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
//                                 ),
//                                 owner,
//                                 spender,
//                                 value,
//                                 nonces[owner]++,
//                                 deadline
//                             )
//                         )
//                     )
//                 ),
//                 v,
//                 r,
//                 s
//             );

//             require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

//             allowance[recoveredAddress][spender] = value;
//         }

//         emit Approval(owner, spender, value);
//     }

//     function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
//         return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
//     }

//     function computeDomainSeparator() internal view virtual returns (bytes32) {
//         return
//             keccak256(
//                 abi.encode(
//                     keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
//                     keccak256(bytes(name)),
//                     keccak256("1"),
//                     block.chainid,
//                     address(this)
//                 )
//             );
//     }

//     /*//////////////////////////////////////////////////////////////
//                         INTERNAL MINT/BURN LOGIC
//     //////////////////////////////////////////////////////////////*/

//     function _mint(address to, uint256 amount) internal virtual {
//         totalSupply += amount;

//         // Cannot overflow because the sum of all user
//         // balances can't exceed the max uint256 value.
//         unchecked {
//             balanceOf[to] += amount;
//         }

//         emit Transfer(address(0), to, amount);
//     }

//     function _burn(address from, uint256 amount) internal virtual {
//         balanceOf[from] -= amount;

//         // Cannot underflow because a user's balance
//         // will never be larger than the total supply.
//         unchecked {
//             totalSupply -= amount;
//         }

//         emit Transfer(from, address(0), amount);
//     }
}
