// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./interfaces/IAxeNFTInfo.sol";

contract AxeNFT is
	IAxeNFTInfo,
	ERC721Enumerable,
	Ownable,
	ReentrancyGuard,
	Pausable
{
	uint256 private nextTokenId = 1;

	mapping(uint256 => uint256) public _nftPrices;

	mapping(uint256 => uint256) public _nftLevels;

	// mapping account => level => [tokenIds]
	mapping(address => mapping(uint256 => uint256[]))
		public _balanceByNFTLevels;

	event Minted(uint256 indexed tokenId, address user, uint256 level);

	constructor() ERC721("Jack Trump Axe", "AXE") {
		_nftPrices[1] = 0.0008 ether;
		_nftPrices[2] = 0.0011 ether;
		_nftPrices[3] = 0.0013 ether;
		_nftPrices[4] = 0.0022 ether;
		_nftPrices[5] = 0.0133 ether;
	}

	function mint(
		uint256 quantity,
		uint256 level
	) external payable whenNotPaused nonReentrant {
		require(quantity > 0, "Minimum 1 NFT");
		require(_nftPrices[level] != 0, "NFT level invalid");
		require(
			msg.value >= quantity * _nftPrices[level],
			"Insufficient payment for the requested quantity."
		);

		for (uint256 i = 0; i < quantity; i++) {
			_mint(_msgSender(), nextTokenId);
			_nftLevels[nextTokenId] = level;
			_balanceByNFTLevels[_msgSender()][level].push(nextTokenId);
			emit Minted(nextTokenId, _msgSender(), level);
			nextTokenId++;
		}
	}

	function setSalePrice(uint256 level, uint256 price) external onlyOwner {
		require(level > 0 && price > 0, "Zero input");
		_nftPrices[level] = price;
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 firstTokenId,
		uint256 batchSize
	) internal virtual override {
		uint256 level = _nftLevels[firstTokenId];
		if (from != address(0)) {
			for (uint i = 0; i < _balanceByNFTLevels[from][level].length; i++) {
				if (firstTokenId == _balanceByNFTLevels[from][level][i]) {
					delete _balanceByNFTLevels[from][level][i];
					break;
				}
			}
		}
		if (to != address(0)) _balanceByNFTLevels[to][level].push(firstTokenId);
		super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
	}

	function withdraw() external onlyOwner {
		(bool success, ) = payable(msg.sender).call{
			value: address(this).balance
		}("");
		require(success, "Withdraw failed.");
	}

	function pauseContract() external whenNotPaused onlyOwner {
		_pause();
	}

	function unpauseContract() external whenPaused onlyOwner {
		_unpause();
	}

	function getLevel(uint256 tokenId) external view returns (uint256) {
		return _nftLevels[tokenId];
	}

	function getAccountBalanceByLevel(
		address account,
		uint256 level
	) external view returns (uint256[] memory) {
		return _balanceByNFTLevels[account][level];
	}
}
