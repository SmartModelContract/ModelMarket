//FOR HEILA - not needed rn
document.getElementById("uploadButton").addEventListener("click", async function () {
    const fileInput = document.getElementById("fileInput");
    const file = fileInput.files[0];
    if (file) {
        console.log(`Uploading ${file.name}...`);

        const reader = new FileReader();

        reader.onload = async function() {
            const { createHelia } = await import('helia');
            const { unixfs } = await import('@helia/unixfs');

            const helia = await createHelia();  
            const content = new Uint8Array(reader.result);
            try {

                const cid = await fs.addBytes(content, helia.blockstore);
                console.log('Added file:', cid.toString());

                const decoder = new TextDecoder();
                let text = '';
                for await (const chunk of fs.cat(cid)) {
                    text += decoder.decode(chunk, { stream: true });
                }
                console.log('Added file contents:', text);

                alert(`File successfully uploaded with CID: ${cid.toString()}`);
            } catch (error) {
                console.error('Error uploading file to Helia IPFS:', error);
                alert('Upload failed, see console for details.');
            }
        };

        reader.readAsArrayBuffer(file);
    } else {
        console.log("No file selected");
    }
});
