// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

contract MultiSigDeployScript is Script {

  address[] owners;

    function setUp() public {
      if (block.chainid == 31337) {
        owners = [0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC];
      } else {
        owners = [0xda1D3f95B7C67D9103D30C4437610437A137d891, 0x8423f6c5f0895914e0C8A4eF523C0A1d5c8632f6, 0x70185775Ae9767751c218d9baAeffBC9b5fD5b34];
      }
    }

    function run() public {
        vm.broadcast();
        new MultiSigWallet(owners, 2);
        vm.stopBroadcast();
    }
}
