// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SprayMachine
 * @notice Decentralized money-spraying contract for SprayChain.
 *         Sprayers open a session, drip funds in via addSpray(),
 *         then close the session to push the full total to the honoree.
 * @dev Deployed on Celo Mainnet and Botchain (chain ID 677).
 *      Native gas token (CELO / Botchain native) is used in v1.
 *      No owner, no admin keys, no upgrade proxy — fully immutable.
 */
contract SprayMachine {

    // ─────────────────────────────────────────────
    //  Data Structures
    // ─────────────────────────────────────────────

    enum Status { Active, Closed }

    struct Session {
        address sprayer;      // wallet that opened the session
        address honoree;      // wallet that receives funds on close
        string  honoreeTag;   // human name typed by the sprayer
        uint256 total;        // cumulative wei deposited so far
        Status  status;
        uint256 openedAt;
        uint256 closedAt;
    }

    // ─────────────────────────────────────────────
    //  Storage
    // ─────────────────────────────────────────────

    /// @dev sessionId → Session
    mapping(bytes32 => Session) private _sessions;

    /// @dev sprayer → list of their sessionIds (for history)
    mapping(address => bytes32[]) private _sprayerHistory;

    /// @dev honoree → list of sessionIds they received (for notifications)
    mapping(address => bytes32[]) private _honoreeHistory;

    /// @dev running nonce for session ID generation
    uint256 private _nonce;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────

    /**
     * @notice Emitted when a new spray session is opened.
     */
    event SprayOpened(
        bytes32 indexed sessionId,
        address indexed sprayer,
        address indexed honoree,
        string  honoreeTag,
        uint256 initialAmount
    );

    /**
     * @notice Emitted on every addSpray() tick.
     */
    event SprayTick(
        bytes32 indexed sessionId,
        uint256 tickAmount,
        uint256 cumulative
    );

    /**
     * @notice Emitted when a session is closed and funds pushed to honoree.
     */
    event SprayClosed(
        bytes32 indexed sessionId,
        address indexed sprayer,
        address indexed honoree,
        uint256 totalAmount,
        string  honoreeTag
    );

    // ─────────────────────────────────────────────
    //  Errors
    // ─────────────────────────────────────────────

    error SessionNotFound(bytes32 sessionId);
    error SessionAlreadyClosed(bytes32 sessionId);
    error NotSessionSprayer(bytes32 sessionId, address caller);
    error ZeroValueNotAllowed();
    error HonoreeMustBeDifferent();
    error TransferFailed(address to, uint256 amount);

    // ─────────────────────────────────────────────
    //  Core Functions
    // ─────────────────────────────────────────────

    /**
     * @notice Open a new spray session.
     * @param honoree   Address of the person being sprayed.
     * @param honoreeTag  Human-readable name (e.g. "Queen Bimpe 🎉").
     * @return sessionId  Unique bytes32 ID for this session.
     */
    function openSpray(
        address honoree,
        string calldata honoreeTag
    ) external payable returns (bytes32 sessionId) {
        if (msg.value == 0) revert ZeroValueNotAllowed();
        if (honoree == msg.sender) revert HonoreeMustBeDifferent();
        if (honoree == address(0)) revert HonoreeMustBeDifferent();

        unchecked { _nonce++; }

        sessionId = keccak256(
            abi.encodePacked(msg.sender, honoree, _nonce, block.timestamp)
        );

        _sessions[sessionId] = Session({
            sprayer:    msg.sender,
            honoree:    honoree,
            honoreeTag: honoreeTag,
            total:      msg.value,
            status:     Status.Active,
            openedAt:   block.timestamp,
            closedAt:   0
        });

        _sprayerHistory[msg.sender].push(sessionId);
        _honoreeHistory[honoree].push(sessionId);

        emit SprayOpened(sessionId, msg.sender, honoree, honoreeTag, msg.value);
    }

    /**
     * @notice Add more funds to an active spray session (UI tick call).
     * @param sessionId  The session to top up.
     */
    function addSpray(bytes32 sessionId) external payable {
        Session storage s = _getActiveSession(sessionId);
        if (s.sprayer != msg.sender) revert NotSessionSprayer(sessionId, msg.sender);
        if (msg.value == 0) revert ZeroValueNotAllowed();

        s.total += msg.value;

        emit SprayTick(sessionId, msg.value, s.total);
    }

    /**
     * @notice Close the session and push all accumulated funds to the honoree.
     * @param sessionId  The session to close.
     */
    function closeSpray(bytes32 sessionId) external {
        Session storage s = _getActiveSession(sessionId);
        if (s.sprayer != msg.sender) revert NotSessionSprayer(sessionId, msg.sender);

        // ── Checks-Effects-Interactions ──
        uint256 payout = s.total;
        address honoree = s.honoree;
        string memory tag = s.honoreeTag;

        s.status   = Status.Closed;
        s.closedAt = block.timestamp;

        emit SprayClosed(sessionId, msg.sender, honoree, payout, tag);

        // Push transfer — honoree receives 100% of sprayed amount
        (bool ok, ) = honoree.call{value: payout}("");
        if (!ok) revert TransferFailed(honoree, payout);
    }

    // ─────────────────────────────────────────────
    //  View / Query Functions
    // ─────────────────────────────────────────────

    /**
     * @notice Read full session details.
     */
    function getSession(bytes32 sessionId)
        external
        view
        returns (Session memory)
    {
        Session memory s = _sessions[sessionId];
        if (s.sprayer == address(0)) revert SessionNotFound(sessionId);
        return s;
    }

    /**
     * @notice List all session IDs opened by a sprayer.
     */
    function getSprayerHistory(address sprayer)
        external
        view
        returns (bytes32[] memory)
    {
        return _sprayerHistory[sprayer];
    }

    /**
     * @notice List all session IDs received by an honoree.
     */
    function getHonoreeHistory(address honoree)
        external
        view
        returns (bytes32[] memory)
    {
        return _honoreeHistory[honoree];
    }

    // ─────────────────────────────────────────────
    //  Internal Helpers
    // ─────────────────────────────────────────────

    function _getActiveSession(bytes32 sessionId)
        internal
        view
        returns (Session storage s)
    {
        s = _sessions[sessionId];
        if (s.sprayer == address(0)) revert SessionNotFound(sessionId);
        if (s.status == Status.Closed) revert SessionAlreadyClosed(sessionId);
    }

    // ─────────────────────────────────────────────
    //  Receive guard — reject plain ETH sends
    // ─────────────────────────────────────────────

    receive() external payable {
        revert("Use openSpray() or addSpray()");
    }
}
