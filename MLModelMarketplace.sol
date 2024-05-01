// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Import the ModelCoin contract
import "@openzeppelin/contracts/utils/Strings.sol"; // String utils

contract MLModelMarketplace {
    // Use SafeERC20 to prevent reentrancy attacks
    using SafeERC20 for ModelCoin;
    ModelCoin public modelCoin;

    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }

    // contract deployed at: 0x36E3F7c04038D3AE09Ca7d63326F1827172b65AC

    // ----------------- Model Request -----------------
    struct ModelRequest {
        // Parameters
        address requester;
        uint reward;
        uint trainerStake;
        uint deadline;   // DERIVED: timestamp of submission closure
        string context;         // relevant instructions / info
        string trainingIPFS;
        string unlabeledTestingIPFS;
        string groundTruthSHA;
        uint testDataSize;   // # of elements in testing data

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

        uint status;            // current status code
        address blameworthy;    // responsible for preventing timeout
        uint timeout;           // timestamp when contract will revert
        uint canceledCount;     // # of canceled submissions

        // Ground Truth
        uint[] groundTruth;

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
        uint claimedAccuracy;    // # of testing data correctly categorized
        string modelIPFS;           // Publicly visible!!!
        uint[] prediction;
    }


    // ----------------- Establish Variables -----------------
    mapping(string => ModelRequest) public requests; // All requests
    mapping(string => ModelSubmission) public submissions; // All models
    mapping(string => string[]) private submissionsForRequest; // Map requestID to list of modelIDs

    uint public requestCount; // TODO necessary?
    uint public responseWindow = 900;  // fifteen minutes (in seconds)

    event RequestCreated (string requestID, address requester, uint timeout);
    event RequestUpdated(string requestID, uint timeout, uint status);
    event RequestCanceled(string requestID, uint status);

    event ModelSubmitted    (string modelID, string targetRequestID, address trainer);
    event SubmissionCanceled(string modelID, string targetRequestID);
    event ModelAccepted(string requestID, string modelID, string modelIPFS);


    // -------------- External View Functions ---------------
    function getRequest(string calldata requestID) external view returns (ModelRequest memory) {
        return requests[requestID];
    }

    function getSubmission(string calldata modelID) external view returns (ModelSubmission memory) {
        return submissions[modelID];
    }


    // ------------- Internal Utility Functions ---------------

    function stringOfArray(uint[] memory array) internal pure returns (string memory) {
        string memory outputString = "";
        for (uint i = 0; i < array.length; i++) {
            outputString = string.concat(outputString, Strings.toString(array[i]));
        }
        return outputString;
    }

    function resetTimeout(string memory requestID) internal {
        requests[requestID].timeout = block.timestamp + responseWindow;
        // add event
    }

    // Called if request is canceled and there are submissions.
    function slashRequester(string memory requestID) internal {
        ModelRequest memory request = requests[requestID];
        string[] memory modelIDs = submissionsForRequest[requestID];

        // Calculate reward share
        uint numTrainers = modelIDs.length - request.canceledCount;
        uint slice = request.reward / numTrainers;

        // Distrubute slashed reward to valid trainers
        for (uint i = 0; i < modelIDs.length; i++) {
            address trainer = submissions[modelIDs[i]].trainer;
            if (trainer != address(0)) {
                modelCoin.transfer(trainer, slice);
            }
        }
    }

    // =========== Core Protocol ============ TODO: update!!!

    function createRequest(string calldata requestID, uint reward, uint trainerStake, uint submissionWindow,
                           string calldata context, string calldata trainingIPFS,
                           string calldata unlabeledTestingIPFS, string calldata groundTruthSHA,
                           uint testDataSize) external {

        require(modelCoin.transferFrom(msg.sender, address(this), reward), "Transfer failed"); // absorb reward

        requests[requestID] = ModelRequest({
            // Parameters
            requester: msg.sender,
            reward: reward,
            trainerStake: trainerStake,
            deadline: block.timestamp + submissionWindow,
            context: context,
            trainingIPFS: trainingIPFS,
            unlabeledTestingIPFS: unlabeledTestingIPFS,
            groundTruthSHA: groundTruthSHA,
            testDataSize: testDataSize,

            // Tracking
            status: 0,
            blameworthy: msg.sender,
            timeout: block.timestamp + submissionWindow + responseWindow,
            canceledCount: 0,
            groundTruth: new uint[](testDataSize),
            candidateModel: ""
        });

        emit RequestCreated(requestID, msg.sender, requests[requestID].timeout);
    }

    function cancelRequest(string calldata requestID) external returns (string memory) {
        ModelRequest memory request = requests[requestID];
        address requester = request.requester;
        uint status = request.status;

        require(msg.sender == requester);   // Only callable by requester
        require(status == 0);   // and only before ground truth upload

        if((submissionsForRequest[requestID].length - request.canceledCount) == 0) {
            // Full Refund!
            modelCoin.transfer(request.requester, request.reward);
        } else {
            // Trainers compensated for their efforts
            slashRequester(requestID);
        }
        // 5 - Canceled by Requester
        requests[requestID].status = 5;
    }

    function submitModel(string calldata targetRequestID, string calldata modelID,
    string calldata modelSuperhash, string calldata predictionSHA) external {
        ModelRequest memory request = requests[targetRequestID];

        require(request.requester != address(0), "Invalid target!");
        require(submissions[modelID].trainer == address(0), "Model already uploaded!");
        require(block.timestamp < request.deadline, "Submissions are closed.");
        require(request.status == 0, "This request has been canceled.");

        // Require staking of collateral
        require(modelCoin.transferFrom(msg.sender, address(this), request.trainerStake), "Collateral staking failed");

        uint testDataSize = request.testDataSize;
        uint[] memory blankArray;

        submissions[modelID] = ModelSubmission({
            trainer: msg.sender,
            targetRequestID: targetRequestID,
            modelSuperhash: modelSuperhash,
            predictionSHA: predictionSHA,
            // For Later
            claimedAccuracy: request.testDataSize + 1, // Not uploaded yet
            modelIPFS: "",                              // Not uploaded yet
            prediction: blankArray  // Not uploaded yet
        });

        // keep submissions indexed by request!
        submissionsForRequest[targetRequestID].push(modelID);

        // requests[requestID].submissionCount++;
        emit ModelSubmitted(modelID, targetRequestID, msg.sender);
    }

    function cancelSubmission(string memory modelID) public {
        // Can be called internally or by model trainer
        ModelSubmission memory model = submissions[modelID];
        ModelRequest memory request = requests[model.targetRequestID];

        require(msg.sender == address(this) || msg.sender == model.trainer, "Invalid submission.");

        delete submissions[modelID];    // reset mapping to 0
        request.canceledCount++; // log cancelation

        // Refund trainer stake if before deadline
        if (block.timestamp < request.deadline) {
            modelCoin.transfer(model.trainer, request.trainerStake);
        }
    }

    function uploadGroundTruth(string calldata requestID, uint[] calldata groundTruth) external {
        ModelRequest memory request = requests[requestID];

        require(msg.sender == request.requester, "Only the requester can upload ground truth testing labels!");
        require(request.status == 0, "The ground truth cannot be uploaded now!");
        require(block.timestamp >= request.deadline, "It is too early to upload the ground truth! Wait until the submission deadline.");

        // require correct ground truth length
        require(groundTruth.length == request.testDataSize, string.concat("Ground truth labels should be an array of length ", Strings.toString(request.testDataSize)));

        // Convert groundTruth array into string format
        string memory groundTruthString = stringOfArray(groundTruth);



        // ALTERNATE GT COMPARISON USING KECCAK:

        require(keccak256(abi.encodePacked(request.groundTruthSHA)) ==
                keccak256(abi.encodePacked(sha256(abi.encodePacked(groundTruthString)))));

        // Ensure correct ground truth
        //require(Strings.equal(request.groundTruthSHA,
        //                      string(abi.encodePacked(sha256(abi.encodePacked(groundTruthString))))),
        //                      "Please upload the correctly formatted ground truth corresponding"
        //                      "to the hash uploaded in your initial request!");

        requests[requestID].groundTruth = groundTruth;
        requests[requestID].status = 1; // begin accepting accuracy claims
        resetTimeout(requestID);
    }

    function submitAccuracy(string calldata modelID, uint accuracy) external {
        ModelSubmission memory model = submissions[modelID];
        ModelRequest memory request = requests[model.targetRequestID];
        require(accuracy <= request.testDataSize, string.concat("Accuracy is number correct out of ", Strings.toString(request.testDataSize)));

        // Upload accuracy claim
        submissions[modelID].claimedAccuracy = accuracy;
    }

    function pickCandidate(string memory requestID) public {
        ModelRequest memory request = requests[requestID];
        uint timeout = request.timeout;
        uint status = request.status;

        require(msg.sender == address(this) || ((status == 1 || status == 2) && block.timestamp >= timeout), "This function can only be called when it is time to select a candidate!");

        string[] memory modelIDs = submissionsForRequest[requestID];
        uint modelCount = modelIDs.length;

        // Initialize placeholders
        uint bestAccuracy = 0;
        string memory bestCandidate = "";
        string memory modelID = "";
        // Loop over submissions
        for (uint i = 0; i < modelCount; i++) {
            modelID = modelIDs[i];
            ModelSubmission memory model = submissions[modelID];

            // If submission is valid and not canceled:
            if (model.claimedAccuracy > bestAccuracy) {
                bestCandidate = modelID;
                bestAccuracy = model.claimedAccuracy;
            } else if (model.trainer != address(0))
            {   // Cancel submissions without listed accuracy.
                cancelSubmission(modelID);
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
            requests[requestID].blameworthy = submissions[bestCandidate].trainer;

            // 2 - Pending Candidate Validation
            requests[requestID].status = 2;

            // Ensure blameworthy trainer enjoys the full response window
            resetTimeout(requestID);
        }
        // add event
    }

    function enforceTimeout(string memory requestID) public {
        // can be called internally or externally
        ModelRequest memory request = requests[requestID];
        address requester = request.requester;
        address blameworthy = request.blameworthy;
        uint timeout = request.timeout;
        uint status = request.status;

        require(block.timestamp > timeout, "Request has not timed out.");
        if (requester == blameworthy) {
            slashRequester(requestID);
              // 6 - Requester Punished for Taking Too Long
            requests[requestID].status = 6;
        } else {
            cancelSubmission(request.candidateModel);
            pickCandidate(requestID);
        }
    }

    // If this goes well, the request is fulfilled!
    // Otherwise, the candidate is canceled and pickCandidate is called
    function candidateUpload(string calldata modelID, string calldata modelIPFS, uint[] calldata prediction) external {
        ModelSubmission memory model = submissions[modelID];
        ModelRequest memory request = requests[model.targetRequestID];

        require(msg.sender == model.trainer, "You are not the trainer.");
        require(prediction.length == request.testDataSize, string.concat("Prediction should be array of length ", Strings.toString(request.testDataSize)));

        // Ensure model IPFS corresponds to superhash from submission
        require(Strings.equal(model.modelSuperhash, string(abi.encodePacked(sha256(abi.encodePacked(modelIPFS))))),
        "Please upload the correct IPFS link corresponding to the hash from your initial submission.");

        // Convert prediction array into string format
        string memory predictionString = stringOfArray(prediction);

        // Compare prediction to previously uploaded hash
        require(Strings.equal(model.predictionSHA, string(abi.encodePacked(sha256(abi.encodePacked(predictionString))))),
        "Please the prediction corresponding to the SHA hash from your initial submission.");
        // Compare accuracy with ground truth
        uint calculatedAccuracy = 0;
        for (uint i = 0; i < request.testDataSize; i++) {
            if (prediction[i] == request.groundTruth[i]) {
                calculatedAccuracy++;
            }
        }

        if (calculatedAccuracy == model.claimedAccuracy) {
            submissions[modelID].modelIPFS = modelIPFS; // Upload Model
            modelCoin.transfer(model.trainer, request.reward + request.trainerStake); // send reward & stake

            // 3 - Success (Transaction Complete)
            requests[model.targetRequestID].status = 3;
        } else {
            // Restart the process.
            cancelSubmission(modelID);
            pickCandidate(model.targetRequestID);
        }
    }
}
