// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MLModelMarketplace {
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
        string modelHash;
        address contributor;
    }

    mapping(uint256 => ModelRequest) public requests;
    mapping(uint256 => ModelSubmission[]) public submissions;

    uint256 public requestCount;

    event RequestCreated(uint256 requestId, address requester, uint256 reward, uint256 collateral, string trainingDataHash, string testingDataHash);
    event ModelSubmitted(uint256 requestId, string modelHash, address contributor);
    event RequestFulfilled(uint256 requestId, string modelHash, address contributor);

    // Function to create a new model request
    function createRequest(uint256 reward, uint256 collateral, string calldata context, string calldata trainingDataHash, string calldata testingDataHash, string calldata metadata) external {
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
        emit RequestCreated(requestId, msg.sender, reward, collateral, trainingDataHash, testingDataHash);
    }

    // Function for contributors to submit models
    function submitModel(uint256 requestId, string calldata modelHash) external {
        require(!requests[requestId].isFulfilled, "Request already fulfilled");
        submissions[requestId].push(ModelSubmission({
            modelHash: modelHash,
            contributor: msg.sender
        }));
        emit ModelSubmitted(requestId, modelHash, msg.sender);
    }

    // Function to mark a request as fulfilled
    function fulfillRequest(uint256 requestId, string calldata modelHash) external {
        require(msg.sender == requests[requestId].requester, "Only requester can fulfill");
        requests[requestId].isFulfilled = true;
        emit RequestFulfilled(requestId, modelHash, msg.sender);
    }

    // Function to fetch request details
    function getRequest(uint256 requestId) external view returns (ModelRequest memory) {
        return requests[requestId];
    }

    // Function to fetch all submissions for a request
    function getSubmissions(uint256 requestId) external view returns (ModelSubmission[] memory) {
        return submissions[requestId];
    }
}
