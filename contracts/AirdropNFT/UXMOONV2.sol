// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import {UXNFTBASE} from "./UXNFTBASE.sol";

// @dev https://uxlink.io
contract UXMOONV2 is UXNFTBASE {
    constructor() UXNFTBASE("MOON", "MOON") {
        isUsingWhitelist = false;
        addToWhitelist(BLACK_HOLE);
    }
}

