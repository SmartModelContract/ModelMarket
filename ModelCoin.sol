// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ModelCoin is ERC20, Ownable(msg.sender) {
    uint256 private _totalSupply = 1000000 * (10 ** uint256(decimals())); // Set total supply
    mapping(address => bool) public hasClaimed;

    event Airdropped(address recipient, uint256 amount);

    constructor() ERC20("ModelCoin", "MDC") {
        _mint(msg.sender, _totalSupply);
    }

    // Airdrop function to allow users to claim tokens
    function claimAirdrop() public {
        require(!hasClaimed[msg.sender], "Airdrop already claimed by this address.");
        uint256 airdropAmount = _totalSupply / 1000;
        require(balanceOf(owner()) >= airdropAmount, "Not enough tokens in owner's balance for airdrop.");

        // Transfer the airdrop tokens from the owner to the claimant
        _transfer(owner(), msg.sender, airdropAmount);
        hasClaimed[msg.sender] = true; // Mark as claimed

        emit Airdropped(msg.sender, airdropAmount);
    }
}
