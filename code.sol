

// SPDX-License-Identifier: MIT



pragma solidity ^0.8.13;
import "ERC20.sol";
import "Ownable.sol";
import "ECDSA.sol";

contract TestToken is ERC20("Avaxtars Token", "AVXT"), Ownable {
    using ECDSA for bytes32;

    // MinterAddress which would eventually be set to address(0)
    address minterAddress;
    address signer;

    mapping(uint => bool) public executed;

    constructor() {
        _setupDecimals(6);
        minterAddress = msg.sender;
    }

    function mint(uint256 amount) external
    {
        require(msg.sender == minterAddress, "OnlyMinter can set this address!");
        _mint(address(this), amount);
    }

    // Change the minter address can only be done by the current minter
    function setMinter(address _minterAddress) external {
        require(msg.sender == minterAddress, "OnlyMinter can set this address!");
        minterAddress = _minterAddress;
    }

    function setSigner(address _signerAddress) public onlyOwner {
        signer = _signerAddress;
    }

    // Burns the callers tokens
    function burnOwnTokens(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

    function transferFromLayer2(uint _amount, uint _nonce, bytes memory _signature)
    external
    {
        require(isValidData(address(msg.sender), _amount, _nonce, _signature), "invalid sig");
        require(!executed[_nonce], "tx executed");

        executed[_nonce] = true;

        _transfer(address(this), address(msg.sender), _amount);

        emit TransferFromLayer2(msg.sender, _nonce, _amount);
    }

    function isValidData(address to, uint amount, uint nonce, bytes memory sig) public view returns(bool){
        bytes32 message = keccak256(abi.encodePacked(address(this), to, amount, nonce));
        return (recoverSigner(message, sig) == signer);
    }

    function deposit(uint _amount)
    public
    {
        transfer(address(this), _amount);

        emit TransferToLayer2(msg.sender, _amount);
    }


    function recoverSigner(bytes32 message, bytes memory sig)
    public
    pure
    returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);
        return ecrecover(message, v, r, s);
    }

    function splitSignature(bytes memory sig)
    public
    pure
    returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;

    }

    event TransferFromLayer2(address indexed to, uint256 nonce, uint256 amount);
    event TransferToLayer2(address indexed to, uint256 amount);
}
