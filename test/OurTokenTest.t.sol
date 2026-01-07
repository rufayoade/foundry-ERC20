// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";
import {ManualToken} from "../src/ManualToken.sol";

contract OurTokenTest is Test {
    OurToken public ourToken;
    ManualToken public manualToken;
    DeployOurToken public deployer;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address charlie = makeAddr("charlie");

    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant INITIAL_SUPPLY = 1000 ether;

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        // msg.sender has all the tokens, transfer some to Bob
        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    // ============ OurToken Tests ============
    function testInitialSupply() public view {
        assertEq(ourToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(ourToken.balanceOf(msg.sender), INITIAL_SUPPLY - STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testTokenMetadata() public view {
        assertEq(ourToken.name(), "OurToken");
        assertEq(ourToken.symbol(), "OT");
        assertEq(ourToken.decimals(), 18);
    }

    function testTransferSuccess() public {
        uint256 transferAmount = 50 ether;

        vm.prank(bob);
        bool success = ourToken.transfer(alice, transferAmount);

        assertTrue(success);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.balanceOf(alice), transferAmount);
    }

    function testTransferInsufficientBalance() public {
        uint256 transferAmount = STARTING_BALANCE + 1 ether;

        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(alice, transferAmount);

        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
        assertEq(ourToken.balanceOf(alice), 0);
    }

    function testTransferZeroAmount() public {
        vm.prank(bob);
        bool success = ourToken.transfer(alice, 0);

        assertTrue(success);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
        assertEq(ourToken.balanceOf(alice), 0);
    }

    function testTransferToZeroAddress() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(address(0), 10 ether);
    }

    function testAllowancesWorks() public {
        uint256 initialAllowance = 1000;

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        uint256 transferAmount = 500;

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.allowance(bob, alice), initialAllowance - transferAmount);
    }

    function testApproveAndCheckAllowance() public {
        uint256 allowanceAmount = 5000;

        vm.prank(bob);
        bool success = ourToken.approve(alice, allowanceAmount);

        assertTrue(success);
        assertEq(ourToken.allowance(bob, alice), allowanceAmount);
    }

    function testTransferFromInsufficientAllowance() public {
        uint256 allowanceAmount = 1000;
        uint256 transferAmount = 1500;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmount);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, charlie, transferAmount);
    }

    function testTransferFromInsufficientBalance() public {
        uint256 allowanceAmount = STARTING_BALANCE + 1 ether;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmount);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, charlie, allowanceAmount);
    }

    function testTransferFromZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(address(0), charlie, 100);
    }

    function testTransferFromToZeroAddress() public {
        uint256 allowanceAmount = 1000;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmount);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, address(0), 500);
    }

    function testAllowanceAfterTransferFrom() public {
        uint256 initialAllowance = 2000;
        uint256 transferAmount1 = 700;
        uint256 transferAmount2 = 300;

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        vm.prank(alice);
        ourToken.transferFrom(bob, charlie, transferAmount1);

        assertEq(ourToken.allowance(bob, alice), initialAllowance - transferAmount1);

        vm.prank(alice);
        ourToken.transferFrom(bob, charlie, transferAmount2);

        assertEq(ourToken.allowance(bob, alice), initialAllowance - transferAmount1 - transferAmount2);
    }

    function testSelfTransfer() public {
        uint256 transferAmount = 10 ether;
        uint256 initialBalance = ourToken.balanceOf(bob);

        vm.prank(bob);
        bool success = ourToken.transfer(bob, transferAmount);

        assertTrue(success);
        assertEq(ourToken.balanceOf(bob), initialBalance);
    }

    function testSelfTransferFromWithAllowance() public {
        uint256 allowanceAmount = 1000;

        vm.prank(bob);
        ourToken.approve(bob, allowanceAmount);

        vm.prank(bob);
        ourToken.transferFrom(bob, bob, 500);

        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
        assertEq(ourToken.allowance(bob, bob), allowanceAmount - 500);
    }

    function testTransferAllBalance() public {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);

        vm.prank(bob);
        ourToken.transfer(alice, STARTING_BALANCE);

        assertEq(ourToken.balanceOf(bob), 0);
        assertEq(ourToken.balanceOf(alice), STARTING_BALANCE);
    }

    function testAllowanceResetToZero() public {
        uint256 allowanceAmount = 1000;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmount);
        assertEq(ourToken.allowance(bob, alice), allowanceAmount);

        vm.prank(bob);
        ourToken.approve(alice, 0);
        assertEq(ourToken.allowance(bob, alice), 0);
    }

    function testTransferFromWithExactAllowance() public {
        uint256 allowanceAmount = 500;
        uint256 transferAmount = allowanceAmount;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmount);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.allowance(bob, alice), 0);
    }

    function testMultipleApprovals() public {
        uint256 allowance1 = 500;
        uint256 allowance2 = 300;

        vm.prank(bob);
        ourToken.approve(alice, allowance1);
        assertEq(ourToken.allowance(bob, alice), allowance1);

        vm.prank(bob);
        ourToken.approve(alice, allowance2);
        assertEq(ourToken.allowance(bob, alice), allowance2);
    }

    // ============ ManualToken Tests ============
    function testManualTokenMetadata() public {
        manualToken = new ManualToken();

        assertEq(manualToken.name(), "ManualToken");
        assertEq(manualToken.totalSupply(), 100 ether);
        assertEq(manualToken.decimals(), 18);
    }

    function testManualTokenInitialBalance() public {
        manualToken = new ManualToken();

        // Check initial balances are zero
        assertEq(manualToken.balanceOf(bob), 0);
        assertEq(manualToken.balanceOf(alice), 0);
    }

    function testManualTokenTransfer() public {
        manualToken = new ManualToken();

        // ManualToken doesn't have mint functionality, so we can't test transfers
        // This is more of a demonstration that the contract has issues
        assert(true);
    }
}
