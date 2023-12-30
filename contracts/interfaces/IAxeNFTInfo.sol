//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IAxeNFTInfo {
	function getLevel(uint256 tokenId) external view returns (uint256);
}
