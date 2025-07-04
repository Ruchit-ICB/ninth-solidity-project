// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Imports from OpenZeppelin (JSDelivr CDN)
import "https://cdn.jsdelivr.net/npm/@openzeppelin/contracts@4.9.3/token/ERC721/IERC721.sol";
import "https://cdn.jsdelivr.net/npm/@openzeppelin/contracts@4.9.3/token/ERC20/IERC20.sol";
import "https://cdn.jsdelivr.net/npm/@openzeppelin/contracts@4.9.3/access/Ownable.sol";

contract NFTStaking is Ownable {
    IERC721 public immutable nft;
    IERC20 public immutable rewardToken;

    uint public rewardRatePerSecond = 1e16; // 0.01 token/sec

    struct Stake {
        address owner;
        uint256 stakedAt;
    }

    // tokenId => Stake
    mapping(uint => Stake) public stakes;
    mapping(address => uint[]) public stakedTokens;

    event Staked(address indexed user, uint indexed tokenId);
    event Unstaked(address indexed user, uint indexed tokenId, uint reward);

    constructor(address _nft, address _rewardToken) {
        nft = IERC721(_nft);
        rewardToken = IERC20(_rewardToken);
    }

    function stake(uint tokenId) external {
        require(nft.ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        require(stakes[tokenId].owner == address(0), "Already staked");

        nft.transferFrom(msg.sender, address(this), tokenId);

        stakes[tokenId] = Stake({
            owner: msg.sender,
            stakedAt: block.timestamp
        });

        stakedTokens[msg.sender].push(tokenId);

        emit Staked(msg.sender, tokenId);
    }

    function unstake(uint tokenId) external {
        Stake memory staked = stakes[tokenId];
        require(staked.owner == msg.sender, "Not your stake");

        uint stakedTime = block.timestamp - staked.stakedAt;
        uint reward = stakedTime * rewardRatePerSecond;

        // Clean up
        delete stakes[tokenId];
        _removeToken(msg.sender, tokenId);

        // Transfer NFT back
        nft.transferFrom(address(this), msg.sender, tokenId);

        // Transfer ERC20 reward
        require(rewardToken.balanceOf(address(this)) >= reward, "Not enough reward tokens");
        rewardToken.transfer(msg.sender, reward);

        emit Unstaked(msg.sender, tokenId, reward);
    }

    function getStakedTokens(address user) external view returns (uint[] memory) {
        return stakedTokens[user];
    }

    function fund(uint amount) external onlyOwner {
        rewardToken.transferFrom(msg.sender, address(this), amount);
    }

    function _removeToken(address user, uint tokenId) internal {
        uint[] storage tokens = stakedTokens[user];
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }
}
