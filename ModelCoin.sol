// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ModelCoin is ERC20, Ownable {
    constructor() ERC20("ModelCoin", "MDC") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals()))); // making money out of thin air for airdrop (initial mint)
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

// Airdrop
contract ModelCoinAirdrop is Ownable {
    ModelCoin public token;
    mapping(address => bool) public airdropped;

    event Airdropped(address recipient, uint256 amount);

    constructor(ModelCoin _token) {
        token = _token;
    }

    function airdropTokens(address[] calldata recipients, uint256 amount) public onlyOwner {
        for (uint i = 0; i < recipients.length; i++) {
            if (!airdropped[recipients[i]]) {
                token.transfer(recipients[i], amount);
                airdropped[recipients[i]] = true;
                emit Airdropped(recipients[i], amount);
            }
        }
    }
}
