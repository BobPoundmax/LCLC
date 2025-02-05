// PrizeManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PrizeManager
 * @dev Manages prize pools, distributions, and random winner selection.
 */
contract SelectWinner {

    /**
     * @notice Selects a random winner from a list of users based on their balances and total supply.
     * @param totalSupply The total supply of tokens.
     * @param userBalances An array of balances corresponding to the users.
     * @return winnerAddress The randomly selected winner's address.
     */
    function selectWinner(uint256 totalSupply, address[] calldata userAddresses, uint256[] calldata userBalances) 
        external 
        view 
        returns (address winnerAddress) 
    {
        require(userAddresses.length == userBalances.length, "Input arrays must have the same length");
        require(totalSupply > 0, "Total supply must be greater than 0");

        // Step 1: Generate a random seed using multiple entropy sources
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.number,
            blockhash(block.number - 1),
            msg.sender,
            address(this).balance,
            gasleft(),
            tx.gasprice,
            totalSupply
        )));

        // Step 2: Generate a final random number based on the seed
        uint256 random = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.number,
            blockhash(block.number - 1),
            msg.sender,
            address(this).balance,
            randomSeed
        )));

        // Step 3: Select a winner proportionally based on balances
        uint256 cumulativeWeight = 0;
        uint256 winningValue = random % totalSupply;

        for (uint256 i = 0; i < userBalances.length; i++) {
            cumulativeWeight += userBalances[i];
            if (winningValue < cumulativeWeight) {
                return userAddresses[i];
            }
        }

        revert("Winner could not be determined");
    }
}