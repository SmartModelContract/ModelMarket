// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MLModelMarketplace {
    struct ModelRequest {
        address requester;
        uint256 reward;
        uint256 collateral;
        uint256 stake;
        uint256 timeLock;  // Timestamp until which certain actions are locked
        string context;
        string trainingDataLink;
        string unlabeledTestingDataLink;
        string superHashLabels; // Hash for labels related to the model
        string labels; // Plain labels uploaded by requestor after time lock
        bool isFulfilled;
    }

    struct ModelSubmission {
        string superHashModel;  // Hash of the submitted model
        address contributor;
        bool isSubmitted;
        uint accuracy;  // Accuracy submitted by the contributor after time lock
    }

    mapping(uint256 => ModelRequest) public requests;
    mapping(uint256 => ModelSubmission) public submissions;
    mapping(address => bool) public hasRequested;  // Track if a requestor has already made a request

    uint256 public requestCount;

    event RequestCreated(
        uint256 requestId,
        address requester,
        uint256 reward,
        uint256 collateral,
        uint256 stake,
        uint256 timeLock,
        string trainingDataLink,
        string unlabeledTestingDataLink,
        string superHashLabels
    );
    event ModelSubmitted(uint256 requestId, string superHashModel, address contributor);
    event LabelsUploaded(uint256 requestId, string labels);
    event AccuracySubmitted(uint256 requestId, uint accuracy, address contributor);
    event RequestFulfilled(uint256 requestId, string superHashModel, address contributor);

    // Function to create a new model request
    function createRequest(
        uint256 reward,
        uint256 collateral,
        uint256 stake,
        uint256 timeLock,
        string calldata context,
        string calldata trainingDataLink,
        string calldata unlabeledTestingDataLink,
        string calldata superHashLabels
    ) external {
        require(!hasRequested[msg.sender], "Requestor has already made a request");
        uint256 requestId = ++requestCount;
        requests[requestId] = ModelRequest({
            requester: msg.sender,
            reward: reward,
            collateral: collateral,
            stake: stake,
            timeLock: timeLock,
            context: context,
            trainingDataLink: trainingDataLink,
            unlabeledTestingDataLink: unlabeledTestingDataLink,
            superHashLabels: superHashLabels,
            labels: "",
            isFulfilled: false
        });
        hasRequested[msg.sender] = true;
        emit RequestCreated(
            requestId, msg.sender, reward, collateral, stake, timeLock,
            trainingDataLink, unlabeledTestingDataLink, superHashLabels
        );
    }

    // Function for requestor to upload labels after time lock
    function uploadLabels(uint256 requestId, string calldata labels) external {
        require(msg.sender == requests[requestId].requester, "Only requester can upload labels");
        require(block.timestamp >= requests[requestId].timeLock, "Action locked until time lock passes");
        requests[requestId].labels = labels;
        emit LabelsUploaded(requestId, labels);
    }

    // Function for contributors to submit accuracies after time lock
    function submitAccuracy(uint256 requestId, uint accuracy) external {
        require(submissions[requestId].contributor == msg.sender, "Only model contributor can submit accuracy");
        require(block.timestamp >= requests[requestId].timeLock, "Action locked until time lock passes");
        submissions[requestId].accuracy = accuracy;
        emit AccuracySubmitted(requestId, accuracy, msg.sender);
    }

    // Function to fetch request details
    function getRequest(uint256 requestId) external view returns (ModelRequest memory) {
        return requests[requestId];
    }

    // Function to fetch the submission for a request
    function getSubmission(uint256 requestId) external view returns (ModelSubmission memory) {
        return submissions[requestId];
    }
}
