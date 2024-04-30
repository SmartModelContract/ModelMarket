// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Import the ModelCoin contract

// contract deployed at: 0x36E3F7c04038D3AE09Ca7d63326F1827172b65AC

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
        // testing labels sha string
        bool isFulfilled;
    }
    // ----------------- Model Submission -----------------
    struct ModelSubmission {
        string modelHash;
        address contributor;
        bool isSubmitted;
        // upload hash(guesses) which is a string of hash
        // need identifier
    }
    // ----------------- Establish Variables -----------------
    mapping(uint256 => ModelRequest) public requests; // Keep track of requests (w/ id, reward, collateral, hashes, etc.)
    mapping(uint256 => ModelSubmission) public submissions; // keep track of submissions (hashes)


    uint256 public requestCount;

    event RequestCreated(uint256 requestId, address requester, uint256 reward, uint256 collateral, string trainingDataHash, string testingDataHash); // request event
    event ModelSubmitted(uint256 requestId, string modelHash, address contributor); // submission event
    event RequestFulfilled(uint256 requestId, string modelHash, address contributor); // fulfillment event

    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }

    function createRequest(uint256 reward, uint256 collateral, string calldata context, string calldata trainingDataHash, string calldata testingDataHash) external {
        require(modelCoin.transferFrom(msg.sender, address(this), reward + collateral), "Transfer failed"); // transfer reward and collateral from requestor to contract
        uint256 requestId = ++requestCount; // get rid of this and make this an parameter
        requests[requestId] = ModelRequest({
            requester: msg.sender,
            reward: reward,
            collateral: collateral,
            context: context,
            trainingDataHash: trainingDataHash,
            testingDataHash: testingDataHash,
            isFulfilled: false
        });
        emit RequestCreated(requestId, msg.sender, reward, collateral, trainingDataHash, testingDataHash);
    }

    function submitModel(uint256 requestId, string calldata modelHash) external {
        require(!requests[requestId].isFulfilled, "Request already fulfilled");
        require(!submissions[requestId].isSubmitted, "Model already submitted for this request");
        submissions[requestId] = ModelSubmission({
            modelHash: modelHash,
            contributor: msg.sender,
            isSubmitted: true
        });
        emit ModelSubmitted(requestId, modelHash, msg.sender);
    }

    function fulfillRequest(uint256 requestId) external { // delete after fufillment to avoid too much storage
        require(msg.sender == requests[requestId].requester, "Only requester can fulfill");
        require(submissions[requestId].isSubmitted, "No model submitted yet");
        requests[requestId].isFulfilled = true;
        modelCoin.transfer(submissions[requestId].contributor, requests[requestId].reward);
        modelCoin.transfer(requests[requestId].requester, requests[requestId].collateral);
        emit RequestFulfilled(requestId, submissions[requestId].modelHash, submissions[requestId].contributor);
    }

    function getRequest(uint256 requestId) external view returns (ModelRequest memory) {
        return requests[requestId];
    }

    function getSubmission(uint256 requestId) external view returns (ModelSubmission memory) {
        return submissions[requestId];
    }
}
