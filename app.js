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

const labelsArrs = new Map();

document
  .getElementById("submitButton")
  .addEventListener("click", async function () {
    if (!window.signer) {
      alert("Please connect to MetaMask first.");
      return;
    }

    alert(
      "*****IMPORTANT*****\n\nIt is your responsibility to keep track of the hash to your testing data labels\n\nIf you lose these values your model may not be recoverable or you may lose your reward offered/collateral",
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
    //handleFileSelect(labelsFile, modelIdInput);
    try {
      const parsedData = await parseAndShuffleData(dataFile, labelsFile);
      if (!parsedData) {
        alert("Issue parsing");
        return;
      } else {
        console.log("data parsed");
      }

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
        //const testLabelsResult = await testLabelsResponse.json();
        //const hashTestLabelsUrl = CryptoJS.SHA256(
        //  testLabelsResult.url,
        //).toString();

        // Example usage with a Blob from FormData
        // Assuming 'formDataTestLabels' has been properly filled with a Blob of CSV data
        const csvBlob = formDataTestLabels.get("file");
        //const hashTestLabelsUrl = readAndParseCsv(csvBlob);
        const reader = new FileReader();
        reader.onload = async function (event) {
          const csvString = event.target.result;
          const numbersArray = parseCsvToNumbers(csvString);
          console.log("Model: ", modelIdInput, ": ", numbersArray); // Outputs the array of numbers
          const hashTestLabelsUrl = CryptoJS.SHA256(
            numbersArray.join(""),
          ).toString();
          modelHashes.set(modelIdInput, numbersArray);
          modelHashesLengths.set(modelIdInput, parsedData.testingLabels.length);

          prompt(
            "*****IMPORTANT*****\n\nTesting data (LABELS) (Ctrl+C the text box):",
            numbersArray.join(""),
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

          const provider = new ethers.providers.Web3Provider(window.ethereum);
          const signer = provider.getSigner();

          const contractABI = marketplaceContractABI;
          const contractAddress = "0x39ae2482B07c0538968C17E58de124DD39C0151E";
          const marketplaceContract = new ethers.Contract(
            contractAddress,
            contractABI,
            signer,
          );

          try {
            console.log("Triggering model request...");
            const tx = await marketplaceContract.createRequest(
              rewardInput,
              modelIdInput,
            );
            await tx.wait();
            console.log("Model Request executed successfully:", tx);
            alert("Model Request successful! Transaction hash: " + tx.hash);
          } catch (error) {
            console.error("Error triggering model request:", error);
            alert("Model Request failed: " + error.message);
          }
        };
        reader.readAsText(csvBlob);
      } catch (error) {
        console.error("Upload failed:", error);
        alert(`Upload failed: ${error.message}`);
      }
    } catch (error) {
      console.error("Failed to get labels from file:", error);
      return null;
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

async function finalizeModelDeletion(
  modelId,
  modelList,
  entry,
  highestPredictions,
  highestUploadId,
) {
  if (highestUploadId) {
    alert(
      `EVERYONE: For model ID ${modelId}, Upload ID ${highestUploadId} claims to have the most correct predictions.`,
    );
    displayZKSnarkRequirement(modelId, highestUploadId, highestPredictions);
    const testGuessesUrl = prompt(
      "MODEL CREATOR: Provide the labels for your test guesses whose hash was revealed to you earlier:",
    );

    if (testGuessesUrl) {
      const hashTestGuessesUrl = CryptoJS.SHA256(testGuessesUrl).toString();
      const guessesInfo = modelTestingGuessesURL.get(modelId);
      console.log(testGuessesUrl);
      console.log(guessesInfo[highestUploadId]);
      if (
        guessesInfo &&
        CryptoJS.SHA256(guessesInfo[highestUploadId].join("")).toString() ===
          hashTestGuessesUrl
      ) {
        alert("Testing labels verified.");
        //const file = await fetchFileAsBlob(testGuessesUrl); // Fetch the file as Blob
        //handleFileSelect(file, highestUploadId); // Process the file to get labels data
        compareLabelsArrays(
          guessesInfo[highestUploadId],
          modelHashes.get(modelId),
          highestPredictions,
          modelId,
          highestUploadId,
        );
      } else {
        alert("Testing labels not verified. Stake Slashed.");
        console.log("testing hash of labels incorrect");
        removeModelEntriesFromList("modelsRequiringZKSnark", modelId);
        removeModelEntriesFromList("modelTestLabelsList", modelId);
        removeModelEntriesFromList("modelsToVerifyList", modelId);
      }
    }
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

async function fetchFileAsBlob(url) {
  const response = await fetch(url);
  return response.blob();
}

async function compareLabelsArrays(
  newLabels,
  original,
  number,
  modelId,
  highestUploadId,
) {
  if (original.length !== newLabels.length) {
    console.error("The arrays do not have the same length.");
    return;
  }
  let matchCount = 0;
  original.forEach((item, index) => {
    if (item === newLabels[index]) {
      matchCount++;
    }
  });
  console.log(`Number of matching predictions: ${matchCount}`);
  if (number == matchCount) {
    console.log("Verified number of correct predictions");
    const model = prompt(
      `For model Request: ${modelId}, the model ID: ${highestUploadId} IPFS file is:`,
    );
    const modelInfo = modeluploadResultURL.get(modelId);
    console.log(modelInfo[highestUploadId]);
    if (modelInfo[highestUploadId] == CryptoJS.SHA256(model)) {
      console.log("Model Uploaded Successfully!");
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner();
  /*
      const contractABI = marketplaceContractABI;
      const contractAddress = "0x39ae2482B07c0538968C17E58de124DD39C0151E";
      const marketplaceContract = new ethers.Contract(
        contractAddress,
        contractABI,
        signer,
      );
      
      try {
        console.log("Triggering model request...");
        const tx = await marketplaceContract.finalVerification(modelIdInput);
        await tx.wait();
        console.log("Model Request executed successfully:", tx);
        alert("Model Request successful! Transaction hash: " + tx.hash);
      } catch (error) {
        console.error("Error triggering model request:", error);
        alert("Model Request failed: " + error.message);
      }*/

      const finalModels = document.getElementById("finalModels");
      const item = document.createElement("li");
      item.innerHTML = `Model ID: ${modelId}, <a href="${model}" target="_blank">Model</a>`;
      removeModelEntriesFromList("modelsRequiringZKSnark", modelId);
      removeModelEntriesFromList("modelTestLabelsList", modelId);
      removeModelEntriesFromList("modelsToVerifyList", modelId);
      finalModels.appendChild(item);
    }
  } else {
    console.log("Model not equal");
    alert("Model IPFS URL not correct");
    removeModelEntriesFromList("modelsRequiringZKSnark", modelId);
    removeModelEntriesFromList("modelTestLabelsList", modelId);
    removeModelEntriesFromList("modelsToVerifyList", modelId);
  }
}

function removeModelEntriesFromList(listId, modelId) {
  const list = document.getElementById(listId);
  if (!list) {
    console.error("List not found with ID:", listId);
    return;
  }

  // Retrieve all list items
  const listItems = list.querySelectorAll("li");
  listItems.forEach((item) => {
    // Check if the list item contains the specific model ID
    if (item.innerHTML.includes(`Model ID: ${modelId}`)) {
      // Remove the list item if it matches
      list.removeChild(item);
    }
  });
}

async function promptForPredictions(modelId, uploadId) {
  return new Promise((resolve) => {
    const predictions = prompt(
      `For model Request: ${modelId}, the model ID: ${uploadId} number of correct predictions is:`,
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

        modelList.removeChild(entry);

        const userHashInput = prompt(
          "MODEL REQUESTER: Input the test labels revealed earlier to you for Model ID: " +
            modelId,
        );
        const userHash = CryptoJS.SHA256(userHashInput).toString();

        const uploadIds = modelTestingIDs.get(modelId);
        let highestPredictions = 0;
        let highestUploadId = null;

        if (userHash == CryptoJS.SHA256(hashToVerify.join(""))) {
          alert("Verification passed");
          const success = await displayVerifiedTestLabel(
            modelId,
            userHashInput,
          );
          if (success) {
            console.log("await succes");
          } else {
            console.log("await failure");
          }
          setTimeout(async () => {
            if (uploadIds && uploadIds.length > 0) {
              /*const timer = setTimeout(() => {
                    finalizeModelDeletion(modelId, modelList, entry, highestPredictions, highestUploadId);
                }, 120000); // 120 seconds */

              for (let uploadId of uploadIds) {
                const predictions = await promptForPredictions(
                  modelId,
                  uploadId,
                );
                if (parseInt(predictions, 10) > highestPredictions) {
                  highestPredictions = parseInt(predictions, 10);
                  highestUploadId = uploadId;
                }
              }
              //clearTimeout(timer);
              //finalizeModelDeletion(modelId, modelList, entry, highestPredictions, highestUploadId);
              alert(
                `For Model Request ID: ${modelId}, Model Upload ID: ${highestUploadId} claims to have the most correct predictions.`,
              );
              displayZKSnarkRequirement(
                modelId,
                highestUploadId,
                highestPredictions,
              );

              const testGuessesUrl = prompt(
                `MODEL CREATOR: Provide the testing labels revealed to you earlier for Model Upload ID: ${highestUploadId}.`,
              );

              if (testGuessesUrl) {
                const hashTestGuessesUrl =
                  CryptoJS.SHA256(testGuessesUrl).toString();
                const guessesInfo = modelTestingGuessesURL.get(modelId);
                console.log(testGuessesUrl);
                console.log(guessesInfo[highestUploadId]);
                if (
                  guessesInfo &&
                  CryptoJS.SHA256(
                    guessesInfo[highestUploadId].join(""),
                  ).toString() === hashTestGuessesUrl
                ) {
                  alert("Testing labels verified.");
                  //const file = await fetchFileAsBlob(testGuessesUrl); // Fetch the file as Blob
                  //handleFileSelect(file, highestUploadId); // Process the file to get labels data
                  compareLabelsArrays(
                    guessesInfo[highestUploadId],
                    modelHashes.get(modelId),
                    highestPredictions,
                    modelId,
                    highestUploadId,
                  );
                } else {
                  alert(
                    "Testing labels not verified. Model creators stake slashed.",
                  );
                  removeModelEntriesFromList("modelsRequiringZKSnark", modelId);
                  removeModelEntriesFromList("modelTestLabelsList", modelId);
                  removeModelEntriesFromList("modelsToVerifyList", modelId);
                }
              }
            } else {
              alert("No models uploaded for Model ID: " + modelId);
              //finalizeModelDeletion(modelId, modelList, entry, highestPredictions, highestUploadId);
            }
          }, 0);
        } else {
          alert(
            "Verification failed. Model Requester stake slashed for not providing correct testing labels.",
          );
          /*finalizeModelDeletion(
            modelId,
            modelList,
            entry,
            highestPredictions,
            highestUploadId,
          );*/
          removeModelEntriesFromList("modelsRequiringZKSnark", modelId);
          removeModelEntriesFromList("modelTestLabelsList", modelId);
          removeModelEntriesFromList("modelsToVerifyList", modelId);
          return;
        }
        /*
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
        }*/
      }
    }
  });
}

async function displayVerifiedTestLabel(modelId, testLabelUrl) {
  // Simulate an async operation, such as fetching a resource or waiting for user input
  // For example, fetching a file:
  try {
    const modelTestLabelsList = document.getElementById("modelTestLabelsList");
    const item = document.createElement("li");
    item.innerHTML = `Model ID: ${modelId}, <a href="${testLabelUrl}" target="_blank">Test Labels</a>`;
    modelTestLabelsList.appendChild(item);
    return true; // Indicates success
  } catch (error) {
    console.error("Failed to fetch or process test labels:", error);
    return false; // Indicates failure
  }
}
/*
  function displayVerifiedTestLabel(modelId, testLabelUrl) {
    const modelTestLabelsList = document.getElementById("modelTestLabelsList");
    const item = document.createElement("li");
    item.innerHTML = `Model ID: ${modelId}, <a href="${testLabelUrl}" target="_blank">Test Labels</a>`;
    modelTestLabelsList.appendChild(item);
}*/

function readAndParseCsv(blob) {
  const reader = new FileReader();
  reader.onload = function (event) {
    const csvString = event.target.result;
    const numbersArray = parseCsvToNumbers(csvString);
    console.log(numbersArray); // Outputs the array of numbers
    return numbersArray;
  };
  reader.readAsText(blob);
}

function parseCsvToNumbers(csvString) {
  return csvString.split("\n").map((line) => Number(line.trim()));
}

function handleFileSelect(file, modelIdInput) {
  const reader = new FileReader();

  reader.onload = function (event) {
    const csvData = event.target.result;
    Papa.parse(csvData, {
      complete: function (results) {
        const flatLabels = processLabels(results.data);
        console.log("Processed flat labels:", flatLabels);
        labelsArrs.set(modelIdInput, flatLabels);
      },
      error: function (err) {
        console.error("Error parsing CSV:", err);
      },
    });
  };

  reader.onerror = function () {
    alert("Unable to read " + file.name);
    reject(new Error("Unable to read " + file.name));
  };

  reader.readAsText(file);
}

function processLabels(labelsArray) {
  const flatLabels = labelsArray.map((row) => row[0]);

  //console.log("Processed flat labels:", flatLabels);

  return flatLabels;
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

  const tenPercentIndex = Math.floor(dataResults.length * 0.1);
  const testingSize = Math.min(100, tenPercentIndex);

  const shuffledData = indices.map((index) => dataResults[index]);
  const shuffledLabels = indices.map((index) => labelsResults[index]);

  //const trainingSize = Math.floor(shuffledData.length * 0.9);
  const trainingData = shuffledData.slice(0, shuffledData.length - testingSize);
  const trainingLabels = shuffledLabels.slice(
    0,
    shuffledData.length - testingSize,
  );
  const testingData = shuffledData.slice(-testingSize);
  const testingLabels = shuffledLabels.slice(-testingSize);

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

        const csvBlob = formDataGuesses.get("file");
        //const hashTestLabelsUrl = readAndParseCsv(csvBlob);
        const reader = new FileReader();
        reader.onload = async function (event) {
          const csvString = event.target.result;
          const numbersArray = parseCsvToNumbers(csvString);
          console.log("Guesses:", numbersArray); // Outputs the array of numbers
          const hashGuessesUrl = CryptoJS.SHA256(
            numbersArray.join(""),
          ).toString();
          //modelHashes.set(modelIdInput, numbersArray);
          //modelHashesLengths.set(modelIdInput, parsedData.testingLabels.length);

          //const guessesResult = await guessesResponse.json();
          const modelResult = await modelResponse.json();

          //const hashGuessesUrl = CryptoJS.SHA256(guessesResult.url).toString();
          const hashModelUrl = CryptoJS.SHA256(modelResult.url).toString();

          modelTestingGuessesURL.set(modelIdToVerify, {
            [modelUploadId]: numbersArray,
          });
          modeluploadResultURL.set(modelIdToVerify, {
            [modelUploadId]: hashModelUrl,
          });
          prompt(
            "*****IMPORTANT*****\n\nThese testing guesses must be provided later to enfore truthful behavior (Ctrl+C the text box):",
            numbersArray.join(""),
          );
          prompt(
            "*****IMPORTANT*****\n\nThis Model IPFS file must be provided later to enforce truthful behavior (Ctrl+C the text box):",
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
          /*
          try {
            console.log("Triggering model upload...");
            const tx = await modelCoinContract.submitModel(
              modelIdInput,
              modelUploadId,
              hashModelUrl,
              hashGuessesUrl,
            );
            await tx.wait();
            console.log("Model Upload executed successfully:", tx);
            alert("Model Upload successful! Transaction hash: " + tx.hash);
          } catch (error) {
            console.error("Error triggering model upload:", error);
            alert("Model Upload failed: " + error.message);
          } */
        };
        reader.readAsText(csvBlob);
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

// airdrop
async function triggerAirdrop() {
  console.log("clicked");
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const signer = provider.getSigner();

  const contractABI = modelCoinContractABI;
  const contractAddress = "0x7B6f1e448E5F284dE0246cA0f7bD94a483589009";
  const modelCoinContract = new ethers.Contract(
    contractAddress,
    contractABI,
    signer,
  );

  try {
    console.log("Triggering airdrop...");
    const tx = await modelCoinContract.claimAirdrop();
    await tx.wait();
    console.log("Airdrop executed successfully:", tx);
    alert("Airdrop successful! Transaction hash: " + tx.hash);
  } catch (error) {
    console.error("Error triggering airdrop:", error);
    alert("Airdrop failed: " + error.message);
  }
}

document.getElementById("airdropButton").addEventListener("click", () => {
  console.log("Button clicked");
  triggerAirdrop();
});

document.addEventListener("DOMContentLoaded", () => {
  setInterval(checkForExpiredModels, 30000);
});
