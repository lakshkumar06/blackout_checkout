// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Prepaid native USDC escrow for delayed, two-signature Arc Testnet sales.
contract BlackoutCheckout {
    struct Order {
        bytes16 id;
        address payable vendor;
        address payer;
        uint256 amount;
        uint64 deadline;
    }

    bytes32 private constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant RECEIVE_TYPEHASH = keccak256("Receive(bytes16 id,address vendor,uint256 amount,uint64 deadline)");
    bytes32 private constant SEND_TYPEHASH = keccak256("Send(bytes16 id,address vendor,address payer,uint256 amount,uint64 deadline)");
    uint256 private constant HALF_ORDER = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    bytes32 public immutable DOMAIN_SEPARATOR;
    mapping(address => uint256) public balanceOf;
    mapping(bytes32 => bool) public settled;

    event Deposited(address indexed payer, uint256 amount);
    event Withdrawn(address indexed payer, uint256 amount);
    event OrderPaid(bytes16 indexed orderId, address indexed vendor, address indexed payer, uint256 amount);

    error InvalidOrder();
    error InvalidSignature();
    error Expired();
    error AlreadyPaid();
    error InsufficientBalance();
    error ForwardFailed();

    constructor() {
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH,
            keccak256(bytes("Blackout Checkout")), keccak256(bytes("2")), block.chainid, address(this)));
    }

    function deposit() external payable {
        if (msg.value == 0) revert InvalidOrder();
        balanceOf[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0 || balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        if (!sent) revert ForwardFailed();
        emit Withdrawn(msg.sender, amount);
    }

    function orderKey(address vendor, bytes16 id) public pure returns (bytes32) {
        return keccak256(abi.encode(vendor, id));
    }

    function receiveDigest(Order calldata o) public view returns (bytes32) {
        return _digest(keccak256(abi.encode(RECEIVE_TYPEHASH, o.id, o.vendor, o.amount, o.deadline)));
    }

    function sendDigest(Order calldata o) public view returns (bytes32) {
        return _digest(keccak256(abi.encode(SEND_TYPEHASH, o.id, o.vendor, o.payer, o.amount, o.deadline)));
    }

    function settle(Order calldata o, bytes calldata receiveSignature, bytes calldata sendSignature) external {
        if (o.id == bytes16(0) || o.vendor == address(0) || o.payer == address(0) || o.amount == 0) revert InvalidOrder();
        if (block.timestamp > o.deadline) revert Expired();
        bytes32 key = orderKey(o.vendor, o.id);
        if (settled[key]) revert AlreadyPaid();
        if (_recover(receiveDigest(o), receiveSignature) != o.vendor ||
            _recover(sendDigest(o), sendSignature) != o.payer) revert InvalidSignature();
        if (balanceOf[o.payer] < o.amount) revert InsufficientBalance();
        settled[key] = true;
        balanceOf[o.payer] -= o.amount;
        (bool sent,) = o.vendor.call{value: o.amount}("");
        if (!sent) revert ForwardFailed();
        emit OrderPaid(o.id, o.vendor, o.payer, o.amount);
    }

    function _digest(bytes32 structHash) private view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function _recover(bytes32 digest, bytes calldata signature) private pure returns (address) {
        if (signature.length != 65) revert InvalidSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        if (v < 27 || v > 28 || uint256(s) > HALF_ORDER) revert InvalidSignature();
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return signer;
    }
}
