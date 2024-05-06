// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
pragma abicoder v2;

import {UXNFTBASE} from "./UXNFTBASE.sol";

// @dev https://uxlink.io
contract UXLINKV1 is UXNFTBASE {

    constructor() UXNFTBASE("LINK", "LINK") {
        isUsingWhitelist = true;
        addToWhitelist(BLACK_HOLE);
    }

}

