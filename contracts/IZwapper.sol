pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @dev Required interface of an Zwapper compliant contract.
 */
// SPDX-License-Identifier: GLWTPL
interface IZwapper {
    /**
     * @dev Emitted when `from` join a `zwap`.
     */
    event ZwapJoined(uint256 indexed zwapId, address indexed from);

    /**
     * @dev Emitted when `from` submit goods to his current `zwap`.
     */
    event ZwapSubmitted(uint256 indexed zwapId, address indexed from);

    /**
     * @dev Emitted when `from` have locked his current `zwap` and his goods' ownership are successfully transferred.
     */
    event ZwapLocked(uint256 indexed zwapId, address indexed from);

    /**
     * @dev Emitted when the `zwap` is withdrawn and the transfer of goods is successful for `from`.
     */
    event ZwapWithdrawn(uint256 indexed zwapId, address indexed from);

    /**
     * @dev Emitted when `from` abort his current `zwap`, both users will get back ownership of locked goods.
     */
    event ZwapAborted(uint256 indexed zwapId, address indexed from);


    enum ZwapState {
        NONE,
        CREATED,
        SUBMITTED,
        LOCKED,
        WITHDRAWING,
        COMPLETED,
        CLOSED
    }

    struct ERC20Token {
        address origin;
        uint256 amount;
    }

    struct ERC721Token {
        address origin;
        uint256 token;
    }

    struct Zwap {
        ZwapState state;
        address userA;
        address userB;
        bool userA_locked;
        bool userB_locked;
        bool userA_withdraw;
        bool userB_withdraw;
        mapping(uint256 => ERC20Token) userA_coins;
        uint256 userA_coins_total;
        mapping(uint256 => ERC721Token) userA_tokens;
        uint256 userA_tokens_total;
        mapping(uint256 => ERC20Token) userB_coins;
        uint256 userB_coins_total;
        mapping(uint256 => ERC721Token) userB_tokens;
        uint256 userB_tokens_total;
    }

    struct ZwapDTO {
        ZwapState state;
        address userA;
        address userB;
        bool userA_locked;
        bool userB_locked;
        bool userA_withdraw;
        bool userB_withdraw;
        ERC20Token[] userA_coins;
        ERC721Token[] userA_tokens;
        ERC20Token[] userB_coins;
        ERC721Token[] userB_tokens;
    }

    /**
     * @dev Create a Zwap for the `caller`, another user have to join the Zwap before any new functionality become available.
     * Set the `zwap` as 'CREATED'.
     *
     * Returns the `zwap` identifier.
     */
    function createZwap() external returns (uint256 zwap);

    /**
     * @dev Join the given `zwap`.
     *
     * Requirements:
     * - `zwap` must exist.
     * - `zwap` is not full and you are not part of it already.
     *
     * Emits a {ZwapJoined} event.
     */
    function joinZwap(uint256 zwapId) external;

    /**
     * @dev Submit given goods to be transferred.
     * Set the `zwap` as 'SUBMITTED' when at least one user has called this methods.
     *
     * Requirements:
     * - `zwap` must be in `CREATED` state.
     * - `caller` must be part of the `zwap`.
     * - `caller` must be the owner of the given coins & tokens.
     *
     * Emits a {ZwapSubmitted} event.
     */
    function submitToZwap(uint256 zwapId, ERC20Token[] calldata coins, ERC721Token[] calldata tokens) external;

    /**
     * @dev  Lock the Zwap and transfer the ownership of the goods to the Zwapper contract.
     * Set the `zwap` as 'LOCKED' when both users have called this methods.
     *
     * Requirements:
     * - `caller` must be part of the `zwap`.
     * - `zwap` must be in `SUBMITTED` state.
     * - `caller` must not have locked his `zwap` already.
     * - `caller` must have approved the transfer of the given coins & tokens to Zwapper.
     * - `caller` must be the owner of the given coins & tokens.
     *
     * Emits a {ZwapLocked} event.
     */
    function lockExchange(uint256 zwapId) external;

    /**
     * @dev Transfer the ownership of the goods to the new owner.
     * Set the `zwap` as 'WITHDRAWING' when a user has withdraw their goods.
     * Set the `zwap` as 'COMPLETED' when both users have withdraw their goods.
     *
     * Requirements:
     * - `caller` must be part of the `zwap`.
     * - `zwap` must be in 'VALIDATED' state.
     *
     * Emits a {ZwapCompleted} event.
     */
    function withdrawZwap(uint256 zwapId) external;

    /**
     * @dev Abort the `zwap`. Goods are transferred back to their original owners if the `zwap` state is 'LOCKED' or 'VALIDATED'
     * Set the `zwap` as 'CLOSED'.
     *
     * Requirements:
     * - `caller` must be part of the `zwap`.
     * - `zwap` must not be in 'COMPLETED' state.
     *
     * Emits a {ZwapAborted} event.
     */
    function abortExchange(uint256 zwapId) external;

    /**
     * @dev Returns the detail of the `zwap`.
     *
     * Requirements:
     * - `caller` must be part of the `zwap`.
     */
    function getZwap(uint256 zwapId) external view returns (ZwapDTO memory);
}
