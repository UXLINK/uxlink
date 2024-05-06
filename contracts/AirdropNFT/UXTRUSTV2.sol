// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import {UXNFTBASE} from "./UXNFTBASE.sol";

// @dev https://uxlink.io
contract UXTRUSTV2 is UXNFTBASE {
    constructor() UXNFTBASE("TRUST", "TRUST") {
        isUsingWhitelist = false;
        addToWhitelist(BLACK_HOLE);
    }
}