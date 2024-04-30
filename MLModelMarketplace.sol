// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Import the ModelCoin contract
import "@openzeppelin/contracts/utils/Strings.sol"; // String utils

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


    // ----------------- Model Request -----------------
    struct ModelRequest {               //TODO: populate update!
        address constant requester;
        uint256 constant reward;
        uint256 constant trainerStake;
        uint256 constant deadline;      // timestamp of submission closure
        string constant context;        // relevant instructions / info
        string constant trainingIPFS;
        string constant unlabeledTestingIPFS;
        string constant groundTruthSHA;
        uint256 constant testDataCount; // number of testing data


        // Tracking Status Codes:
        // ---------------------
        // 0 - Open (Accepting Submissions / Awaiting Ground Truth)
        // 1 - Grounded (Accepting Accuracy Claims / Awaiting Candidate Selection)
        // 2 - Pending Candidate Validation
        // 3 - Success (Transaction Complete)
        // 4 - Refunded (No Valid Submissions)
        // 5 - Canceled by Requester
        // 6 - Requester Punished for Taking Too Long
        // ---------------------

        uint256 status;             // current status code
        uint256 blameworthy;        // responsible for preventing timeout
        uint256 timeout;            // timestamp when contract will revert
        uint256 canceledCount;      // # of canceled submissions

        // Ground Truth
        bool hasGroundTruth;
        uint256[] groundTruth;

        // Candidate Selection
        string candidateModel;
    }


    // ----------------- Model Submission -----------------
    struct ModelSubmission {
        address trainer;
        string targetRequestID;

        // Submission Payload
        string modelSuperhash;
        string predictionSHA;

        // Uploaded Later
        uint256 claimedAccuracy;    // # of testing data correctly categorized
        string modelIPFS;           // Publicly visible!!!
    }


    // ----------------- Establish Variables -----------------
    mapping(string => ModelRequest) public requests; // All requests
    mapping(string => ModelSubmission) public submissions; // All models
    mapping(string => string[]) private submissionsForRequest; // Map requestID to list of modelIDs

    uint256 public requestCount; // TODO necessary?
    uint256 public responseWindow = 900;  // fifteen minutes (in seconds)

    event RequestCreated(string requestID, address requester, uint256 reward, uint256 trainerStake, uint256 deadline, string trainingIPFS, string unlabeledTestingIPFS, uint256 testDataCount);
    event ModelSubmitted(string requestID, string modelID, address trainer, string modelSuperhash, string predictionSHA);


    // -------------- External View Functions ---------------
    function getRequest(string requestID) external view returns (ModelRequest memory) {
        return requests[requestID];
    }

    function getSubmission(string calldata modelID) external view returns (ModelSubmission memory) {
        return submissions[modelID];
    }


    // ------------- Internal Utility Functions ---------------

    function resetTimeout(string requestID) internal {
        requests[requestID].timeout = block.timestamp + responseWindow;
    }

    // Called if request is canceled and there are submissions.
    function slashRequester(string requestID) internal {
        ModelRequest memory request = requests[requestID];
        string[] memory modelIDs = submissionsForRequest[requestID];

        // Calculate reward share
        uint256 numTrainers = modelIDs.length - request.canceledCount;
        uint256 slice = request.reward / numTrainers;

        // Distrubute slashed reward to valid trainers
        for (uint256 i = 0; i < modelIDs.length; i++) {
            address trainer = submissions[modelIDs[i]].trainer;
            if (trainer != address(0)) {
                modelCoin.transfer(trainer, slice);
            }
        }
    }

    // =========== Core Protocol ============ TODO: update!!!

    function createRequest(uint256 reward, uint256 trainerStake, uint256 deadline, string calldata context, string calldata trainingIPFS, string calldata unlabeledTestingIPFS, string calldata groundTruthSHA, uint256 testDataCount) external {
        require(modelCoin.transferFrom(msg.sender, address(this), reward), "Transfer failed"); // absorb reward

        string requestID = ++requestCount; //TODO unnecessary?
        requests[requestID] = ModelRequest({
            // Parameters
            requester: msg.sender,
            reward: reward,
            trainerStake: trainerStake,
            deadline: deadline,
            context: context,
            trainingIPFS: trainingIPFS,
            unlabeledTestingIPFS: unlabeledTestingIPFS,
            groundTruthSHA: groundTruthSHA,
            testDataCount: testDataCount,

            // Tracking
            status: 0,
            blameworthy: msg.sender,
            timeout: deadline + responseWindow,
            canceledCount: 0,
            hasGroundTruth: false,
            groundTruth: new uint[](testDataCount),
            candidateModel: ""
        });

        emit RequestCreated(requestID, msg.sender, reward, trainerStake, deadline, context, trainingIPFS, unlabeledTestingIPFS, groundTruthSHA, testDataCount);
    }

    function cancelRequest(string calldata requestID) external returns (string memory) {
        ModelRequest memory request = requests[requestID];
        address requester = request.requester;
        uint256 status = request.status;

        require(msg.sender == requester);   // Only callable by requester
        require(status == 0);   // and only before ground truth upload

        if((submissions[requestID].length - request.canceledCount) == 0) {
            // Full Refund!
            modelCoin.transfer(request.requester, request.reward);
        } else {
            // Trainers compensated for their efforts
            slashRequester(requestID);
        }
        // 5 - Canceled by Requester
        requests[requestID].status = 5;
    }

    function submitModel(string calldata targetRequestID, string calldata modelID, string calldata modelSuperhash, string calldata predictionSHA) external {
        ModelRequest memory request = requests[targetRequestID];

        require(request.requester != address(0), "Invalid target!");
        require(submissions[modelID].trainer == address(0), "Model already uploaded!");
        require(block.timestamp < request.deadline, "Submissions are closed.");
        require(request.status == 0, "This request has been canceled.");

        // Require staking of collateral
        require(modelCoin.transferFrom(msg.sender, address(this), request.trainerStake), "Collateral staking failed");

        submissions[modelID] = ModelSubmission({
            trainer: msg.sender,
            targetRequestID: targetRequestID,
            modelID: modelID,
            modelSuperhash: modelSuperhash,
            predictionSHA: predictionSHA,
            // For Later
            claimedAccuracy: request.testDataCount + 1, // Not uploaded yet
            modelIPFS: "",                              // Not uploaded yet
            prediction: uint[](request.testDataCount)  // Not uploaded yet
        });

        // keep submissions indexed by request!
        submissionsForRequest[targetRequestID].push(modelID);

        // requests[requestID].submissionCount++;
        emit ModelSubmitted(targetRequestID, modelID, msg.sender, modelSuperhash, predictionSHA);
    }

    function cancelSubmission(string calldata modelID) public {
        // Can be called internally or by model trainer
        ModelSubmission memory model = submissions[modelID];
        require(msg.sender == address(this) || msg.sender == model.trainer, "Invalid submission.");

        delete submissions[modelID];    // reset mapping to 0
        requests[model.targetRequestID].canceledCount++; // log cancelation

        // Refund trainer stake if before deadline
        if (block.timestamp < requests[model.targetRequestID].deadline) {
            modelCoin.transfer(model.trainer, trainerStake);
        }
    }

    function uploadGroundTruth(string calldata requestID, uint256[] calldata groundTruth) external {
        ModelRequest memory request = requests[requestID];

        require(msg.sender == request.requester, "Only the requester can upload ground truth testing labels!");
        require(!request.hasGroundTruth, "The ground truth has already been uploaded.");
        require(request.status == 0, "You let the contract time out! Sorry.");
        require(block.timestamp >= request.deadline, "It is too early to upload the ground truth! Wait until the submission deadline.");

        // require correct ground truth - TODO DEBUG WITH DAPP/FRONTEND!
        require(Strings.equal(groundTruthSHA, keccak256(groundTruth)), "Please upload the correctly formatted ground truth corresponding to the hash uploaded in your initial request!");

        requests[requestID].groundTruth = groundTruth;
        requests[requestID].hasGroundTruth = true;
        requests[requestID].status = 1; // begin accepting accuracy claims
        resetTimeout();
    }

    function submitAccuracy(string calldata modelID, uint256 accuracy) {
        ModelSubmission memory model = submissions[modelID];
        ModelRequest memory request = requests[model.targetRequestID];
        require(accuracy <= request.testDataCount, string.concat("Accuracy is number correct out of ", Strings.toString(testDataCount)));

        // Upload accuracy claim
        submissions[modelID].claimedAccuracy = accuracy;
    }

    function pickCandidate(string calldata requestID) public {
        ModelRequest memory request = requests[requestID];
        uint256 timeout = request.timeout;
        uint256 status = request.status;

        require(msg.sender == address(this) || ((status == 1 || status == 2) && block.timestamp >= timeout), "This function can only be called when it is time to select a candidate!");

        string[] memory modelIDs = submissions[requestID];
        uint256 modelCount = modelIDs.length;

        // Initialize placeholders
        uint256 bestAccuracy = 0;
        string bestCandidate = "";
        // Loop over submissions
        for (uint256 i = 0; i < modelCount; i++) {
            modelID = modelIDs[i];
            ModelSubmission memory model = submissions[modelID];

            // If submission is not canceled:
            if (model.trainer != address(0) && model.claimedAccuracy > bestAccuracy) {
                bestCandidate = modelID;
                bestAccuracy = model.claimedAccuracy;
            }
        }

        if (Strings.equal(bestCandidate, "")) {
            // Full Refund!
            modelCoin.transfer(request.requester, request.reward);

            // 4 - Refunded (No Valid Candidate Submission)
            requests[requestID].status = 4;
        } else {    // New candidate found
            // Set new candidate model and cast blame on trainer
            requests[requestID].candidateModel = bestCandidate;
            requests[requestID].blameworthy = bestCandidate.trainer;

            // 2 - Pending Candidate Validation
            requests[requestID].status = 2;

            // Ensure blameworthy trainer enjoys the full response window
            resetTimeout(requestID);
        }

    }

    function enforceTimeout(string calldata requestID) public {
        // can be called internally or externally
        ModelRequest memory request = requests[requestID];
        address requester = request.requester;
        address blameworthy = request.blameworthy;
        uint256 timeout = request.timeout;
        uint256 status = request.status;

        require(block.timestamp > timeout, "Request has not timed out.");
        if (requester == blameworthy) {
            slashRequester();
              // 6 - Requester Punished for Taking Too Long
            requests[requestID].status = 6;
        } else {
            cancelSubmission(request.candidateModel);
            pickCandidate(requestID);
        }
    }

    // If this goes well, the request is fulfilled!
    // Otherwise, the candidate is canceled and pickCandidate is called
    function candidateUpload(string calldata modelID, string calldata modelIPFS, uint256[] prediction) external {
        ModelSubmission memory model = submissions[modelID];
        ModelRequest memory request = requests[model.targetRequestID];

        require(msg.sender == model.trainer, "You are not the trainer.");
        require(prediction.length == request.testDataCount, string.concat("Prediction should be array of length ", Strings.toString(testDataCount)));

        // Compare model IPFS to previously uploaded hash TODO debug!
        require(Strings.equal(keccak256(modelIPFS), model.modelSuperhash), "Please upload the correct IPFS link corresponding to the hash from your initial submission.");

        // Compare prediction to previously uploaded hash TODO debug!
        require(Strings.equal(keccak256(prediction), model.predictionSHA), "Please the prediction corresponding to the hash from your initial submission.");

        // Compare accuracy with ground truth
        uint256 calculatedAccuracy = 0;
        for (uint256 i = 0; i < request.testDataCount; i++) {
            if (prediction[i] == request.groundTruth[i]) {
                calculatedAccuracy++;
            }
        }

        if (calculatedAccuracy == model.claimedAccuracy) {
            submissions[modelID].modelIPFS = modelIPFS; // Upload Model
            ModelCoin.transfer(model.trainer, reward + trainerStake); // send reward & stake

            // 3 - Success (Transaction Complete)
            requests[requestID].status = 3;
        } else {
            // Restart the process.
            cancelSubmission(modelID);
            pickCandidate(model.targetRequestID);
        }
    }
}
