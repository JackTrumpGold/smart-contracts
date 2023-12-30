// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JackTrump is ERC20 {
	constructor(uint256 totalSupply) ERC20("Jack Trump Token", "JTRUMP") {
		_mint(msg.sender, totalSupply);
	}
}
