// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import {UXNFTBASE} from "./UXNFTBASE.sol";

// @dev https://uxlink.io
contract UXMOONV1 is UXNFTBASE {
    constructor() UXNFTBASE("MOON", "MOON") {
        isUsingWhitelist = true;
        addToWhitelist(BLACK_HOLE);
    }
}

