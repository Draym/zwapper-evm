pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
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
    function submitToZwap(uint256 zwapId, Token[] calldata tokens) external override onlyParticipant(zwapId) isState(zwapId, ZwapState.CREATED) {
        require(zwaps[zwapId].userB != address(0), "Missing participant in given Zwap.");

        if (msg.sender == zwaps[zwapId].userA) {
            _verifyTokenOwnership(tokens);
            for (uint256 i = 0; i < tokens.length; i++) {
                zwaps[zwapId].userA_tokens[i] = tokens[i];
            }
            zwaps[zwapId].userA_tokens_total = tokens.length;
        } else {
            _verifyTokenOwnership(tokens);
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
            _transferToSelf(zwaps[zwapId].userA_tokens, zwaps[zwapId].userA_tokens_total);
        } else {
            _transferToSelf(zwaps[zwapId].userB_tokens, zwaps[zwapId].userB_tokens_total);
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
            _transferToUser(zwaps[zwapId].userB_tokens, zwaps[zwapId].userB_tokens_total, zwaps[zwapId].userA);
        } else {
            _transferToUser(zwaps[zwapId].userA_tokens, zwaps[zwapId].userA_tokens_total, zwaps[zwapId].userB);
        }
        emit ZwapWithdrawn({zwapId : zwapId, from : msg.sender});
    }

    /**
     * @dev See {IZwapper-abortExchange}.
     */
    function abortExchange(uint256 zwapId) external override onlyParticipant(zwapId) isState(zwapId, ZwapState.LOCKED) {
        zwaps[zwapId].state = ZwapState.CLOSED;
        _transferToUser(zwaps[zwapId].userA_tokens, zwaps[zwapId].userA_tokens_total, zwaps[zwapId].userA);
        _transferToUser(zwaps[zwapId].userB_tokens, zwaps[zwapId].userB_tokens_total, zwaps[zwapId].userB);
        emit ZwapAborted({zwapId : zwapId, from : msg.sender});
    }

    /**
     * @dev Verify ownership of tokens of the caller.
     */
    function _verifyTokenOwnership(Token[] memory tokens) internal view {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].tokenType == TokenType.ERC20) {
                require(
                    IERC20(tokens[i].origin).balanceOf(msg.sender) >= tokens[i].amount,
                    "You do not hold enough of the submitted ERC20 token."
                );
            } else if (tokens[i].tokenType == TokenType.ERC712) {
                require(
                    IERC721(tokens[i].origin).ownerOf(tokens[i].tokenId) == msg.sender,
                    "You are not the owner of the submitted ERC721 token."
                );
            } else if (tokens[i].tokenType == TokenType.ERC1155) {
                require(
                    IERC1155(tokens[i].origin).balanceOf(msg.sender, tokens[i].tokenId) >= tokens[i].amount,
                    "You do not hold enough of the submitted ERC1155 token."
                );
            } else {
                revert("Unknown provided Token.");
            }
        }
    }

    /**
     * @dev Transfer tokens from this contract to a receiver.
     */
    function _transferToUser(mapping(uint256 => Token) memory tokens, uint256 total, address to) internal {
        for (uint256 i = 0; i < total; i++) {
            if (tokens[i].tokenType == TokenType.ERC20) {
                IERC20(tokens[i].origin).transferFrom(address(this), to, tokens[i].amount);
            } else if (tokens[i].tokenType == TokenType.ERC712) {
                IERC721(tokens[i].origin).safeTransferFrom(address(this), to, tokens[i].tokenId);
            } else if (tokens[i].tokenType == TokenType.ERC1155) {
                IERC1155(tokens[i].origin).safeTransferFrom(address(this), to, tokens[i].tokenId, tokens[i].amount, "0x");
            } else {
                revert("Unknown provided Token.");
            }
        }
    }

    /**
     * @dev Transfer tokens from the caller to this contract.
     */
    function _transferToSelf(mapping(uint256 => Token) memory tokens, uint256 total) internal {
        for (uint256 i = 0; i < total; i++) {
            if (tokens[i].tokenType == TokenType.ERC20) {
                IERC20(tokens[i].origin).approve(address(this), tokens[i].amount);
                IERC20(tokens[i].origin).transferFrom(msg.sender, address(this), tokens[i].amount);
            } else if (tokens[i].tokenType == TokenType.ERC712) {
                IERC721(tokens[i].origin).approve(address(this), tokens[i].tokenId);
                IERC721(tokens[i].origin).safeTransferFrom(msg.sender, address(this), tokens[i].tokenId);
            } else if (tokens[i].tokenType == TokenType.ERC1155) {
                IERC1155(tokens[i].origin).setApprovalForAll(address(this), true);
                IERC1155(tokens[i].origin).safeTransferFrom(msg.sender, address(this), tokens[i].tokenId, tokens[i].amount, "0x");
            } else {
                revert("Unknown provided Token.");
            }
        }
    }

    function transferFromSender(Transfer[] calldata batch) external override {
        for (uint256 i = 0; i < batch.length; i++) {
            if (batch[i].token.tokenType == TokenType.ERC20) {
                IERC20(batch[i].token.origin).approve(address(this), batch[i].token.amount);
                IERC20(batch[i].token.origin).transferFrom(msg.sender, batch[i].to, batch[i].token.amount);
            } else if (batch[i].token.tokenType == TokenType.ERC712) {
                IERC721(batch[i].token.origin).approve(address(this), batch[i].token.tokenId);
                IERC721(batch[i].token.origin).safeTransferFrom(msg.sender, batch[i].to, batch[i].token.tokenId);
            } else if (batch[i].token.tokenType == TokenType.ERC1155) {
                IERC1155(batch[i].token.origin).setApprovalForAll(address(this), true);
                IERC1155(batch[i].token.origin).safeTransferFrom(msg.sender, batch[i].to, batch[i].token.tokenId, batch[i].token.amount, "0x");
            } else {
                revert("Unknown provided Token.");
            }
        }
    }

    /**
     * @dev See {IZwapper-getZwap}.
     */
    function getZwap(uint256 zwapId) external override view returns (ZwapDTO memory){
        Token[] memory userA_tokens = new Token[](zwaps[zwapId].userA_tokens_total);
        Token[] memory userB_tokens = new Token[](zwaps[zwapId].userB_tokens_total);

        for (uint256 i = 0; i < zwaps[zwapId].userA_tokens_total; i++) {
            userA_tokens[i] = zwaps[zwapId].userA_tokens[i];
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
        userA_tokens : userA_tokens,
        userB_tokens : userB_tokens
        });
    }
}
