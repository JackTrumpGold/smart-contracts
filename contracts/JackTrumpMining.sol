// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./interfaces/IAxeNFTInfo.sol";

contract JackTrumpMining is Ownable, Pausable, ReentrancyGuard {
	address public _jackTrumpToken;
	address public _axeNFT;

	uint256 public _stopTime;

	bool public _claimable = false;

	uint256 public _annualProfit;

	uint256 public _startingAmount = 1 ether;

	uint256 public _miningFee = 0;

	uint256 public constant ONE_YEAR = 365 days;
	uint256 public constant USER_MULTIPLIER = 1000;
	uint256 public constant ANNUAL_PROFIT_MULTIPLIER = 1000;
	uint256 public constant REFERRAL_MULTIPLIER = 10; // 0.1 %

	mapping(address => uint256) public _userMiningTimes;

	mapping(address => uint256) public _userLastEarnedTimes;

	mapping(address => uint256) public _userMultiplier;

	mapping(address => uint256) public _userEarneds;

	mapping(address => address) public _referralUser;

	mapping(address => uint256[]) public _userBoostLevels;

	mapping(uint256 => uint256) public _NFTlevelMultiplier; // nft level => mul 1000

	address[] public _miners;

	address public _signer;

	event NewMiner(address account);
	event Boosted(address account, uint256 tokenId, uint256 level);
	event Referral(address referee, address referral);
	event ClaimReward(address account, uint256 amount);
	event Stopped(uint256 time);

	constructor(
		address signer,
		address jackTrumpToken,
		address axeNFT,
		uint256 stopTime
	) {
		_signer = signer;

		_jackTrumpToken = jackTrumpToken;
		_axeNFT = axeNFT;

		_stopTime = stopTime;

		_NFTlevelMultiplier[1] = 1200;
		_NFTlevelMultiplier[2] = 1500;
		_NFTlevelMultiplier[3] = 1800;
		_NFTlevelMultiplier[4] = 2300;
		_NFTlevelMultiplier[5] = 5000;
	}

	function mine(
		address account,
		address referral,
		bytes calldata signature
	) external payable whenNotPaused nonReentrant returns (bool) {
		require(
			msg.value >= _miningFee,
			"Insufficient payment for the requested quantity."
		);

		require(_msgSender() == account, "Invalid sender");
		require(!_isMiner(_msgSender()), "User already joined");

		bytes32 digest = keccak256(abi.encode("mine", account, referral));
		require(
			SignatureChecker.isValidSignatureNow(
				_signer,
				ECDSA.toEthSignedMessageHash(digest),
				signature
			),
			"Invalid signature"
		);

		_miners.push(_msgSender());

		_userMiningTimes[_msgSender()] = block.timestamp;
		_userLastEarnedTimes[_msgSender()] = block.timestamp;
		_userEarneds[_msgSender()] = 0;

		if (_userMultiplier[_msgSender()] == 0)
			_userMultiplier[_msgSender()] = USER_MULTIPLIER;

		// update multiplier for referal
		if (referral != address(0)) {
			if (_userMultiplier[referral] == 0)
				_userMultiplier[referral] = USER_MULTIPLIER;
			if (_isMiner(referral)) _calculateInterest(referral);

			_userMultiplier[referral] += REFERRAL_MULTIPLIER;
			_referralUser[_msgSender()] = referral;

			emit Referral(_msgSender(), referral);
		}

		emit NewMiner(_msgSender());
		return true;
	}

	function boost(uint256 tokenId) external whenNotPaused nonReentrant {
		require(_isMiner(_msgSender()), "User already joined");

		uint256 level = IAxeNFTInfo(_axeNFT).getLevel(tokenId);

		require(level > 0, "Invalid level");

		require(_NFTlevelMultiplier[level] > 0, "NFT level multiplier not set");
		require(
			!_isBoostedLevel(_msgSender(), level),
			"This level already boosted"
		);

		IERC721(_axeNFT).transferFrom(_msgSender(), address(this), tokenId);

		_calculateInterest(_msgSender());

		_userMultiplier[_msgSender()] += (_NFTlevelMultiplier[level] -
			USER_MULTIPLIER);

		_userBoostLevels[_msgSender()].push(level);

		emit Boosted(_msgSender(), tokenId, level);
	}

	function claimReward() external whenNotPaused nonReentrant returns (bool) {
		require(_userMiningTimes[_msgSender()] != 0, "Amount is invalid");
		require(_claimable, "Can not claim right now");

		_calculateInterest(_msgSender());

		uint256 earnedAmount = _userEarneds[_msgSender()];

		if (earnedAmount > 0) {
			IERC20 rwTokenContract = IERC20(_jackTrumpToken);
			if (rwTokenContract.balanceOf(address(this)) >= earnedAmount) {
				require(
					rwTokenContract.transfer(_msgSender(), earnedAmount),
					"Can not pay interest for user"
				);
				_userEarneds[_msgSender()] = 0;
			}
		}

		emit ClaimReward(_msgSender(), earnedAmount);

		return true;
	}

	function setStopTime(uint256 timestamp) external onlyOwner {
		require(timestamp >= block.timestamp, "Stop time invalid");
		_stopTime = timestamp;
		emit Stopped(timestamp);
	}

	function setSigner(address signer) external onlyOwner {
		_signer = signer;
	}

	function setAnnualProfit(uint256 annualProfit) external onlyOwner {
		for (uint256 userIndex = 0; userIndex < _miners.length; userIndex++) {
			_calculateInterest(_miners[userIndex]);
		}
		_annualProfit = annualProfit;
	}

	function setMiningFee(uint256 fee) external onlyOwner {
		_miningFee = fee;
	}

	function setClaimable(bool claimable) external onlyOwner {
		_claimable = claimable;
	}

	function setNFTLevelMultiplier(
		uint256 nftLevel,
		uint256 multiplier
	) external onlyOwner {
		require(nftLevel > 0 && multiplier > 0, "Zero input");
		_NFTlevelMultiplier[nftLevel] = multiplier;
	}

	function updateContract(
		address tokenContract,
		address NFTcontract
	) external onlyOwner {
		_jackTrumpToken = tokenContract;
		_axeNFT = NFTcontract;
	}

	function pauseContract() external whenNotPaused onlyOwner {
		_pause();
	}

	function unpauseContract() external whenPaused onlyOwner {
		_unpause();
	}

	function withdraw(uint256 amount) external onlyOwner {
		(bool success, ) = payable(_msgSender()).call{ value: amount }("");
		require(success, "CAN_NOT_WITHDRAW");
	}

	function withdrawToken(address token, uint256 amount) external onlyOwner {
		IERC20(token).transfer(_msgSender(), amount);
	}

	function getUserEarnedAmount(
		address account
	) external view returns (uint256) {
		uint256 earnedAmount = _userEarneds[account];

		//Calculate pending amount
		if (_userMultiplier[account] != 0)
			earnedAmount += _calculatePendingEarned(
				_userMultiplier[account],
				_getUserRewardPendingTime(account)
			);

		return earnedAmount;
	}

	function getUserLastEarnedTime(
		address account
	) external view returns (uint256) {
		return _getUserLastEarnedTime(account);
	}

	function getUserMiningTime(
		address account
	) external view returns (uint256) {
		return _getUserMiningTime(account);
	}

	function getUserRewardPendingTime(
		address account
	) external view returns (uint256) {
		return _getUserRewardPendingTime(account);
	}

	function getUserMultiplier(
		address account
	) external view returns (uint256) {
		return _userMultiplier[account];
	}

	function getUserBoostedLevels(
		address account
	) external view returns (uint256[] memory) {
		return _userBoostLevels[account];
	}

	function _calculateInterest(address account) internal {
		uint256 multiplier = _userMultiplier[account];
		if (multiplier != 0) {
			uint256 earnedAmount = _calculatePendingEarned(
				multiplier,
				_getUserRewardPendingTime(account)
			);
			_userEarneds[account] += earnedAmount;
		}
		_userLastEarnedTimes[account] = block.timestamp;
	}

	function _calculatePendingEarned(
		uint256 multiplier,
		uint256 pendingTime
	) internal view returns (uint256) {
		return
			(((_startingAmount * multiplier) / USER_MULTIPLIER) *
				pendingTime *
				_annualProfit) /
			ANNUAL_PROFIT_MULTIPLIER /
			ONE_YEAR /
			100;
	}

	function _isMiner(address account) internal view returns (bool) {
		for (uint256 index = 0; index < _miners.length; index++) {
			if (_miners[index] == account) return true;
		}

		return false;
	}

	function _isBoostedLevel(
		address account,
		uint256 level
	) internal view returns (bool) {
		for (
			uint256 index = 0;
			index < _userBoostLevels[account].length;
			index++
		) {
			if (_userBoostLevels[account][index] == level) return true;
		}

		return false;
	}

	function _getUserLastEarnedTime(
		address account
	) internal view returns (uint256) {
		return _userLastEarnedTimes[account];
	}

	function _getUserMiningTime(
		address account
	) internal view returns (uint256) {
		return _userMiningTimes[account];
	}

	function _getUserRewardPendingTime(
		address account
	) internal view returns (uint256) {
		if (block.timestamp > _stopTime)
			return _stopTime - _getUserLastEarnedTime(account);
		return block.timestamp - _getUserLastEarnedTime(account);
	}
}
