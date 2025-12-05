// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract DemoPriceFeed {
    uint80 rId = 2;
    int256 ans = 410450930000;
    uint256 sAt = 23;
    uint256 uAt = 23;
    uint80 aInRound = 23;
    function latestRoundData()
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (rId, ans, sAt, uAt, aInRound);
    }

    function decimals() external pure returns (uint8){
        return 8; // Example decimal value
    }
}
