import { modelContractABI } from "./ModelCoin.abi";

document.getElementById("connectWallet").addEventListener("click", async () => {
  if (typeof window.ethereum !== "undefined") {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    window.signer = await provider.getSigner();
    console.log("Connected to MetaMask:", await signer.getAddress());
  } else {
    console.log("MetaMask is not installed!");
    alert("Please install MetaMask to use this feature.");
  }
});

const modelHashes = new Map();
const modelHashesLengths = new Map();

const modelTestingGuessesURL = new Map();
const modeluploadResultURL = new Map();

document
  .getElementById("submitButton")
  .addEventListener("click", async function () {
    if (!window.signer) {
      alert("Please connect to MetaMask first.");
      return;
    }

    alert(
      "*****IMPORTANT*****\nIt is your responsibility to keep track of the IPFS link to your testing data labels\nIf you lose these values your model may not be recoverable or you may lose your reward offered/collateral",
    );

    const dataFile = document.getElementById("dataInput").files[0];
    const labelsFile = document.getElementById("labelsInput").files[0];
    const modelIdInput = document.getElementById("modelIdInput").value;
    const rewardInput = document.getElementById("rewardInput").value;
    const contextInput = document.getElementById("contextInput").value;
    const minutesInput = document.getElementById("minutesInput").value;

    if (
      !dataFile ||
      !labelsFile ||
      !modelIdInput ||
      !rewardInput ||
      !contextInput ||
      !minutesInput
    ) {
      console.log("Form not filled out");
      alert("Please fill out all form elements");
      return;
    }

    if (modelHashes.has(modelIdInput)) {
      alert("Select a unique model ID");
      return;
    }

    const currentTime = new Date();
    const expirationTime = new Date(
      currentTime.getTime() + minutesInput * 60000,
    );

    console.log(`Uploading ${dataFile.name} and ${labelsFile.name}...`);

    const parsedData = await parseAndShuffleData(dataFile, labelsFile);
    if (!parsedData) return;

    try {
      const formDataTrain = new FormData();
      formDataTrain.append(
        "file",
        new Blob([parsedData.trainingCsv], { type: "text/csv" }),
        "training.csv",
      );
      const formDataTest = new FormData();
      formDataTest.append(
        "file",
        new Blob([parsedData.testingCsv], { type: "text/csv" }),
        "testing.csv",
      );
      const formDataTestLabels = new FormData();
      formDataTestLabels.append(
        "file",
        new Blob([parsedData.testingLabelsCsv], { type: "text/csv" }),
        "testing_labels.csv",
      );

      const [trainResponse, testResponse, testLabelsResponse] =
        await Promise.all([
          fetch("http://localhost:3000/upload_train_test_weights", {
            method: "POST",
            body: formDataTrain,
          }),
          fetch("http://localhost:3000/upload_train_test_weights", {
            method: "POST",
            body: formDataTest,
          }),
          fetch("http://localhost:3000/upload_train_test_weights", {
            method: "POST",
            body: formDataTestLabels,
          }),
        ]);

      const trainResult = await trainResponse.json();
      const testResult = await testResponse.json();
      const testLabelsResult = await testLabelsResponse.json();
      const hashTestLabelsUrl = CryptoJS.SHA256(
        testLabelsResult.url,
      ).toString();

      modelHashes.set(modelIdInput, hashTestLabelsUrl);
      modelHashesLengths.set(modelIdInput, parsedData.testingLabels.length);
      prompt(
        "*****IMPORTANT*****\nTesting data (LABELS) URL (Ctrl+C the text box):",
        testLabelsResult.url,
      );

      displayModelData({
        id: modelIdInput,
        reward: parseFloat(rewardInput).toFixed(2),
        context: contextInput,
        urlTrain: trainResult.url,
        urlTest: testResult.url,
        hashTestUrl: hashTestLabelsUrl,
        expiration: expirationTime,
      });
    } catch (error) {
      console.error("Upload failed:", error);
      alert(`Upload failed: ${error.message}`);
    }
  });

function displayModelData(data) {
  const modelList = document.getElementById("modelList");
  const entry = document.createElement("li");
  entry.setAttribute("data-id", data.id);

  const expirationString = data.expiration
    ? data.expiration.toLocaleString()
    : "Not set";

  entry.innerHTML = `ID: ${data.id}, Reward: ${data.reward}, Context: ${data.context},
                         <a href="${data.urlTrain}" target="_blank">Training Data URL</a>,
                         <a href="${data.urlTest}" target="_blank">Testing Data URL</a>,
                         Testing Data Labels SHA256: ${data.hashTestUrl},
                         Expiration Time: <span class="expiration-time">${expirationString}</span>`;

  modelList.appendChild(entry);

  const modelsToVerifyList = document.getElementById("modelsToVerifyList");
  const verifyEntry = document.createElement("li");
  verifyEntry.setAttribute("data-id", data.id);
  verifyEntry.innerHTML = `Model ID: ${data.id}`;
  verifyEntry.appendChild(document.createElement("ul"));
  modelsToVerifyList.appendChild(verifyEntry);
}

function finalizeModelDeletion(
  modelId,
  modelList,
  entry,
  highestPredictions,
  highestUploadId,
) {
  if (highestUploadId) {
    alert(
      `For model ID ${modelId}, Upload ID ${highestUploadId} claims to have the most correct predictions.`,
    );
    displayZKSnarkRequirement(modelId, highestUploadId, highestPredictions);
  }

  const relatedParentEntries = modelsToVerifyList.querySelectorAll(
    `li[data-id='${modelId}']`,
  );
  relatedParentEntries.forEach((parentEl) => {
    parentEl.remove();
  });

  modelList.removeChild(entry);
  modelHashes.delete(modelId);
  modelHashesLengths.delete(modelId);
  modelTestingIDs.delete(modelId);
}

async function promptForPredictions(modelId, uploadId) {
  return new Promise((resolve) => {
    const predictions = prompt(
      `For model ID: ${modelId}, the ${uploadId} number of correct predictions is:`,
    );
    resolve(predictions);
  });
}

function displayZKSnarkRequirement(modelId, uploadId, predictions) {
  const zkSnarkList = document.getElementById("modelsRequiringZKSnark");
  const newItem = document.createElement("li");
  newItem.innerHTML = `Model ID: ${modelId}, Upload ID: ${uploadId}, Correct Predictions: ${predictions}`;
  zkSnarkList.appendChild(newItem);
}

const predictionsMap = new Map();

function checkForExpiredModels() {
  console.log("Checking for expired models");
  const currentTime = new Date();
  const modelList = document.getElementById("modelList");
  const entries = modelList.querySelectorAll("li");

  entries.forEach(async (entry) => {
    const expirationSpan = entry.querySelector(".expiration-time");
    if (expirationSpan) {
      const expiration = new Date(expirationSpan.textContent);
      if (expiration < currentTime) {
        const modelId = entry.getAttribute("data-id");
        const hashToVerify = modelHashes.get(modelId);

        // Prompt user to input the hash of the test labels
        const userHashInput = prompt(
          "Input the hash of the test labels for Model ID: " + modelId,
        );
        const userHash = CryptoJS.SHA256(userHashInput).toString();

        if (userHash === hashToVerify) {
          alert("Verification passed");
          displayVerifiedTestLabel(modelId, userHashInput);
        } else {
          alert("Verification failed");
        }

        const uploadIds = modelTestingIDs.get(modelId);
        let highestPredictions = 0;
        let highestUploadId = null;
        if (uploadIds && uploadIds.length > 0) {
          const timer = setTimeout(() => {
            finalizeModelDeletion(
              modelId,
              modelList,
              entry,
              highestPredictions,
              highestUploadId,
            );
          }, 120000); // 120 seconds

          for (let uploadId of uploadIds) {
            const predictions = await promptForPredictions(modelId, uploadId);
            if (parseInt(predictions, 10) > highestPredictions) {
              highestPredictions = parseInt(predictions, 10);
              highestUploadId = uploadId;
            }
          }

          clearTimeout(timer); // Clear the timer if user responds in time for now
          finalizeModelDeletion(
            modelId,
            modelList,
            entry,
            highestPredictions,
            highestUploadId,
          );
        } else {
          alert("No models uploaded for Model ID: " + modelId);
          finalizeModelDeletion(
            modelId,
            modelList,
            entry,
            highestPredictions,
            highestUploadId,
          );
        }
      }
    }
  });
}

function displayVerifiedTestLabel(modelId, testLabelUrl) {
  const modelTestLabelsList = document.getElementById("modelTestLabelsList");
  const item = document.createElement("li");
  item.innerHTML = `Model ID: ${modelId}, <a href="${testLabelUrl}" target="_blank">Test Labels</a>`;
  modelTestLabelsList.appendChild(item);
}

async function parseAndShuffleData(dataFile, labelsFile) {
  const dataText = await dataFile.text();
  const labelsText = await labelsFile.text();
  const dataResults = Papa.parse(dataText, { header: false }).data;
  const labelsResults = Papa.parse(labelsText, { header: false }).data;

  if (dataResults.length !== labelsResults.length) {
    alert("Data and labels files do not have the same number of entries.");
    return null;
  }

  let indices = Array.from(dataResults.keys());
  shuffleArray(indices);

  const shuffledData = indices.map((index) => dataResults[index]);
  const shuffledLabels = indices.map((index) => labelsResults[index]);

  const trainingSize = Math.floor(shuffledData.length * 0.9);
  const trainingData = shuffledData.slice(0, trainingSize);
  const trainingLabels = shuffledLabels.slice(0, trainingSize);
  const testingData = shuffledData.slice(trainingSize);
  const testingLabels = shuffledLabels.slice(trainingSize);

  const trainingCsv = Papa.unparse(
    trainingData.map((item, index) => [...item, trainingLabels[index]]),
  );
  const testingCsv = Papa.unparse(testingData); // Testing data without labels
  const testingLabelsCsv = Papa.unparse(testingLabels); // Only testing data labels

  return {
    trainingCsv: trainingCsv,
    testingCsv: testingCsv,
    testingLabelsCsv: testingLabelsCsv,
    testingLabels: testingLabels,
  };
}

function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

const modelTestingIDs = new Map();

document
  .getElementById("verifyButton")
  .addEventListener("click", async function () {
    if (!window.signer) {
      alert("Please connect to MetaMask first.");
      return;
    }

    const modelIdToVerify = document.getElementById("verifyModelIdInput").value;
    const modelUploadId = document.getElementById("modelUploadIdInput").value;
    const guessesFile = document.getElementById("guessesInput").files[0];
    const modelFile = document.getElementById("modelInput").files[0];

    if (!modelIdToVerify || !guessesFile || !modelFile || !modelUploadId) {
      alert("Please fill all fields correctly.");
      return;
    }

    const guessesText = await guessesFile.text();
    const guessesData = Papa.parse(guessesText, { header: false }).data;

    if (modelHashesLengths.get(modelIdToVerify) !== guessesData.length) {
      alert(
        "The number of records in the guesses file does not match the testing data or the model request has expired",
      );
      return;
    }

    if (modelHashes.has(modelIdToVerify)) {
      try {
        const formDataGuesses = new FormData();
        formDataGuesses.append("file", guessesFile);
        const formDataModel = new FormData();
        formDataModel.append("file", modelFile);

        const [guessesResponse, modelResponse] = await Promise.all([
          fetch("http://localhost:3000/upload_train_test_weights", {
            method: "POST",
            body: formDataGuesses,
          }),
          fetch("http://localhost:3000/upload_train_test_weights", {
            method: "POST",
            body: formDataModel,
          }),
        ]);

        const guessesResult = await guessesResponse.json();
        const modelResult = await modelResponse.json();

        const hashGuessesUrl = CryptoJS.SHA256(guessesResult.url).toString();
        const hashModelUrl = CryptoJS.SHA256(modelResult.url).toString();

        modelTestingGuessesURL.set(modelIdToVerify, {
          [modelUploadId]: guessesResult.url,
        });
        modeluploadResultURL.set(modelIdToVerify, {
          [modelUploadId]: modelResult.url,
        });

        prompt(
          "*****IMPORTANT*****\nTesting guesses URL (Ctrl+C the text box):",
          guessesResult.url,
        );
        prompt(
          "*****IMPORTANT*****\nModel URL (Ctrl+C the text box):",
          modelResult.url,
        );

        const modelsToVerifyList =
          document.getElementById("modelsToVerifyList");
        let modelSection = modelsToVerifyList.querySelector(
          `li[data-id='${modelIdToVerify}'] ul`,
        );
        if (!modelSection) {
          console.error("Model section not found for ID:", modelIdToVerify);
          return;
        }

        const newItem = document.createElement("li");
        newItem.innerHTML = `Upload ID: ${modelUploadId}, Model: ${hashModelUrl}, Guesses: ${hashGuessesUrl}`;
        modelSection.appendChild(newItem);

        if (!modelTestingIDs.has(modelIdToVerify)) {
          modelTestingIDs.set(modelIdToVerify, []);
        }
        modelTestingIDs.get(modelIdToVerify).push(modelUploadId);
      } catch (error) {
        console.error("Error uploading weights file:", error);
        alert(`Error: ${error.message}`);
      }
    } else {
      alert("Model ID not found for verification.");
    }
  });

function displayVerifiedModel(modelId, weightsUrl, testingUrl) {
  const list = document.getElementById("modelsToVerifyList");
  const item = document.createElement("li");
  item.innerHTML = `Model ID: ${modelId}, <a href="${weightsUrl}" target="_blank">Weights File</a>, <a href="${testingUrl}" target="_blank">Testing URL</a>`;
  list.appendChild(item);
}
// Airdrop tokens
async function triggerAirdrop() {
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const signer = provider.getSigner();

  const contractABI = modelContractABI;
  const contractAddress = "0x5e17b14ADd6c386305A32928F985b29bbA34Eff5";
  const modelCoinContract = new ethers.Contract(
    contractAddress,
    contractABI,
    signer,
  );

  try {
    const tx = await modelCoinContract.airdrop();
    await tx.wait();
    console.log("Airdrop executed successfully:", tx);
  } catch (error) {
    console.error("Error triggering airdrop:", error);
  }
}

document
  .getElementById("airdropButton")
  .addEventListener("click", triggerAirdrop);

document.addEventListener("DOMContentLoaded", () => {
  setInterval(checkForExpiredModels, 30000);
});

document
  .getElementById("submitZkSnarkButton")
  .addEventListener("click", async function () {
    const modelId = document.getElementById("zkSnarkModelIdInput").value;
    const modelUploadId = document.getElementById(
      "zkSnarkModelUploadIdInput",
    ).value;
    const predictionLabelIpfs = document.getElementById(
      "zkSnarkPredictionLabelIpfsInput",
    ).value;
    const zkSnarkFile = document.getElementById("zkSnarkFileInput").files[0];

    if (!modelId || !modelUploadId || !predictionLabelIpfs || !zkSnarkFile) {
      alert("Please fill out all fields.");
      return;
    }
    /*
    const formData = new FormData();
    formData.append("file", zkSnarkFile);

    try {
        const response = await fetch("http://localhost:3000/upload_train_test_weights", {
            method: "POST",
            body: formData
        });
        const result = await response.json();
        const zkSnarkUrl = result.url;
        alert(`zk-SNARK uploaded successfully. URL: ${zkSnarkUrl}`);

        const zkSnarkList = document.getElementById("modelsRequiringZKSnark");
        const item = document.createElement("li");
        item.innerHTML = `Model ID: ${modelId}, Upload ID: ${modelUploadId}, Correct Predictions: Highest, zk-SNARK File: <a href="${zkSnarkUrl}" target="_blank">Download</a>`;
        zkSnarkList.appendChild(item);
    } catch (error) {
        console.error("Error uploading zk-SNARK file:", error);
        alert(`Error: ${error.message}`);
    }*/
  });
