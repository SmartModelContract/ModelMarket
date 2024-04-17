const contractAddress = '0x1e33DaE11dcd6197259673C286C1F56e75A46A18'; // Replace with your contract's address

let contract;
let provider;
let signer;

async function initApp() {
    const provider = await detectEthereumProvider();
    if(provider) {
        startApp(provider); // Initialize your app
    } else {
        console.log('Please install MetaMask!');
    }
}

function startApp(provider) {
    window.ethereum.request({ method: 'eth_requestAccounts' }).then(function (accounts) {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        signer = provider.getSigner();
        contract = new ethers.Contract(contractAddress, contractABI, signer);
	console.log(contract);
	console.log("attaching event listener");
        contract.on("StringSubmitted", (newString, index, event) => {
        // Update the UI with the new string
        const liveUpdateDiv = document.getElementById('liveStringDisplay');
        liveUpdateDiv.innerText = `New string recorded on the blockchain: ${newString} at index ${index}`;
    });


    }).catch(function (error) {
        console.error(error);
    });
}


async function submitString() {
    // Show the loading indicator
    document.getElementById('loadingIndicator').style.display = 'block';

    const str = document.getElementById('inputString').value;
    try {
        const txResponse = await contract.submitString(str);
        await txResponse.wait(); // Wait for the transaction to be mined
        console.log('Transaction submitted!');
        console.log('Transaction hash:', txResponse.hash);

        document.getElementById('txHashDisplay').innerText = `Transaction Hash: ${txResponse.hash}`;
    } catch (error) {
        console.error('Error submitting string:', error);
    } finally {
        // Hide the loading indicator regardless of the outcome
        document.getElementById('loadingIndicator').style.display = 'none';
    }
}

async function displayLatestText() {
    try {
        const latestString = await contract.getLastString();
        console.log('Latest string from the blockchain:', latestString);

        document.getElementById('latestStringDisplay').innerText = `Latest String: ${latestString}`;
    } catch (error) {
        console.error('Error fetching the latest string:', error);
    }
}


document.addEventListener('DOMContentLoaded', (event) => {
    initApp();
    // Listen for the NewStringUploaded event
    document.getElementById('submitStringButton').addEventListener('click', submitString);
    document.getElementById('fetchLatestStringButton').addEventListener('click', displayLatestText);
});


