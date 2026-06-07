// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "solady/tokens/ERC20.sol";

/// @notice Test ERC20 with public mint and configurable metadata (decimals included,
///         so fee/precision edge cases can use non-18 tokens in later suites).
contract MockERC20 is ERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
