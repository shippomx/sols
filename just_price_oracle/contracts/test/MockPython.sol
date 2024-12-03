// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;


import '@pythnetwork/pyth-sdk-solidity/IPyth.sol';
import '@pythnetwork/pyth-sdk-solidity/PythStructs.sol';

import 'hardhat/console.sol';

contract MockPython is IPyth {

    function getValidTimePeriod()
        external
        view
        override
        returns (uint validTimePeriod)
    {}

    function getPrice(
        bytes32 id
    ) external view override returns (PythStructs.Price memory price) {}

    function getEmaPrice(
        bytes32 id
    ) external view override returns (PythStructs.Price memory price) {}

    function getPriceUnsafe(
        bytes32 id
    ) external view override returns (PythStructs.Price memory price) {}

    function getPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view override returns (PythStructs.Price memory price) {
        //      struct Price {
        //     // Price
        //     int64 price;
        //     // Confidence interval around the price
        //     uint64 conf;
        //     // Price exponent
        //     int32 expo;
        //     // Unix timestamp describing when the price was published
        //     uint publishTime;
        // }
        price.price =  3 * 1e18 ;
        price.expo = 18;
    }

    function getEmaPriceUnsafe(
        bytes32 id
    ) external view override returns (PythStructs.Price memory price) {}

    function getEmaPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view override returns (PythStructs.Price memory price) {}

    function updatePriceFeeds(
        bytes[] calldata updateData
    ) external payable override {}

    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable override {}

    function getUpdateFee(
        bytes[] calldata updateData
    ) external view override returns (uint feeAmount) {}

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    )
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory priceFeeds)
    {}

    function parsePriceFeedUpdatesUnique(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    )
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory priceFeeds)
    {}
}