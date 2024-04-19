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

document.getElementById("uploadButton").addEventListener("click", function () {
  const fileInput = document.getElementById("fileInput");
  const file = fileInput.files[0];
  if (file) {
    console.log(`Uploading ${file.name}...`);

    const formData = new FormData();
    formData.append("file", file);

    fetch("/upload", {
      // Your server endpoint
      method: "POST",
      body: formData,
    })
      .then((response) => response.json()) // Assuming JSON response
      .then((result) => {
        console.log("Upload successful:", result);
      })
      .catch((error) => {
        console.error("Upload failed:", error);
      });
  } else {
    console.log("No file selected");
  }
});
