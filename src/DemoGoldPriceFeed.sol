// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract DemoGoldPriceFeed {
    uint80 rId =  92233720368547761085;
    int256 ans = 423883000000;
    uint256 sAt = 1760710793;
    uint256 uAt =  1760710811;
    uint80 aInRound =  92233720368547761085;
    bool public isReverse = false;
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
        if(isReverse) {
            return (rId, 523883000000, sAt, uAt, aInRound);
        }else {
            return (rId, ans, sAt, uAt, aInRound);
        }
    }

    function updateReverse(bool _isReverse) public {
        isReverse = _isReverse;
    }

    function decimals() external pure returns (uint8){
        return 8;
    }
}
