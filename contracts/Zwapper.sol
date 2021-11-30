pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IZwapper.sol";

// SPDX-License-Identifier: GLWTPL
contract Zwapper is IZwapper {

    using Counters for Counters.Counter;
    Counters.Counter private _zwapIds;

    mapping(address => uint256) private user_to_zwap;
    mapping(uint256 => Zwap) private zwaps;

    modifier onlyParticipant(uint256 zwapId) {
        require(user_to_zwap[msg.sender] == zwapId, "You are not a participant of given Zwap.");
        _;
    }

    modifier isState(uint256 zwapId, ZwapState state) {
        require(zwaps[zwapId].state == state, "Not allowed to submit in the current state of given Zwap.");
        _;
    }

    modifier hasState(uint256 zwapId, ZwapState state1, ZwapState state2) {
        require(zwaps[zwapId].state == state1 || zwaps[zwapId].state == state2, "Not allowed to submit in the current state of given Zwap.");
        _;
    }

    /**
     * @dev See {IZwapper-createZwap}.
     */
    function createZwap() external override returns (uint256 zwap) {
        require(user_to_zwap[msg.sender] == 0, "You are already a participant of a Zwap.");

        _zwapIds.increment();
        uint256 _newZwapId = _zwapIds.current();

        zwaps[_newZwapId].userA = msg.sender;
        zwaps[_newZwapId].state = ZwapState.CREATED;
        user_to_zwap[msg.sender] = _newZwapId;
        return _newZwapId;
    }

    /**
     * @dev See {IZwapper-joinZwap}.
     */
    function joinZwap(uint256 zwapId) external override {
        require(user_to_zwap[msg.sender] == 0, "You are already a participant of a Zwap.");
        zwaps[zwapId].userB = msg.sender;
        user_to_zwap[msg.sender] = zwapId;
        emit ZwapJoined({zwapId : zwapId, from : msg.sender});
    }

    /**
     * @dev See {IZwapper-validateExchange}.
     */
    function submitToZwap(uint256 zwapId, ERC20Token[] calldata coins, ERC721Token[] calldata tokens) external override onlyParticipant(zwapId) isState(zwapId, ZwapState.CREATED) {
        require(zwaps[zwapId].userB != address(0), "Missing participant in given Zwap.");

        if (msg.sender == zwaps[zwapId].userA) {
            for (uint256 i = 0; i < zwaps[zwapId].userA_coins_total; i++) {
                require(
                    IERC20(zwaps[zwapId].userA_coins[i].origin).balanceOf(msg.sender) >= zwaps[zwapId].userA_coins[i].amount,
                    "you do not hold enough of the submitted coins."
                );
            }
            for (uint256 i = 0; i < zwaps[zwapId].userA_tokens_total; i++) {
                require(
                    IERC721(zwaps[zwapId].userA_tokens[i].origin).ownerOf(zwaps[zwapId].userA_tokens[i].token) == msg.sender,
                    "you are not the owner the submitted token."
                );
            }
            for (uint256 i = 0; i < coins.length; i++) {
                zwaps[zwapId].userA_coins[i] = coins[i];
            }
            zwaps[zwapId].userA_coins_total = coins.length;
            for (uint256 i = 0; i < tokens.length; i++) {
                zwaps[zwapId].userA_tokens[i] = tokens[i];
            }
            zwaps[zwapId].userA_tokens_total = tokens.length;
        } else {
            for (uint256 i = 0; i < zwaps[zwapId].userB_coins_total; i++) {
                require(
                    IERC20(zwaps[zwapId].userB_coins[i].origin).balanceOf(msg.sender) >= zwaps[zwapId].userB_coins[i].amount,
                    "you do not hold enough of the submitted coins."
                );
            }
            for (uint256 i = 0; i < zwaps[zwapId].userB_tokens_total; i++) {
                require(
                    IERC721(zwaps[zwapId].userB_tokens[i].origin).ownerOf(zwaps[zwapId].userB_tokens[i].token) == msg.sender,
                    "you are not the owner the submitted token."
                );
            }
            for (uint256 i = 0; i < coins.length; i++) {
                zwaps[zwapId].userB_coins[i] = coins[i];
            }
            zwaps[zwapId].userB_coins_total = coins.length;
            for (uint256 i = 0; i < tokens.length; i++) {
                zwaps[zwapId].userB_tokens[i] = tokens[i];
            }
            zwaps[zwapId].userB_tokens_total = tokens.length;
        }
        zwaps[zwapId].state = ZwapState.SUBMITTED;
        emit ZwapSubmitted({zwapId : zwapId, from : msg.sender});
    }

    /**
     * @dev See {IZwapper-lockExchange}.
     */
    function lockExchange(uint256 zwapId) external override onlyParticipant(zwapId) isState(zwapId, ZwapState.SUBMITTED) {
        if (msg.sender == zwaps[zwapId].userA) {
            zwaps[zwapId].userA_locked = true;
        } else {
            zwaps[zwapId].userB_locked = true;
        }
        if (zwaps[zwapId].userA_locked && zwaps[zwapId].userB_locked) {
            zwaps[zwapId].state = ZwapState.LOCKED;
        }
        if (msg.sender == zwaps[zwapId].userA) {
            for (uint256 i = 0; i < zwaps[zwapId].userA_coins_total; i++) {
                IERC20(zwaps[zwapId].userA_coins[i].origin).transferFrom(msg.sender, address(this), zwaps[zwapId].userA_coins[i].amount);
            }
            for (uint256 i = 0; i < zwaps[zwapId].userA_tokens_total; i++) {
                IERC721(zwaps[zwapId].userA_tokens[i].origin).safeTransferFrom(msg.sender, address(this), zwaps[zwapId].userA_tokens[i].token);
            }
        } else {
            for (uint256 i = 0; i < zwaps[zwapId].userB_coins_total; i++) {
                IERC20(zwaps[zwapId].userB_coins[i].origin).transferFrom(msg.sender, address(this), zwaps[zwapId].userB_coins[i].amount);
            }
            for (uint256 i = 0; i < zwaps[zwapId].userB_tokens_total; i++) {
                IERC721(zwaps[zwapId].userB_tokens[i].origin).safeTransferFrom(msg.sender, address(this), zwaps[zwapId].userB_tokens[i].token);
            }
        }
        emit ZwapLocked({zwapId : zwapId, from : msg.sender});
    }

    /**
     * @dev See {IZwapper-completeExchange}.
     */
    function withdrawZwap(uint256 zwapId) external override onlyParticipant(zwapId) hasState(zwapId, ZwapState.LOCKED, ZwapState.WITHDRAWING) {
        zwaps[zwapId].state = ZwapState.WITHDRAWING;
        if (msg.sender == zwaps[zwapId].userA) {
            require(zwaps[zwapId].userA_withdraw == false, "You already completed a withdraw on this Zwap.");
            zwaps[zwapId].userA_withdraw = true;
        } else {
            require(zwaps[zwapId].userB_withdraw == false, "You already completed a withdraw on this Zwap.");
            zwaps[zwapId].userB_withdraw = true;
        }
        if (zwaps[zwapId].userA_withdraw && zwaps[zwapId].userB_withdraw) {
            zwaps[zwapId].state = ZwapState.COMPLETED;
        }
        if (msg.sender == zwaps[zwapId].userA) {
            for (uint256 i = 0; i < zwaps[zwapId].userB_coins_total; i++) {
                IERC20(zwaps[zwapId].userB_coins[i].origin).transferFrom(address(this), zwaps[zwapId].userA, zwaps[zwapId].userB_coins[i].amount);
            }
            for (uint256 i = 0; i < zwaps[zwapId].userB_tokens_total; i++) {
                IERC721(zwaps[zwapId].userB_tokens[i].origin).safeTransferFrom(address(this), zwaps[zwapId].userA, zwaps[zwapId].userB_tokens[i].token);
            }
        } else {
            for (uint256 i = 0; i < zwaps[zwapId].userA_coins_total; i++) {
                IERC20(zwaps[zwapId].userA_coins[i].origin).transferFrom(address(this), zwaps[zwapId].userB, zwaps[zwapId].userA_coins[i].amount);
            }
            for (uint256 i = 0; i < zwaps[zwapId].userA_tokens_total; i++) {
                IERC721(zwaps[zwapId].userA_tokens[i].origin).safeTransferFrom(address(this), zwaps[zwapId].userB, zwaps[zwapId].userA_tokens[i].token);
            }
        }
        emit ZwapWithdrawn({zwapId : zwapId, from : msg.sender});
    }

    /**
     * @dev See {IZwapper-abortExchange}.
     */
    function abortExchange(uint256 zwapId) external override onlyParticipant(zwapId) isState(zwapId, ZwapState.LOCKED) {
        zwaps[zwapId].state = ZwapState.CLOSED;
        if (msg.sender == zwaps[zwapId].userA) {
            for (uint256 i = 0; i < zwaps[zwapId].userA_coins_total; i++) {
                IERC20(zwaps[zwapId].userA_coins[i].origin).transferFrom(address(this), zwaps[zwapId].userA, zwaps[zwapId].userA_coins[i].amount);
            }
            for (uint256 i = 0; i < zwaps[zwapId].userA_tokens_total; i++) {
                IERC721(zwaps[zwapId].userA_tokens[i].origin).safeTransferFrom(address(this), zwaps[zwapId].userA, zwaps[zwapId].userA_tokens[i].token);
            }
        } else {
            for (uint256 i = 0; i < zwaps[zwapId].userB_coins_total; i++) {
                IERC20(zwaps[zwapId].userB_coins[i].origin).transferFrom(address(this), zwaps[zwapId].userB, zwaps[zwapId].userB_coins[i].amount);
            }
            for (uint256 i = 0; i < zwaps[zwapId].userB_tokens_total; i++) {
                IERC721(zwaps[zwapId].userB_tokens[i].origin).safeTransferFrom(address(this), zwaps[zwapId].userB, zwaps[zwapId].userB_tokens[i].token);
            }
        }
        emit ZwapAborted({zwapId : zwapId, from : msg.sender});
    }

    /**
     * @dev See {IZwapper-getZwap}.
     */
    function getZwap(uint256 zwapId) external override view returns (ZwapDTO memory){
        ERC20Token[] memory userA_coins = new ERC20Token[](zwaps[zwapId].userA_coins_total);
        ERC721Token[] memory userA_tokens = new ERC721Token[](zwaps[zwapId].userA_tokens_total);
        ERC20Token[] memory userB_coins = new ERC20Token[](zwaps[zwapId].userB_coins_total);
        ERC721Token[] memory userB_tokens = new ERC721Token[](zwaps[zwapId].userB_tokens_total);

        for (uint256 i = 0; i < zwaps[zwapId].userA_coins_total; i++) {
            userA_coins[i] = zwaps[zwapId].userA_coins[i];
        }
        for (uint256 i = 0; i < zwaps[zwapId].userA_tokens_total; i++) {
            userA_tokens[i] = zwaps[zwapId].userA_tokens[i];
        }
        for (uint256 i = 0; i < zwaps[zwapId].userB_coins_total; i++) {
            userB_coins[i] = zwaps[zwapId].userB_coins[i];
        }
        for (uint256 i = 0; i < zwaps[zwapId].userB_tokens_total; i++) {
            userB_tokens[i] = zwaps[zwapId].userB_tokens[i];
        }

        return ZwapDTO({
        state : zwaps[zwapId].state,
        userA : zwaps[zwapId].userA,
        userB : zwaps[zwapId].userB,
        userA_locked : zwaps[zwapId].userA_locked,
        userB_locked : zwaps[zwapId].userB_locked,
        userA_withdraw : zwaps[zwapId].userA_withdraw,
        userB_withdraw : zwaps[zwapId].userB_withdraw,
        userA_coins : userA_coins,
        userA_tokens : userA_tokens,
        userB_coins : userB_coins,
        userB_tokens : userB_tokens
        });
    }
}
