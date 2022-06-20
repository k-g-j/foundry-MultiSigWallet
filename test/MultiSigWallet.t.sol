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
        vm.deal(address(multiSigWallet), 0.1 ether);
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
        (bool success, ) = payable(multiSigWallet).call{value: 0.4 ether}("");
        require(success, "external contract call failed");
        assertEq(address(multiSigWallet).balance, 0.5 ether);
    }

    function test__receiveFallbackEvent() public {
        vm.expectEmit(false, false, false, true);
        (bool success, ) = payable(multiSigWallet).call{value: 0.2 ether}("");
        require(success, "external contract call failed");
        emit Deposit(address(this), 0.2 ether, address(multiSigWallet).balance);
    }

    function test_submitTxOnlyOwner() public {
        vm.prank(elon);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        multiSigWallet.submitTx(address(rick), 0.1 ether, bytes("0x"));
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

    function test_approveTxOnlyOwner() public {
        vm.prank(elon);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        multiSigWallet.approveTx(0);
    }

    function test_approveTxTxExists() public {
        vm.expectRevert(MultiSigWallet.TxDoesNotExist.selector);
        multiSigWallet.approveTx(1);
    }

    function test_approveTxNotExecuted() public {
        vm.prank(rick);
        multiSigWallet.approveTx(0);
        vm.prank(morty);
        multiSigWallet.approveTx(0);
        multiSigWallet.executeTx(0);
        vm.expectRevert(MultiSigWallet.TxAlreadyExecuted.selector);
        multiSigWallet.approveTx(0);
    }

    function test_approveTxNotApproved() public {
        multiSigWallet.approveTx(0);
        vm.expectRevert(MultiSigWallet.TxAlreadyApproved.selector);
        multiSigWallet.approveTx(0);
    }

    function test_approveTx() public {
        multiSigWallet.approveTx(0);
        assertEq(multiSigWallet.getTransaction(0).confirmations, 1);
        assertTrue(multiSigWallet.checkApproved(0, address(this)));
    }

    function test_approveTxEvent() public {
        vm.expectEmit(false, false, false, true);
        multiSigWallet.approveTx(0);
        emit ApprovedTx(0, address(this));
    }

    function test__executeTxOnlyOwner() public {
        vm.prank(elon);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        multiSigWallet.executeTx(0);
    }

    function test__executeTxTxExists() public {
        vm.expectRevert(MultiSigWallet.TxDoesNotExist.selector);
        multiSigWallet.executeTx(1);
    }

    function test__executeTxTxNotExecuted() public {
        vm.prank(rick);
        multiSigWallet.approveTx(0);
        vm.prank(morty);
        multiSigWallet.approveTx(0);
        multiSigWallet.executeTx(0);
        vm.expectRevert(MultiSigWallet.TxAlreadyExecuted.selector);
        multiSigWallet.executeTx(0);
    }

    function test__executeTxLessConfirmationsThanRequired() public {
        vm.prank(rick);
        multiSigWallet.approveTx(0);
        vm.expectRevert(MultiSigWallet.LessConfirmationsThanRequired.selector);
        multiSigWallet.executeTx(0);
    }

    function test__executeTx() public {
        multiSigWallet.approveTx(0);
        vm.prank(rick);
        multiSigWallet.approveTx(0);
        multiSigWallet.executeTx(0);
        assertEq(address(rick).balance, 0.1 ether);
    }

    function test__executeTxEvent() public {
        multiSigWallet.approveTx(0);
        vm.prank(rick);
        multiSigWallet.approveTx(0);
        vm.expectEmit(false, false, false, true);
        multiSigWallet.executeTx(0);
        emit TxExecuted(
            address(rick),
            0.1 ether,
            bytes("0x8888"),
            address(this)
        );
    }
}
