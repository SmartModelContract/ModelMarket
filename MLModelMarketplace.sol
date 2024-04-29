// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Import the ModelCoin contract

contract MLModelMarketplace {
    // Use SafeERC20 to prevent reentrancy attacks
    using SafeERC20 for ModelCoin;

    ModelCoin public modelCoin;
    // ----------------- Model Request -----------------
    struct ModelRequest {
        address requester;
        uint256 reward;
        uint256 collateral;
        string context;
        string trainingDataHash;
        string testingDataHash;
        bool isFulfilled;
    }
    // ----------------- Model Submission -----------------
    struct ModelSubmission {
        string[] modelHashes;
        address contributor;
        bool isSubmitted;
    }
    // ----------------- Establish Variables -----------------
    mapping(uint256 => ModelRequest) public requests; // Keep track of requests (w/ id, reward, collateral, hashes, etc.)
    mapping(uint256 => ModelSubmission) public submissions; // keep track of submissions (hashes)
    mapping(address => bool) public hasRequested; // Make sure requestor can only request once

    uint256 public requestCount;

    event RequestCreated(uint256 requestId, address requester, uint256 reward, uint256 collateral, string trainingDataHash, string testingDataHash); // request event
    event ModelSubmitted(uint256 requestId, string[] modelHashes, address contributor); // submission event
    event RequestFulfilled(uint256 requestId, string[] modelHashes, address contributor); // fulfillment event

    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }

    function createRequest(uint256 reward, uint256 collateral, string calldata context, string calldata trainingDataHash, string calldata testingDataHash) external {
        require(modelCoin.transferFrom(msg.sender, address(this), reward + collateral), "Transfer failed"); // transfer reward and collateral from requestor to contract
        uint256 requestId = ++requestCount;
        requests[requestId] = ModelRequest({
            requester: msg.sender,
            reward: reward,
            collateral: collateral,
            context: context,
            trainingDataHash: trainingDataHash,
            testingDataHash: testingDataHash,
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
