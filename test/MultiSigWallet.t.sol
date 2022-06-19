// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    event Deposit(address sender, uint256 value, uint256 balance);
    event SubmittedTx(address to, uint256 value, bytes data);
    event ApprovedTx(uint256 txId, address approver);
    event TxExecuted(address to, uint256 value, bytes data, address executor);

    address rick = address(0x1234);
    address morty = address(0x5678);
    address elon = address(0x7777);

    MultiSigWallet multiSigWallet;

    address[] _owners = [address(this), address(rick), address(morty)];

    function setUp() public {
        vm.label(rick, "Rick");
        vm.label(morty, "Morty");
        vm.label(elon, "elon");
        vm.label(address(multiSigWallet), "MultiSigWallet");
        vm.label(address(this), "Tester");

        multiSigWallet = new MultiSigWallet(_owners, 2);
        multiSigWallet.submitTx(address(rick), 0.1 ether, bytes("0x8888"));
    }

    function test__constructorGreaterThanRequired() public {
        vm.expectRevert(MultiSigWallet.InvalidNumRequired.selector);
        multiSigWallet = new MultiSigWallet(_owners, 4);
    }

    function test_constructorInvalidAddress() public {
        vm.expectRevert(MultiSigWallet.InvalidOwnerAddress.selector);
        _owners = [address(this), address(0), address(rick)];
        multiSigWallet = new MultiSigWallet(_owners, 2);
    }

    function test_constructorRepeatAddress() public {
        vm.expectRevert(MultiSigWallet.AlreadyOwner.selector);
        _owners = [address(this), address(this), address(rick)];
        multiSigWallet = new MultiSigWallet(_owners, 2);
    }

    function test_receiveFallback() public {
        vm.expectEmit(false, false, false, true);
        (bool success, ) = payable(multiSigWallet).call{value: 0.1 ether}("");
        require(success, "contract call failed");
        emit Deposit(address(this), 0.1 ether, address(multiSigWallet).balance);
        assertEq(address(multiSigWallet).balance, 0.1 ether);
    }

    function test_submitTxNotOwner() public {
        vm.startPrank(elon);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        multiSigWallet.submitTx(address(rick), 0.1 ether, bytes("0x"));
        vm.stopPrank();
    }

    function test_submitTx() public {
        multiSigWallet.submitTx(address(morty), 0.3 ether, bytes("0x4444"));
        assertEq(multiSigWallet.getTransaction(1).id, 1);
        assertEq(multiSigWallet.getTransaction(1).to, address(morty));
        assertEq(multiSigWallet.getTransaction(1).value, 0.3 ether);
        assertEq(multiSigWallet.getTransaction(1).data, bytes("0x4444"));
        assertEq(multiSigWallet.getTransaction(1).confirmations, 0);
        assertEq(multiSigWallet.getTransaction(1).executed, false);
    }

    function test__submitTxEvent() public {
        vm.expectEmit(false, false, false, true);
        multiSigWallet.submitTx(address(morty), 0.3 ether, bytes("0x4444"));
        emit SubmittedTx(address(morty), 0.3 ether, bytes("0x4444"));
    }
}
