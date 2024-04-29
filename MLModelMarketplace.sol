// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Ensure this path matches your project structure

contract MLModelMarketplace {
    using SafeERC20 for ModelCoin;

    ModelCoin public modelCoin;

    struct ModelRequest {
        address requester;
        uint256 reward;
        uint256 collateral;
        string context;
        string trainingDataHash;
        string testingDataHash;
        string modelMetadata;  // Optional metadata about the model
        bool isFulfilled;
    }

    struct ModelSubmission {
        string[] modelHashes;  // Array to hold multiple model parts or models
        address contributor;
        bool isSubmitted;
    }

    mapping(uint256 => ModelRequest) public requests;
    mapping(uint256 => ModelSubmission) public submissions;
    mapping(address => bool) public hasRequested;  // Track if a requestor has already made a request

    uint256 public requestCount;

    event RequestCreated(uint256 requestId, address requester, uint256 reward, uint256 collateral, string trainingDataHash, string testingDataHash);
    event ModelSubmitted(uint256 requestId, string[] modelHashes, address contributor);
    event RequestFulfilled(uint256 requestId, string[] modelHashes, address contributor);

    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }

    function createRequest(uint256 reward, uint256 collateral, string calldata context, string calldata trainingDataHash, string calldata testingDataHash, string calldata metadata) external {
        modelCoin.mint(address(this), reward + collateral);
        uint256 requestId = ++requestCount;
        requests[requestId] = ModelRequest({
            requester: msg.sender,
            reward: reward,
            collateral: collateral,
            context: context,
            trainingDataHash: trainingDataHash,
            testingDataHash: testingDataHash,
            modelMetadata: metadata,
            isFulfilled: false
        });
        hasRequested[msg.sender] = true;
        emit RequestCreated(requestId, msg.sender, reward, collateral, trainingDataHash, testingDataHash);
    }

    function submitModel(uint256 requestId, string[] calldata modelHashes) external {
        require(!requests[requestId].isFulfilled, "Request already fulfilled");
        require(!submissions[requestId].isSubmitted, "Model already submitted for this request");
        submissions[requestId] = ModelSubmission({
            modelHashes: modelHashes,
            contributor: msg.sender,
            isSubmitted: true
        });
        emit ModelSubmitted(requestId, modelHashes, msg.sender);
    }

    function fulfillRequest(uint256 requestId) external {
        require(msg.sender == requests[requestId].requester, "Only requester can fulfill");
        require(submissions[requestId].isSubmitted, "No model submitted yet");
        requests[requestId].isFulfilled = true;
        modelCoin.transfer(submissions[requestId].contributor, requests[requestId].reward);
        modelCoin.transfer(requests[requestId].requester, requests[requestId].collateral);
        emit RequestFulfilled(requestId, submissions[requestId].modelHashes, submissions[requestId].contributor);
    }

    function getRequest(uint256 requestId) external view returns (ModelRequest memory) {
        return requests[requestId];
    }

    function getSubmission(uint256 requestId) external view returns (ModelSubmission memory) {
        return submissions[requestId];
    }
}
