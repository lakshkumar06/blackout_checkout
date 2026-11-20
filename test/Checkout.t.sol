// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/BlackoutCheckout.sol";

interface Vm {
    function addr(uint256) external returns (address);
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    function deal(address, uint256) external;
    function prank(address) external;
    function warp(uint256) external;
}

contract CheckoutTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 constant VENDOR_KEY = 0xA11CE;
    uint256 constant PAYER_KEY = 0xB0B;
    BlackoutCheckout checkout;
    address vendor;
    address payer;

    function setUp() public {
        checkout = new BlackoutCheckout();
        vendor = vm.addr(VENDOR_KEY);
        payer = vm.addr(PAYER_KEY);
        vm.deal(payer, 10 ether);
        vm.prank(payer);
        checkout.deposit{value: 3 ether}();
    }

    function order() internal view returns (BlackoutCheckout.Order memory) {
        return BlackoutCheckout.Order({id: bytes16(uint128(1)), vendor: payable(vendor), payer: payer,
            amount: 1 ether, deadline: uint64(block.timestamp + 1 days)});
    }

    function signatures(BlackoutCheckout.Order memory o) internal returns (bytes memory receiveSig, bytes memory sendSig) {
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(VENDOR_KEY, checkout.receiveDigest(o));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(PAYER_KEY, checkout.sendDigest(o));
        return (abi.encodePacked(r1, s1, v1), abi.encodePacked(r2, s2, v2));
    }

    function testDepositSettleReplayAndWithdraw() public {
        BlackoutCheckout.Order memory o = order();
        (bytes memory receiveSig, bytes memory sendSig) = signatures(o);
        uint256 beforeVendor = vendor.balance;
        checkout.settle(o, receiveSig, sendSig);
        require(vendor.balance == beforeVendor + 1 ether, "vendor not paid");
        require(checkout.balanceOf(payer) == 2 ether, "escrow not debited");
        require(checkout.settled(checkout.orderKey(vendor, o.id)), "order not consumed");
        (bool replay,) = address(checkout).call(abi.encodeCall(checkout.settle, (o, receiveSig, sendSig)));
        require(!replay, "replay accepted");
        vm.prank(payer);
        checkout.withdraw(2 ether);
        require(checkout.balanceOf(payer) == 0, "withdraw failed");
    }

    function testTamperedTermsAndMissingFundsFail() public {
        BlackoutCheckout.Order memory o = order();
        (bytes memory receiveSig, bytes memory sendSig) = signatures(o);
        o.amount = 2 ether;
        (bool tampered,) = address(checkout).call(abi.encodeCall(checkout.settle, (o, receiveSig, sendSig)));
        require(!tampered, "tampered amount accepted");
        o.amount = 1 ether;
        vm.prank(payer);
        checkout.withdraw(3 ether);
        (bool unfunded,) = address(checkout).call(abi.encodeCall(checkout.settle, (o, receiveSig, sendSig)));
        require(!unfunded, "unfunded payment accepted");
    }

    function testExpiredIntentFails() public {
        BlackoutCheckout.Order memory o = order();
        (bytes memory receiveSig, bytes memory sendSig) = signatures(o);
        vm.warp(o.deadline + 1);
        (bool expired,) = address(checkout).call(abi.encodeCall(checkout.settle, (o, receiveSig, sendSig)));
        require(!expired, "expired intent accepted");
    }
}
