// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// If compiling on Remix IDE, use custom ./compiler_config.json file.
// address deployed at: 0x8C2EbC431e4311dc4e8C2D2CdfB6Fb821261b055
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Import the ModelCoin contract

contract MLModelMarketplace {
    // Use SafeERC20 to prevent reentrancy attacks
    using SafeERC20 for ModelCoin;
    ModelCoin public modelCoin;

    // contract deployed at: 0x36E3F7c04038D3AE09Ca7d63326F1827172b65AC

    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }

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

    uint public responseWindow = 900;  // fifteen minutes (in seconds)

    event RequestCreated(string requestID, address requester, uint timeout);
    event RequestUpdated(string requestID, uint timeout, uint status);
    event RequestClosed (string requestID, uint status);

    event ModelSubmitted    (string modelID, string targetRequestID, address trainer);
    event SubmissionCanceled(string modelID, string targetRequestID);
    event ModelAccepted     (string modelID, string targetRequestID, string modelIPFS);


    // -------------- External View Functions ---------------
    function getRequest(string calldata requestID) external view returns (ModelRequest memory) {
        return requests[requestID];
    }

    function getStatus(string calldata requestID) external view returns (uint) {
        return requests[requestID].status;
    }

    function getSubmission(string calldata modelID) external view returns (ModelSubmission memory) {
        return submissions[modelID];
    }


    // ------------- Internal Utility Functions ---------------

    function stringOfDigit(uint digit) internal pure returns (string memory) {
        require(digit < 10, "Not a digit!");
        if (digit == 0) {return "0";}
        if (digit == 1) {return "1";}
        if (digit == 2) {return "2";}
        if (digit == 3) {return "3";}
        if (digit == 4) {return "4";}
        if (digit == 5) {return "5";}
        if (digit == 6) {return "6";}
        if (digit == 7) {return "7";}
        if (digit == 8) {return "8";}
        if (digit == 9) {return "9";}
        return "";
    }

    function stringOfArray(uint[] memory array) internal pure returns (string memory) {
        string memory outputString = "";
        for (uint i = 0; i < array.length; i++) {
            outputString = string.concat(outputString, stringOfDigit(array[i]));
        }
        return outputString;
    }

    function resetTimeout(string memory requestID) internal {
        requests[requestID].timeout = block.timestamp + responseWindow;
    }

    // Called if request is canceled and there are submissions.
    function slashRequester(string memory requestID) internal {
        ModelRequest memory request = requests[requestID];
        string[] memory modelIDs = submissionsForRequest[requestID];

        uint trainersRemaining = modelIDs.length - request.canceledCount;

        if (trainersRemaining > 0) {
            modelCoin.transfer(request.requester, request.reward);  // Full Refund!
        } else {

            // Calculate reward share
            uint rewardShare = request.reward / trainersRemaining;

            // Distrubute slashed reward to valid trainers
            for (uint i = 0; i < modelIDs.length; i++) {
                address trainer = submissions[modelIDs[i]].trainer;
                if (trainer != address(0)) {
                    modelCoin.transfer(trainer, rewardShare);
                }
            }
        }
    }

    // =========== Core Protocol ============

    function createRequest(string calldata requestID, uint reward, uint trainerStake, uint submissionWindow,
            string calldata context, string calldata trainingIPFS, string calldata unlabeledTestingIPFS,
            string calldata groundTruthSHA, uint testDataSize) external {

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

    function cancelRequest(string calldata requestID) external {
        ModelRequest memory request = requests[requestID];

        require(msg.sender == request.requester);   // Only callable by requester
        require(request.status == 0);   // and only before ground truth upload

        // Trainers compensated for their efforts (or if none, full refund)
        slashRequester(requestID);

        // 5 - Canceled by Requester
        requests[requestID].status = 5;
        emit RequestClosed(requestID, 5);
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
        emit SubmissionCanceled(modelID, model.targetRequestID);

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
        require(groundTruth.length == request.testDataSize, "Ground truth labels array is the wrong size.");

        // Ensure correct ground truth
        require(keccak256(abi.encodePacked(request.groundTruthSHA)) ==
                keccak256(abi.encodePacked(sha256(abi.encodePacked(stringOfArray(groundTruth))))));

        requests[requestID].groundTruth = groundTruth;
        requests[requestID].status = 1; // begin accepting accuracy claims
        resetTimeout(requestID);
        emit RequestUpdated(requestID, requests[requestID].timeout, 1);
    }

    function submitAccuracy(string calldata modelID, uint accuracy) external {
        ModelSubmission memory model = submissions[modelID];
        ModelRequest memory request = requests[model.targetRequestID];
        require(accuracy <= request.testDataSize, "Accuracy cannot be larger than 100%.");

        // Upload accuracy claim
        submissions[modelID].claimedAccuracy = accuracy;
    }

    function pickCandidate(string memory requestID) public {
        ModelRequest memory request = requests[requestID];

        require(msg.sender == address(this) ||
               (request.status == 1 && block.timestamp >= request.timeout),
              "This function can only be called when it is time to select a candidate!");

        string[] memory modelIDs = submissionsForRequest[requestID];

        // Initialize placeholders
        uint bestAccuracy = 0;
        string memory bestCandidate = "";
        string memory modelID = "";
        // Loop over submissions
        for (uint i = 0; i < modelIDs.length; i++) {
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

        if (bytes(bestCandidate).length == 0) { // No candidate to be found
            // Full Refund!
            modelCoin.transfer(request.requester, request.reward);

            // 4 - Refunded (No Valid Candidate Submission)
            requests[requestID].status = 4;
            emit RequestClosed(requestID, 4);
        } else {    // New candidate found
            // Set new candidate model and cast blame on trainer
            requests[requestID].candidateModel = bestCandidate;
            requests[requestID].blameworthy = submissions[bestCandidate].trainer;

            // 2 - Pending Candidate Validation
            requests[requestID].status = 2;
            resetTimeout(requestID);
            emit RequestUpdated(requestID, requests[requestID].timeout, 2);
        }
    }

    function enforceTimeout(string memory requestID) public {
        // can be called internally or externally
        ModelRequest memory request = requests[requestID];

        require(block.timestamp > request.timeout, "Request has not timed out.");
        if (request.requester == request.blameworthy) {
            slashRequester(requestID);
            // 6 - Requester Punished for Taking Too Long
            requests[requestID].status = 6;
            emit RequestClosed(requestID, 6);
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
        require(prediction.length == request.testDataSize, "Prediction array should have one element per testing datum");

        // Ensure model IPFS corresponds to superhash from submission
        require(keccak256(abi.encodePacked(model.modelSuperhash)) ==
                keccak256(abi.encodePacked(sha256(abi.encodePacked(modelIPFS)))),
        "Please upload the raw IPFS link corresponding to the hash from your initial submission.");

        // Compare prediction to previously uploaded hash
        require(keccak256(abi.encodePacked(model.predictionSHA)) ==
                keccak256(abi.encodePacked(sha256(abi.encodePacked(stringOfArray(prediction))))),
        "Please upload the raw prediction corresponding to the hash from your initial submission.");

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
            emit RequestClosed(model.targetRequestID, 3);
            emit ModelAccepted(model.targetRequestID, modelID, modelIPFS);
        } else {
            // Restart the process.
            cancelSubmission(modelID);
            pickCandidate(model.targetRequestID);
        }
    }
}
