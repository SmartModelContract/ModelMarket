document.getElementById("connectWallet").addEventListener("click", async () => {
  if (typeof window.ethereum !== "undefined") {
    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      await provider.send("eth_requestAccounts", []);
      const signer = provider.getSigner();
      console.log("Connected to MetaMask:", await signer.getAddress());
    } catch (error) {
      console.error("Error connecting to MetaMask:", error);
    }
  } else {
    console.log("MetaMask is not installed!");
    alert("Please install MetaMask to use this feature.");
  }
});

const modelHashes = new Map();

document.getElementById("submitButton").addEventListener("click", function () {
    alert("*****IMPORTANT***** \nIt is your responsibility to keep track of the full dataset IPFS link along with the testing set IPFS link\nIf you lose these values your model may not be recoverable or you may lose your reward offered/collateral")
    const fileInput = document.getElementById("fileInput");
    const modelIdInput = document.getElementById("modelIdInput");
    const rewardInput = document.getElementById("rewardInput");
    const contextInput = document.getElementById("contextInput");
    
    const file = fileInput.files[0];

    if (!file || !modelIdInput || !rewardInput || !contextInput) {
        console.log("Form not filled out");
        alert("Please fill out all form elements");
        return;
    }

    if (modelHashes.has(modelIdInput)) {
        alert("Select a unique model ID");
        return
    }

    console.log(`Uploading ${file.name}...`);

    let urlTrain, urlTest;

    Papa.parse(file, {
        complete: async function(results) {
            const data = results.data;
            shuffleArray(data);
            const trainingSize = Math.floor(data.length * 0.9);
            const trainingData = data.slice(0, trainingSize);
            const testingData = data.slice(trainingSize);

            const trainingCsv = Papa.unparse(trainingData);
            const testingCsv = Papa.unparse(testingData);

            try {
                const formDataTrain = new FormData();
                formDataTrain.append("file", new Blob([trainingCsv], { type: "text/csv" }), "training.csv");

                const formDataTest = new FormData();
                formDataTest.append("file", new Blob([testingCsv], { type: "text/csv" }), "testing.csv");

                const [trainResponse, testResponse] = await Promise.all([
                    fetch("http://localhost:3000/upload_train_test_weights", { method: "POST", body: formDataTrain }),
                    fetch("http://localhost:3000/upload_train_test_weights", { method: "POST", body: formDataTest })
                ]);

                const trainResult = await trainResponse.json();
                const testResult = await testResponse.json();
                //console.log(`*****IMPORTANT*****\nTesting data URL: ${testResult.url}`)
                const hashTestUrl = CryptoJS.SHA256(testResult.url).toString();

                modelHashes.set(modelIdInput.value, hashTestUrl);
                prompt("*****IMPORTANT*****\nTesting data URL (Ctrl+C the text box):", testResult.url);
                displayModelData({
                    id: modelIdInput.value,
                    reward: parseFloat(rewardInput.value).toFixed(2),
                    context: contextInput.value,
                    urlTrain: trainResult.url,
                    hashTestUrl: hashTestUrl
                });
            } catch (error) {
                console.error("Upload failed:", error);
                alert(`Upload failed: ${error.message}`);
            }
        },
        error: function(err) {
            console.error("Error parsing CSV:", err);
            alert("Failed to parse CSV file.");
        }
    });

    const fullFormData = new FormData();
    fullFormData.append("file", file);
    fetch("http://localhost:3000/upload_full", {
        method: "POST",
        body: fullFormData,
    })
    .then(response => response.json())
    .then(result => {
        console.log("Full file upload successful:", result);
        prompt('*****IMPORTANT: DO NOT LOSE TRACK OF THE FULL FILE URL*****\n Full file uploaded successfully!\n IPFS URL (Ctrl+C): ', result.url);
    })
    .catch(error => {
        console.error("Full file upload failed:", error);
        alert(`Full file upload failed: ${error.message}`);
    });

    
})

function displayModelData(data) {
    const modelList = document.getElementById("modelList");
    const entry = document.createElement("li");
    entry.innerHTML = `ID: ${data.id}, Reward: ${data.reward}, Context: ${data.context}, <a href="${data.urlTrain}" target="_blank">Training Data URL</a>, Testing Data SHA256: ${data.hashTestUrl}`;
    modelList.appendChild(entry);
}

document.getElementById("verifyButton").addEventListener("click", async function () {
    const modelIdToVerify = document.getElementById("verifyModelIdInput").value;
    const modelWeightsFile = document.getElementById("modelWeightsInput").files[0];

    if (!modelIdToVerify || !modelWeightsFile) {
        alert("Please enter a model ID and select a file for model weights.");
        return;
    }

    if (modelHashes.has(modelIdToVerify)) {
        const expectedHash = modelHashes.get(modelIdToVerify);

        const userInput = prompt("What is the URL of the testing data that gave the SHA256 output that was revealed in the list of models?");
        const userInputHash = CryptoJS.SHA256(userInput).toString();

        if (userInputHash === expectedHash) {
            alert("The values are equal, verification passed.");

            const formData = new FormData();
            formData.append("file", modelWeightsFile);

            try {
                const response = await fetch("http://localhost:3000/upload_train_test_weights", {
                    method: "POST",
                    body: formData
                });
                const result = await response.json();
                const weightsUrl = result.url;
        
                const originalTestingUrl = userInput; 
                displayVerifiedModel(modelIdToVerify, weightsUrl, originalTestingUrl);

                const modelEntries = document.querySelectorAll("#modelList li");
                modelEntries.forEach(entry => {
                    if (entry.textContent.includes(`ID: ${modelIdToVerify}`)) {
                        entry.parentNode.removeChild(entry);
                    }
                });

            modelHashes.delete(modelIdToVerify); 


            } catch (error) {
                console.error("Error uploading weights file:", error);
                alert(`Error: ${error.message}`);
                return
            }

        } else {
            alert("The values are not equal. Verification failed.");
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

function shuffleArray(array) {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]]; 
    }
}
